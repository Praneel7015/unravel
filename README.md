# Unravel — Circadian Botanical & Stoic Field Journal

> *“We suffer more often in imagination than in reality.”* — **Seneca**, *Letters from a Stoic, XIII*

**Unravel** is a local-first, end-to-end encrypted Stoic field journal designed to help you untangle anticipatory worry **before** important life moments and gently record how reality actually unfolded **afterward**.

Built with a strict **Dart 3.6 Pub Workspace Monorepo**, Unravel ships in two cleanly isolated editions:
- **Libre / FOSS Edition (`app.unravel.foss`):** 100% air-gapped by default, reproducible F-Droid build with **zero** proprietary billing, Firebase, or Google Play Services dependencies.
- **Sanctuary Cloud Edition (`app.unravel.store`):** App Store & Google Play edition with zero-knowledge E2EE Cloud Sync and a stateless, entitlement-gated Multi-Model Stoic AI Relay.

---

## 1. Core Philosophy — Zero Toxic Gamification

Most wellness apps borrow engagement mechanics from slot machines: day-streak counters, flame icons, leaderboards, and guilt-inducing push notifications. **Anxiety cannot be quieted by an app that makes you anxious about breaking a streak.**

Unravel contains **zero streaks** and revolves around two calm primitives:
1. **Open Threads (*Before a Moment* & *After a Moment*):**
   - **Before a Moment (Untangle Worries):** Speak or write what feels knotted in your chest. Break the worry into numbered items (`01`, `02`) separated by Epictetus’s **Dichotomy of Control** (`WITHIN MY CONTROL` vs. `BEYOND MY CONTROL`), paired with a concrete somatic **Physical Anchor**.
   - **After a Moment (Gentle Check-In):** A single, offline-scheduled local notification (`flutter_local_notifications` + `timezone`, zero Firebase) invites you 1 hour after the event to record how reality actually unfolded—with `NotificationVisibility.private` so raw worries never leak onto your lock screen.
2. **The Perspective Curve:**
   - A dual smooth cubic spline chart comparing **What Fear Predicted** (`1–10` dashed terracotta line) against **How Life Unfolded** (`1–10` solid botanical moss curve), computing your personal `"% gentler than feared"` evidence over time.

---

## 2. The 4 Circadian Botanical Surface Themes

Unravel’s surface palette shifts automatically with your local sun cycle (`CircadianResolver`) or can be pinned manually in **Sanctuary**:

| Circadian Window | Surface Mode | Canvas | Card Surface | Hairline Border (`1px`) | Primary Text | Primary Accent | Secondary Accent |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`06:00–11:00`** | **Morning Mist** *(Birch Paper Light)* | `#F6F5F0` | `#EFECE6` | `#DCD8CE` | `#1C1E1B` | `#3B5944` *(River Moss)* | `#C87D55` *(Morning Clay)* |
| **`11:00–17:30`** | **High Sun** *(Raw Limestone Neutral)* | `#EAE8E1` | `#E0DDD5` | `#CCC8BE` | `#181A18` | `#3B5944` *(Wild Sage)* | `#C98A3A` *(Ochre Sun)* |
| **`17:30–23:00`** | **Dusk Pine** *(Evening Nature Dark)* | `#141815` | `#1C221E` | `#2A332D` | `#E8E6DF` | `#84A98C` *(Lichen Green)* | `#D49A59` *(Warm Amber)* |
| **`23:00–06:00`** | **Midnight Starlight** *(Pure OLED Black)* | `#000000` | `#0B0C0B` | `#222623` | `#F2F0E8` | `#749C82` *(Moonlit Fern)* | `#C97054` *(Terracotta)* |

### Offline SIL Open Font License (OFL) Typography
Runtime HTTP font fetching is hard-disabled (`GoogleFonts.config.allowRuntimeFetching = false`). All 7 `.ttf` binaries are bundled directly in `packages/core/assets/fonts/`:
- **Editorial Serif (`Newsreader`):** Screen headers, event titles, italic Daily Stoic quotes, and spoken transcripts.
- **Humanist Sans (`Plus Jakarta Sans`):** Body copy, card descriptions, and pill buttons.
- **Technical Monospace (`JetBrains Mono`):** Circadian time pills, numbered worry indices (`01`, `02`), and 60-second audio timers (`0:42 / 1:00`).

---

## 3. Cryptographic Threat Model & Zero-Bill-Shock Architecture

### Client-Side Envelope Encryption (`EnvelopeEncryptionService`)
- **Per-Record Encryption:** Every reflection note, transcript, and synced thread envelope is encrypted on-device using **AES-256-GCM** (`package:cryptography`) with a cryptographically random 96-bit (12-byte) nonce and a 128-bit authentication tag (`v1:<nonce_b64>:<ciphertext_b64>:<mac_b64>`).
- **AAD Record Binding:** Each record’s unique identifier (`<recordId>:<column>`) is bound into the GCM **Associated Authenticated Data (`aad`)**, preventing a malicious server or MITM from transplanting ciphertexts across rows or tables.
- **Argon2id Master Key Wrapping:** When exporting a recovery bundle or syncing across devices, the 256-bit `MasterDataKey` is wrapped on-device using **Argon2id** (`64 MiB` memory cost, `3` iterations, `4` parallelism lanes, 16-byte random salt).
- **Ephemeral Voice Pipeline (`EphemeralHardwareVoiceCaptureService`):** Microphone audio streams as 16-bit PCM in RAM to drive the 30fps `OrganicVoiceWaveform`. The millisecond transcription completes—or if the modal sheet is swiped closed—`stopAndShred()` overwrites all RAM PCM chunks with `0x00` and unlinks any temporary OS buffer. Raw voice audio is never uploaded.

### Zero-Bill-Shock Cloud Hardening (`supabase/`)
- **Free & FOSS Users Cost `$0.00`:** `REVOKE ALL ON TABLE ... FROM anon;` ensures unauthenticated and free-tier users cannot touch Postgres tables or Edge Functions.
- **Hard Payload Ceiling:** Both client (`EnvelopeEncryptionService`) and Postgres (`CHECK (octet_length(encrypted_payload) <= 16384)`) enforce a strict `16 KiB` ceiling per envelope.
- **Atomic Quota & One-Trial-Per-Account Enforcement:**
  - `public.consume_unravel_ai_quota(UUID)` locks the user’s profile row with `FOR UPDATE`, enforcing a hard cap of **15 total AI calls** during a 7-day trial (`trial_ai_calls_remaining`) and **20 calls/day** for Pro users (`ai_calls_today <= 20`).
  - `POST /functions/v1/billing-webhook` verifies webhook signatures in **constant time** (`constantTimeEqual`) and invokes `public.apply_store_billing_webhook`, enforcing `trial_used = TRUE` so an account can never reset or repeat a free trial.
- **Apple Guideline 5.1.1(v) Account & Vault Purge:** Two-step confirmation in **Sanctuary** wipes local Drift SQLite tables, destroys the on-device `MasterDataKey`, and executes `public.delete_my_account()` to atomically delete `encrypted_journal_envelopes`, `profiles`, and `auth.users`.

---

## 4. Monorepo Structure

```text
Unravel/
├── apps/
│   ├── unravel_foss/        # F-Droid libre entrypoint (app.unravel.foss) — 0 proprietary SDKs
│   └── unravel_store/       # App Store / Play Store entrypoint (app.unravel.store)
├── packages/
│   ├── core/                # Circadian Theme Engine, Drift SQLite, AES-256-GCM/Argon2id, 30fps Voice, UI
│   ├── sync_foss/           # Air-gapped local mode, HTTPS WebDAV sync, BYOK / Local Ollama relay
│   └── sync_store/          # Entitlement-gated Supabase E2EE sync & Multi-Model Cloud Relay
├── supabase/
│   ├── migrations/          # RLS, 16 KiB CHECK constraints, quota & webhook RPCs, delete_my_account()
│   └── functions/           # Deno Edge Functions: unravel-relay (12s failover) & billing-webhook
├── fastlane/metadata/       # F-Droid compliant metadata (en-US title, descriptions, changelog)
├── docker/                  # Turnkey self-hosted TLS WebDAV + local Ollama Docker Compose kit
├── site/                    # Zero-dependency interactive Circadian web landing page
└── scripts/                 # Offline OFL font fetcher & 5-stage checkpoint verification runner
```

---

## 5. Turnkey Self-Hosting (`docker/`)

FOSS users who want cross-device E2EE sync and local AI reframing without any commercial cloud can spin up the self-hosted stack in one command:

```bash
cd docker
cp .env.example .env
# Edit .env with your domain and bcrypt password hash
docker compose --profile local-ai up -d
```

- **WebDAV E2EE Vault:** Exposed over TLS via Caddy at `https://<your-domain>/unravel-vault`.
- **Local Ollama Daemon:** Bound strictly to loopback (`127.0.0.1:11434`) with `no-new-privileges` and dropped Linux capabilities.

---

## 6. Reproducible Build Instructions for F-Droid Maintainers

`apps/unravel_foss` (`app.unravel.foss`) is engineered to pass `fdroid scanner` with zero warnings:

```bash
# 1. Fetch and verify the 7 SIL Open Font License (OFL 1.1) .ttf binaries
./scripts/fetch_ofl_fonts.sh

# 2. Verify zero proprietary dependencies exist in the FOSS tree
grep -RInE "(purchases_flutter|supabase_flutter|firebase_|com\.android\.billingclient|com\.google\.android\.gms)" \
  apps/unravel_foss packages/sync_foss/lib packages/sync_foss/pubspec.yaml && exit 1 || echo "Clean FOSS tree"

# 3. Resolve workspace dependencies & run tests
flutter pub get
flutter test packages/core/test/unravel_core_test.dart
flutter test packages/sync_foss/test/sync_foss_test.dart

# 4. Build the reproducible FOSS APK
cd apps/unravel_foss
flutter build apk --release --no-pub
```

---

## 7. Philosophical Safe-Harbor Notice

Unravel is a Stoic and botanical field journal for personal contemplation, not a medical device, clinical diagnostic tool, or substitute for professional mental health care. If you are experiencing a mental health crisis, please contact your local emergency services or a crisis support helpline.
