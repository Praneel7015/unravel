# Unravel — Run `app.unravel.foss` on Your Physical Phone or Emulator
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\run_foss_on_phone.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$FossAppDir = Join-Path $RepoRoot "apps\unravel_foss"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " UNRAVEL FOSS PHONE LAUNCHER (`app.unravel.foss`)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Locate Flutter SDK on PATH or common Windows install locations
$FlutterExe = $null
$FlutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($FlutterCmd) {
  $FlutterExe = $FlutterCmd.Source
} else {
  $Candidates = @(
    "C:\src\flutter\bin\flutter.bat",
    "C:\flutter\bin\flutter.bat",
    "$env:USERPROFILE\flutter\bin\flutter.bat",
    "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
    "$env:USERPROFILE\scoop\apps\flutter\current\bin\flutter.bat",
    "$env:USERPROFILE\fvm\default\bin\flutter.bat"
  )
  foreach ($Candidate in $Candidates) {
    if (Test-Path $Candidate) {
      $FlutterExe = $Candidate
      break
    }
  }
}

if (-not $FlutterExe) {
  Write-Host "`n[!] Flutter SDK was not found on this machine." -ForegroundColor Yellow
  Write-Host "To run the native Android build on your phone, install Flutter & Android platform-tools:" -ForegroundColor White
  Write-Host "  1. Run: winget install -e --id Google.Flutter" -ForegroundColor Green
  Write-Host "  2. Enable 'USB Debugging' in Developer Options on your phone and plug it in via USB." -ForegroundColor Green
  Write-Host "  3. Re-run this script: .\scripts\run_foss_on_phone.ps1`n" -ForegroundColor Green
  exit 1
}

Write-Host "Found Flutter SDK: $FlutterExe" -ForegroundColor Green

# 2. Ensure Offline OFL Fonts exist
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "fetch_ofl_fonts.ps1")

# 3. Scaffold missing Gradle wrapper files if needed while preserving our custom MainActivity.kt & AndroidManifest.xml
Push-Location $FossAppDir
try {
  $ManifestBackup = Get-Content "android\app\src\main\AndroidManifest.xml" -Raw
  $ActivityBackup = Get-Content "android\app\src\main\kotlin\app\unravel\foss\MainActivity.kt" -Raw

  if (-not (Test-Path "android\gradlew.bat")) {
    Write-Host "Generating Android Gradle wrapper for apps/unravel_foss..." -ForegroundColor Yellow
    & $FlutterExe create --platforms=android --org app.unravel --project-name unravel_foss .
    Set-Content -Path "android\app\src\main\AndroidManifest.xml" -Value $ManifestBackup
    New-Item -ItemType Directory -Force -Path "android\app\src\main\kotlin\app\unravel\foss" | Out-Null
    Set-Content -Path "android\app\src\main\kotlin\app\unravel\foss\MainActivity.kt" -Value $ActivityBackup
  }

  Write-Host "`nChecking connected phones / emulators..." -ForegroundColor Cyan
  & $FlutterExe devices

  Write-Host "`nLaunching app.unravel.foss in --release mode..." -ForegroundColor Green
  & $FlutterExe run --release
} finally {
  Pop-Location
}
