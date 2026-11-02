# Verifies the bundled SIL Open Font License IBM Plex faces used by packages/core.

$ErrorActionPreference = "Stop"
$FontDir = Join-Path $PSScriptRoot "..\packages\core\assets\fonts"

$Required = @(
  "IBMPlexSerif-Regular.ttf",
  "IBMPlexSerif-Medium.ttf",
  "IBMPlexSerif-Italic.ttf",
  "IBMPlexSans-Regular.ttf",
  "IBMPlexSans-SemiBold.ttf",
  "IBMPlexMono-Regular.ttf",
  "IBMPlexMono-Medium.ttf",
  "OFL-IBMPlex.txt"
)

foreach ($Name in $Required) {
  $Path = Join-Path $FontDir $Name
  if (-not (Test-Path $Path) -or (Get-Item $Path).Length -le 0) {
    throw "Missing font asset: $Path"
  }
}

Write-Host "Verified $($Required.Count) IBM Plex / OFL files in $FontDir"
