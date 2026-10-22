// POST /functions/v1/billing-webhook
// Zero-Trust Store Entitlement Webhook for Unravel (`app.unravel.store`).
//
// Handles Apple App Store / Google Play / RevenueCat lifecycle events:
// - `INITIAL_PURCHASE`
// - `RENEWAL`
// - `CANCELLATION`
// - `EXPIRATION`
//
// Security Guarantees:
// 1. Constant-Time Secret & HMAC-SHA256 Signature Verification (`constantTimeEqual`)
//    so attackers cannot spoof POST requests or use timing side-channels to upgrade `profiles.tier`.
// 2. One-Trial-Per-Account Rule: Atomically checks `profiles.trial_used` via
//    `public.apply_store_billing_webhook` (`FOR UPDATE` row lock). If `period_type === 'TRIAL'`
//    and `trial_used` is already `true`, rejects trial activation with HTTP 409.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.46.1';

const MAX_WEBHOOK_BYTES = 32768;
const SUPPORTED_EVENTS = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'CANCELLATION',
  'EXPIRATION',
]);

/**
 * Constant-time byte array comparison (`O(n)` bitwise XOR accumulator).
 * Never branches early on mismatch, eliminating timing side-channel leaks.
 */
export function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.byteLength !== b.byteLength || a.byteLength === 0) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.byteLength; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}

/**
 * Hashes two strings with SHA-256 so both inputs are normalized to fixed 32-byte
 * digests before running `constantTimeEqual` (preventing length-oracle leaks).
 */
export async function constantTimeSecretVerify(
  providedSecret: string,
  expectedSecret: string,
): Promise<boolean> {
  if (!providedSecret || !expectedSecret) {
    return false;
  }
  const encoder = new TextEncoder();
  const [digestA, digestB] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(providedSecret)),
    crypto.subtle.digest('SHA-256', encoder.encode(expectedSecret)),
  ]);
  return constantTimeEqual(new Uint8Array(digestA), new Uint8Array(digestB));
}

/**
 * Verifies an optional hex-encoded HMAC-SHA256 payload signature (`X-Unravel-Signature`)
 * in constant time.
 */
export async function verifyHmacSha256Signature(
  rawBody: string,
  providedHexSignature: string,
  webhookSecret: string,
): Promise<boolean> {
  if (!providedHexSignature || !webhookSecret) {
    return false;
  }
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(webhookSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const macBuffer = await crypto.subtle.sign('HMAC', key, encoder.encode(rawBody));
  const computedHex = Array.from(new Uint8Array(macBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  return constantTimeSecretVerify(
    providedHexSignature.trim().toLowerCase(),
    computedHex,
  );
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const expectedWebhookSecret = Deno.env.get('BILLING_WEBHOOK_SECRET') ?? '';
  if (!expectedWebhookSecret) {
    return new Response(
      JSON.stringify({ error: 'Webhook secret not configured on server' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).byteLength > MAX_WEBHOOK_BYTES) {
    return new Response(JSON.stringify({ error: 'Webhook payload too large' }), {
      status: 413,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Verify either `X-Unravel-Signature` (HMAC-SHA256) or `Authorization: Bearer <secret>` in constant time.
  const signatureHeader = req.headers.get('X-Unravel-Signature') ?? '';
  const authHeader = req.headers.get('Authorization') ?? '';
  const bearerToken = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length).trim()
    : '';

  const isSignatureValid = signatureHeader
    ? await verifyHmacSha256Signature(
        rawBody,
        signatureHeader,
        expectedWebhookSecret,
      )
    : await constantTimeSecretVerify(bearerToken, expectedWebhookSecret);

  if (!isSignatureValid) {
    return new Response(
      JSON.stringify({ error: 'Invalid webhook signature or authorization' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    );
  }

  let eventObj: Record<string, unknown>;
  try {
    const parsed = JSON.parse(rawBody) as Record<string, unknown>;
    // Support both RevenueCat `{ "event": { ... } }` envelope and direct event object
    eventObj =
      parsed.event && typeof parsed.event === 'object' && !Array.isArray(parsed.event)
        ? (parsed.event as Record<string, unknown>)
        : parsed;
  } catch {
    return new Response(JSON.stringify({ error: 'Malformed JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const eventId = typeof eventObj.id === 'string' ? eventObj.id.trim() : '';
  const eventType = typeof eventObj.type === 'string' ? eventObj.type.trim().toUpperCase() : '';
  const appUserId =
    typeof eventObj.app_user_id === 'string' ? eventObj.app_user_id.trim() : '';
  const periodType =
    typeof eventObj.period_type === 'string'
      ? eventObj.period_type.trim().toUpperCase()
      : 'NORMAL';

  if (!eventId || !appUserId || !SUPPORTED_EVENTS.has(eventType)) {
    return new Response(
      JSON.stringify({
        error: 'Missing required fields (id, app_user_id) or unsupported event type',
      }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  // Atomically apply entitlement transition & enforce One-Trial-Per-Account (`trial_used`)
  const { data: statusResult, error: rpcError } = await adminClient.rpc(
    'apply_store_billing_webhook',
    {
      p_user_id: appUserId,
      p_event_id: eventId,
      p_event_type: eventType,
      p_period_type: periodType,
    },
  );

  if (rpcError) {
    return new Response(
      JSON.stringify({ error: 'Failed to apply store entitlement transition' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  if (statusResult === 'TRIAL_ALREADY_USED') {
    return new Response(
      JSON.stringify({
        error: 'One-Trial-Per-Account rule: trial_used is already true for this account.',
        status: statusResult,
      }),
      { status: 409, headers: { 'Content-Type': 'application/json' } },
    );
  }

  if (statusResult === 'PROFILE_NOT_FOUND') {
    return new Response(
      JSON.stringify({ error: 'Target user profile not found', status: statusResult }),
      { status: 404, headers: { 'Content-Type': 'application/json' } },
    );
  }

  return new Response(
    JSON.stringify({
      ok: true,
      eventId,
      eventType,
      periodType,
      transition: statusResult,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
