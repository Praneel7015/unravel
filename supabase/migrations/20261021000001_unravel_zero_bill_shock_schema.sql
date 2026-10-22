-- Unravel — Zero-Bill-Shock & E2EE Cloud Sync Schema
-- Strictly enforces:
-- 1. REVOKE ALL on the `anon` Postgres role (free/anonymous users cost $0.00).
-- 2. Cryptographic Entitlement Gate: RLS requires `profiles.tier IN ('trial', 'pro')`.
-- 3. Hard Abuse Caps: `trial_ai_calls_remaining` (15 total) and `ai_calls_today <= 20`.
-- 4. `CHECK (octet_length(encrypted_payload) <= 16384)` on all synced E2EE columns.

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier TEXT NOT NULL DEFAULT 'free'
    CHECK (tier IN ('free', 'trial', 'pro')),
  trial_used BOOLEAN NOT NULL DEFAULT FALSE,
  trial_ai_calls_remaining INTEGER NOT NULL DEFAULT 15
    CHECK (trial_ai_calls_remaining BETWEEN 0 AND 15),
  ai_calls_today INTEGER NOT NULL DEFAULT 0
    CHECK (ai_calls_today BETWEEN 0 AND 20),
  ai_quota_date DATE NOT NULL DEFAULT CURRENT_DATE,
  last_webhook_event_id TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.encrypted_journal_envelopes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  record_type TEXT NOT NULL CHECK (record_type IN ('open_thread', 'perspective_log')),
  encrypted_payload TEXT NOT NULL
    CHECK (octet_length(encrypted_payload) <= 16384),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.encrypted_journal_envelopes ENABLE ROW LEVEL SECURITY;

-- REVOKE ALL from the `anon` role so unauthenticated traffic cannot touch tables or RPCs
REVOKE ALL ON TABLE public.profiles FROM anon;
REVOKE ALL ON TABLE public.encrypted_journal_envelopes FROM anon;

-- Users can read their own profile; only service_role (store webhooks) can mutate `tier`
CREATE POLICY profiles_select_own
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Cryptographic Entitlement Gate for E2EE Cloud Sync:
-- Only authenticated users whose server-verified `profiles.tier IN ('trial', 'pro')`
-- may read or write encrypted envelopes.
CREATE POLICY envelopes_entitled_select
  ON public.encrypted_journal_envelopes
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.tier IN ('trial', 'pro')
    )
  );

CREATE POLICY envelopes_entitled_insert
  ON public.encrypted_journal_envelopes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND octet_length(encrypted_payload) <= 16384
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.tier IN ('trial', 'pro')
    )
  );

CREATE POLICY envelopes_entitled_update
  ON public.encrypted_journal_envelopes
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.tier IN ('trial', 'pro')
    )
  )
  WITH CHECK (
    auth.uid() = user_id
    AND octet_length(encrypted_payload) <= 16384
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.tier IN ('trial', 'pro')
    )
  );

CREATE POLICY envelopes_entitled_delete
  ON public.encrypted_journal_envelopes
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
  );

-- Atomic quota consumption RPC invoked by `POST /functions/v1/unravel-relay`
CREATE OR REPLACE FUNCTION public.consume_unravel_ai_quota(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tier TEXT;
  v_trial_remaining INTEGER;
  v_calls_today INTEGER;
  v_quota_date DATE;
BEGIN
  SELECT tier, trial_ai_calls_remaining, ai_calls_today, ai_quota_date
    INTO v_tier, v_trial_remaining, v_calls_today, v_quota_date
    FROM public.profiles
   WHERE id = p_user_id
   FOR UPDATE;

  IF NOT FOUND OR v_tier = 'free' THEN
    RETURN FALSE;
  END IF;

  IF v_quota_date < CURRENT_DATE THEN
    v_calls_today := 0;
    v_quota_date := CURRENT_DATE;
  END IF;

  IF v_tier = 'trial' THEN
    IF v_trial_remaining <= 0 THEN
      RETURN FALSE;
    END IF;
    UPDATE public.profiles
       SET trial_ai_calls_remaining = trial_ai_calls_remaining - 1,
           ai_calls_today = v_calls_today + 1,
           ai_quota_date = v_quota_date,
           updated_at = NOW()
     WHERE id = p_user_id;
    RETURN TRUE;
  ELSIF v_tier = 'pro' THEN
    IF v_calls_today >= 20 THEN
      RETURN FALSE;
    END IF;
    UPDATE public.profiles
       SET ai_calls_today = v_calls_today + 1,
           ai_quota_date = v_quota_date,
           updated_at = NOW()
     WHERE id = p_user_id;
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_unravel_ai_quota(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_unravel_ai_quota(UUID) TO service_role;

-- Apple App Store Guideline 5.1.1(v) Compliance:
-- Authenticated RPC `delete_my_account()` atomically purges all synced E2EE
-- envelopes, the user's profile row, and the underlying `auth.users` account.
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM public.encrypted_journal_envelopes WHERE user_id = v_uid;
  DELETE FROM public.profiles WHERE id = v_uid;
  DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- Zero-Trust Store Entitlement Webhook Helper (`POST /functions/v1/billing-webhook`):
-- Enforces the One-Trial-Per-Account Rule (`trial_used`) under a row-level `FOR UPDATE`
-- lock and handles `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, and `EXPIRATION`.
CREATE OR REPLACE FUNCTION public.apply_store_billing_webhook(
  p_user_id UUID,
  p_event_id TEXT,
  p_event_type TEXT,
  p_period_type TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trial_used BOOLEAN;
  v_last_event_id TEXT;
BEGIN
  SELECT trial_used, last_webhook_event_id
    INTO v_trial_used, v_last_event_id
    FROM public.profiles
   WHERE id = p_user_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'PROFILE_NOT_FOUND';
  END IF;

  IF p_event_id IS NOT NULL AND v_last_event_id = p_event_id THEN
    RETURN 'DUPLICATE_EVENT';
  END IF;

  IF p_event_type IN ('INITIAL_PURCHASE', 'RENEWAL') THEN
    IF UPPER(COALESCE(p_period_type, 'NORMAL')) = 'TRIAL' THEN
      -- One-Trial-Per-Account Rule: reject repeat trial starts forever
      IF v_trial_used THEN
        RETURN 'TRIAL_ALREADY_USED';
      END IF;

      UPDATE public.profiles
         SET tier = 'trial',
             trial_used = TRUE,
             trial_ai_calls_remaining = 15,
             last_webhook_event_id = p_event_id,
             updated_at = NOW()
       WHERE id = p_user_id;
      RETURN 'ACTIVATED_TRIAL';
    ELSE
      UPDATE public.profiles
         SET tier = 'pro',
             trial_used = TRUE,
             last_webhook_event_id = p_event_id,
             updated_at = NOW()
       WHERE id = p_user_id;
      RETURN 'ACTIVATED_PRO';
    END IF;
  ELSIF p_event_type = 'CANCELLATION' THEN
    -- Record cancellation event; if it was an unbilled trial cancellation or
    -- immediate refund, downgrade to 'free' while keeping `trial_used = TRUE`.
    IF UPPER(COALESCE(p_period_type, 'NORMAL')) = 'TRIAL' THEN
      UPDATE public.profiles
         SET tier = 'free',
             trial_used = TRUE,
             trial_ai_calls_remaining = 0,
             last_webhook_event_id = p_event_id,
             updated_at = NOW()
       WHERE id = p_user_id;
      RETURN 'CANCELLED_TRIAL_DOWNGRADED';
    END IF;

    UPDATE public.profiles
       SET last_webhook_event_id = p_event_id,
           updated_at = NOW()
     WHERE id = p_user_id;
    RETURN 'CANCELLATION_RECORDED';
  ELSIF p_event_type = 'EXPIRATION' THEN
    UPDATE public.profiles
       SET tier = 'free',
           trial_ai_calls_remaining = 0,
           last_webhook_event_id = p_event_id,
           updated_at = NOW()
     WHERE id = p_user_id;
    RETURN 'EXPIRED_DOWNGRADED';
  END IF;

  RETURN 'UNHANDLED_EVENT';
END;
$$;

REVOKE ALL ON FUNCTION public.apply_store_billing_webhook(UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_store_billing_webhook(UUID, TEXT, TEXT, TEXT) TO service_role;


