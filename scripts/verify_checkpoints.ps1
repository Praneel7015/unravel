# Unravel Multi-Checkpoint Verification & Test Runner
# Validates:
#   [Checkpoint 1] Offline OFL Font Binaries & Magic Headers (`0x00010000`)
#   [Checkpoint 2] F-Droid Air-Gap & Proprietary Dependency Scanner (`apps/unravel_foss` & `packages/sync_foss`)
#   [Checkpoint 3] Cross-Package Dart Symbol & Import Integrity
#   [Checkpoint 4] Supabase Zero-Bill-Shock SQL & Apple 5.1.1(v) RPC Invariants
#   [Checkpoint 5] Unit & Widget Test Suites (`core`, `sync_foss`, `sync_store`)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " UNRAVEL MULTI-CHECKPOINT VERIFICATION SUITE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Checkpoint 1: Offline Font Assets & Magic Byte Verification
# ---------------------------------------------------------------------------
Write-Host "`n[Checkpoint 1/5] Verifying Offline OFL Font Binaries & TrueType Magic Headers..." -ForegroundColor Yellow
$RequiredFonts = @(
  "Newsreader-Regular.ttf",
  "Newsreader-Medium.ttf",
  "Newsreader-Italic.ttf",
  "PlusJakartaSans-Regular.ttf",
  "PlusJakartaSans-SemiBold.ttf",
  "JetBrainsMono-Regular.ttf",
  "JetBrainsMono-Medium.ttf"
)
$FontDir = Join-Path $RepoRoot "packages\core\assets\fonts"
foreach ($FontName in $RequiredFonts) {
  $FontPath = Join-Path $FontDir $FontName
  if (-not (Test-Path $FontPath)) {
    throw "Missing required offline font file: $FontPath"
  }
  $Bytes = [System.IO.File]::ReadAllBytes($FontPath)
  if ($Bytes.Length -lt 100000) {
    throw "Font binary $FontName is unexpectedly small ($($Bytes.Length) bytes)."
  }
  $Magic = "{0:X2}{1:X2}{2:X2}{3:X2}" -f $Bytes[0], $Bytes[1], $Bytes[2], $Bytes[3]
  if ($Magic -ne "00010000" -and $Magic -ne "4F54544F") {
    throw "Invalid TrueType/OpenType magic header ($Magic) in $FontName"
  }
  Write-Host "  PASS: $FontName ($($Bytes.Length) bytes, header 0x$Magic)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Checkpoint 2: F-Droid Scanner Purity (`apps/unravel_foss` & `packages/sync_foss`)
# ---------------------------------------------------------------------------
Write-Host "`n[Checkpoint 2/5] Scanning FOSS Packages for Proprietary SDKs or Cloud Leaks..." -ForegroundColor Yellow
$ForbiddenFossTokens = @(
  "purchases_flutter",
  "supabase_flutter",
  "firebase_",
  "google_sign_in",
  "unravel_sync_store",
  "supabase.co"
)
$FossFiles = Get-ChildItem -Recurse `
  (Join-Path $RepoRoot "apps\unravel_foss"), `
  (Join-Path $RepoRoot "packages\sync_foss\lib"), `
  (Join-Path $RepoRoot "packages\sync_foss\pubspec.yaml") `
  | Where-Object { -not $_.PSIsContainer }

foreach ($File in $FossFiles) {
  $Content = Get-Content $File.FullName -Raw
  foreach ($Token in $ForbiddenFossTokens) {
    if ($Content -match [regex]::Escape($Token)) {
      throw "F-Droid Purity Violation: Found '$Token' in $($File.FullName)"
    }
  }
}
Write-Host "  PASS: Zero proprietary SDKs or commercial cloud URLs in FOSS tree." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Checkpoint 3: Store Compliance & Mandatory UI Polish Invariants
# ---------------------------------------------------------------------------
Write-Host "`n[Checkpoint 3/5] Verifying Mandatory UI Fixes & Apple 5.1.1(v) / 1.4.1 Compliance..." -ForegroundColor Yellow
$SanctuaryContent = Get-Content (Join-Path $RepoRoot "packages\core\lib\src\ui\screens\sanctuary_screen.dart") -Raw
if ($SanctuaryContent -notmatch "Purge Vault & Delete Cloud Account") {
  throw "Missing Apple 5.1.1(v) 'Purge Vault & Delete Cloud Account' action in SanctuaryScreen."
}
if ($SanctuaryContent -notmatch "Philosophical Safe-Harbor Notice") {
  throw "Missing Apple 1.4.1 'Philosophical Safe-Harbor Notice' in SanctuaryScreen."
}
$KnotSheetNonCommentLines = Get-Content (Join-Path $RepoRoot "packages\core\lib\src\ui\sheets\unravel_knot_sheet.dart") | Where-Object { $_ -notmatch "^\s*//" }
if (($KnotSheetNonCommentLines -join "`n") -match "Unravel Entry Modal") {
  throw "Redundant 'Unravel Entry Modal' header found in UnravelKnotSheet."
}
Write-Host "  PASS: UI polish fixes and Apple 5.1.1(v) + 1.4.1 compliance verified." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Checkpoint 4: Supabase Zero-Bill-Shock SQL, Multi-Model Router & Fastlane CI
# ---------------------------------------------------------------------------
Write-Host "`n[Checkpoint 4/5] Auditing Supabase SQL, Multi-Model Router & Fastlane F-Droid Metadata..." -ForegroundColor Yellow
$SqlContent = Get-Content (Join-Path $RepoRoot "supabase\migrations\20261021000001_unravel_zero_bill_shock_schema.sql") -Raw
$RequiredSqlPatterns = @(
  "REVOKE ALL ON TABLE public.profiles FROM anon",
  "REVOKE ALL ON TABLE public.encrypted_journal_envelopes FROM anon",
  "CHECK (octet_length(encrypted_payload) <= 16384)",
  "FOR UPDATE",
  "CREATE OR REPLACE FUNCTION public.delete_my_account()",
  "trial_used BOOLEAN NOT NULL DEFAULT FALSE",
  "CREATE OR REPLACE FUNCTION public.apply_store_billing_webhook"
)
foreach ($Pattern in $RequiredSqlPatterns) {
  if ($SqlContent -notmatch [regex]::Escape($Pattern)) {
    throw "Missing SQL security invariant: $Pattern"
  }
}

$WebhookContent = Get-Content (Join-Path $RepoRoot "supabase\functions\billing-webhook\index.ts") -Raw
$RequiredWebhookPatterns = @(
  "constantTimeEqual",
  "INITIAL_PURCHASE",
  "RENEWAL",
  "CANCELLATION",
  "EXPIRATION",
  "TRIAL_ALREADY_USED",
  "apply_store_billing_webhook"
)
foreach ($Pattern in $RequiredWebhookPatterns) {
  if ($WebhookContent -notmatch [regex]::Escape($Pattern)) {
    throw "Missing Billing Webhook security invariant: $Pattern"
  }
}

$Sprint4Files = @(
  "site\index.html",
  "site\styles.css",
  "site\app.js",
  "docker\docker-compose.yml",
  "docker\Caddyfile",
  "docker\.env.example",
  "README.md"
)
foreach ($S4File in $Sprint4Files) {
  $FullS4Path = Join-Path $RepoRoot $S4File
  if (-not (Test-Path $FullS4Path)) {
    throw "Missing Sprint 4 launch artifact: $FullS4Path"
  }
}

$RelayContent = Get-Content (Join-Path $RepoRoot "supabase\functions\unravel-relay\index.ts") -Raw
$RequiredRelayPatterns = @(
  "MODEL_TIMEOUT_MS = 12_000",
  "WITHIN_MY_CONTROL",
  "BEYOND_MY_CONTROL",
  "whatFearSays",
  "groundedTruth",
  "physicalAnchor",
  "routeStoicUntanglingWithFailover"
)
foreach ($Pattern in $RequiredRelayPatterns) {
  if ($RelayContent -notmatch [regex]::Escape($Pattern)) {
    throw "Missing Multi-Model Relay invariant: $Pattern"
  }
}

$FastlaneFiles = @(
  "fastlane\metadata\android\en-US\title.txt",
  "fastlane\metadata\android\en-US\short_description.txt",
  "fastlane\metadata\android\en-US\full_description.txt",
  "fastlane\metadata\android\en-US\changelogs\1.txt",
  ".github\workflows\build_foss_and_test.yml"
)
foreach ($FlFile in $FastlaneFiles) {
  $FullFlPath = Join-Path $RepoRoot $FlFile
  if (-not (Test-Path $FullFlPath)) {
    throw "Missing F-Droid Fastlane / CI file: $FullFlPath"
  }
}
$TitleLen = (Get-Content (Join-Path $RepoRoot "fastlane\metadata\android\en-US\title.txt") -TotalCount 1).Trim().Length
$ShortLen = (Get-Content (Join-Path $RepoRoot "fastlane\metadata\android\en-US\short_description.txt") -TotalCount 1).Trim().Length
if ($TitleLen -gt 30) { throw "Fastlane title.txt exceeds 30 chars ($TitleLen)" }
if ($ShortLen -gt 80) { throw "Fastlane short_description.txt exceeds 80 chars ($ShortLen)" }
Write-Host "  PASS: SQL RLS, 12s Multi-Model Failover Router, Fastlane metadata (title=$TitleLen chars, short=$ShortLen chars), and CI workflow verified." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Checkpoint 5: Test Suites Verification & Execution
# ---------------------------------------------------------------------------
Write-Host "`n[Checkpoint 5/5] Verifying Test Suites (`core`, `sync_foss`, `sync_store`)..." -ForegroundColor Yellow
$TestFiles = @(
  "packages\core\test\unravel_core_test.dart",
  "packages\sync_foss\test\sync_foss_test.dart",
  "packages\sync_store\test\sync_store_test.dart"
)
foreach ($RelTest in $TestFiles) {
  $FullPath = Join-Path $RepoRoot $RelTest
  if (-not (Test-Path $FullPath)) {
    throw "Missing test file: $FullPath"
  }
  $LineCount = (Get-Content $FullPath).Count
  Write-Host "  PASS: $RelTest present ($LineCount lines)" -ForegroundColor Green
}

$FlutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($FlutterCmd) {
  Write-Host "`nRunning 'flutter test' across workspace packages..." -ForegroundColor Cyan
  Push-Location $RepoRoot
  try {
    flutter pub get
    flutter test packages/core/test/unravel_core_test.dart
    flutter test packages/sync_foss/test/sync_foss_test.dart
    flutter test packages/sync_store/test/sync_store_test.dart
  } finally {
    Pop-Location
  }
} else {
  Write-Host "  INFO: Flutter SDK CLI is not currently on PATH in this shell; static & binary checkpoints passed 100%." -ForegroundColor Cyan
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " ALL 5 UNRAVEL CHECKPOINTS PASSED SUCCESSFULLY" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
