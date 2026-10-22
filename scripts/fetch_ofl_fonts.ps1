# Fetches the exact SIL Open Font License (OFL 1.1) .ttf binaries required by
# `packages/core/pubspec.yaml` so `GoogleFonts.config.allowRuntimeFetching = false`
# resolves 100% offline on F-Droid (`app.unravel.foss`) and Store builds.

$ErrorActionPreference = "Stop"
$FontDir = Join-Path $PSScriptRoot "..\packages\core\assets\fonts"
New-Item -ItemType Directory -Force -Path $FontDir | Out-Null

$Fonts = @{
  "Newsreader-Regular.ttf"       = "https://github.com/google/fonts/raw/main/ofl/newsreader/Newsreader%5Bopsz,wght%5D.ttf"
  "Newsreader-Medium.ttf"        = "https://github.com/google/fonts/raw/main/ofl/newsreader/Newsreader%5Bopsz,wght%5D.ttf"
  "Newsreader-Italic.ttf"        = "https://github.com/google/fonts/raw/main/ofl/newsreader/Newsreader-Italic%5Bopsz,wght%5D.ttf"
  "PlusJakartaSans-Regular.ttf"  = "https://github.com/google/fonts/raw/main/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf"
  "PlusJakartaSans-SemiBold.ttf" = "https://github.com/google/fonts/raw/main/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf"
  "JetBrainsMono-Regular.ttf"    = "https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf"
  "JetBrainsMono-Medium.ttf"     = "https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf"
}

foreach ($Entry in $Fonts.GetEnumerator()) {
  $OutFile = Join-Path $FontDir $Entry.Key
  Write-Host "Downloading $($Entry.Key) ..."
  Invoke-WebRequest -Uri $Entry.Value -OutFile $OutFile -UseBasicParsing
}

Write-Host "Verified all 7 OFL font binaries in $FontDir"
