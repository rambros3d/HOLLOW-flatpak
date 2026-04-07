# fetch_ffmpeg.ps1 — Download a minimal LGPL static ffmpeg binary for Windows.
#
# Source: BtbN/FFmpeg-Builds (https://github.com/BtbN/FFmpeg-Builds/releases/latest)
# Variant: ffmpeg-master-latest-win64-lgpl-shared.zip — but we want a static
#          single-binary build, so we use ffmpeg-master-latest-win64-lgpl.zip
#          (statically linked, includes libwebp encoder).
#
# Output: vendor/ffmpeg/ffmpeg-win-x64.exe + LICENSE.ffmpeg.txt + VERSION.txt
#
# Usage: From the repo root, run `.\scripts\fetch_ffmpeg.ps1` in PowerShell.
#        Re-running is safe — it overwrites the existing files.

$ErrorActionPreference = "Stop"

# --- Configuration ---
$ReleaseUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-lgpl.zip"

# Repo root = parent of the scripts/ directory this script lives in.
# Use [System.IO.Path]::GetFullPath to normalize ".." without requiring the
# target directory to already exist (Resolve-Path errors on missing paths).
$RepoRoot   = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$VendorDir  = Join-Path $RepoRoot "vendor\ffmpeg"
$TempDir    = Join-Path $env:TEMP "hollow_ffmpeg_fetch"
$ZipPath    = Join-Path $TempDir "ffmpeg-win64-lgpl.zip"
$ExtractDir = Join-Path $TempDir "extract"

Write-Host "==> Hollow ffmpeg fetcher (Windows x64)"
Write-Host "    Source: $ReleaseUrl"
Write-Host "    Target: $VendorDir"
Write-Host ""

# --- Prepare directories ---
if (-not (Test-Path $VendorDir)) {
    New-Item -ItemType Directory -Path $VendorDir -Force | Out-Null
}
if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force $TempDir
}
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null

# --- Download ---
Write-Host "==> Downloading ffmpeg release archive..."
try {
    # Use TLS 1.2+ (required by GitHub since 2018)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    Invoke-WebRequest -Uri $ReleaseUrl -OutFile $ZipPath -UseBasicParsing
} catch {
    Write-Error "Failed to download ffmpeg: $_"
    exit 1
}

$zipSize = (Get-Item $ZipPath).Length
Write-Host "    Downloaded $([math]::Round($zipSize / 1MB, 1)) MB"
Write-Host ""

# --- Extract ---
Write-Host "==> Extracting archive..."
try {
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractDir -Force
} catch {
    Write-Error "Failed to extract zip: $_"
    exit 1
}

# BtbN archives extract into a folder like "ffmpeg-master-latest-win64-lgpl/"
$inner = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
if (-not $inner) {
    Write-Error "Extracted archive has unexpected structure (no subdirectory found)"
    exit 1
}
Write-Host "    Extracted to: $($inner.Name)"
Write-Host ""

# --- Locate ffmpeg.exe ---
$srcFfmpeg = Join-Path $inner.FullName "bin\ffmpeg.exe"
if (-not (Test-Path $srcFfmpeg)) {
    Write-Error "ffmpeg.exe not found at expected path: $srcFfmpeg"
    exit 1
}
$ffmpegSize = (Get-Item $srcFfmpeg).Length
Write-Host "==> Found ffmpeg.exe ($([math]::Round($ffmpegSize / 1MB, 1)) MB)"

# --- Locate license + readme (for LGPL compliance) ---
$srcLicense = Join-Path $inner.FullName "LICENSE.txt"
$srcReadme  = Join-Path $inner.FullName "README.txt"

# --- Copy to vendor/ffmpeg/ ---
$dstFfmpeg = Join-Path $VendorDir "ffmpeg-win-x64.exe"
$dstLicense = Join-Path $VendorDir "LICENSE.ffmpeg.txt"
$dstVersion = Join-Path $VendorDir "VERSION.txt"

Copy-Item -LiteralPath $srcFfmpeg -Destination $dstFfmpeg -Force
Write-Host "    Copied -> $dstFfmpeg"

if (Test-Path $srcLicense) {
    Copy-Item -LiteralPath $srcLicense -Destination $dstLicense -Force
    Write-Host "    Copied -> $dstLicense"
}

# --- Verify the binary actually runs and supports libwebp ---
Write-Host ""
Write-Host "==> Verifying ffmpeg binary..."
try {
    $versionOutput = & $dstFfmpeg -hide_banner -version 2>&1 | Select-Object -First 3
    Write-Host "    $($versionOutput[0])"
} catch {
    Write-Error "ffmpeg binary failed to execute: $_"
    exit 1
}

# Check for libwebp encoder (required for thumbnail generation)
try {
    $webpCheck = & $dstFfmpeg -hide_banner -encoders 2>&1 | Select-String "libwebp"
    if (-not $webpCheck) {
        Write-Error "FATAL: ffmpeg binary does not include libwebp encoder. Cannot generate WebP thumbnails."
        exit 1
    }
    Write-Host "    libwebp encoder available: OK"
} catch {
    Write-Error "Failed to check ffmpeg encoders: $_"
    exit 1
}

# --- Write VERSION.txt ---
$versionLine = ($versionOutput | Where-Object { $_ -match "ffmpeg version" }) -replace "ffmpeg version ", "" -replace " Copyright.*", ""
$versionInfo = @"
Source: BtbN/FFmpeg-Builds
URL:    $ReleaseUrl
Version: $versionLine
Fetched: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
License: LGPL (subprocess invocation only — no linking)
"@
Set-Content -LiteralPath $dstVersion -Value $versionInfo
Write-Host "    Wrote -> $dstVersion"

# --- Cleanup temp ---
Remove-Item -Recurse -Force $TempDir

Write-Host ""
Write-Host "==> Done. ffmpeg ready at:"
Write-Host "    $dstFfmpeg"
Write-Host ""
Write-Host "    Size: $([math]::Round($ffmpegSize / 1MB, 1)) MB"
Write-Host "    Run '$dstFfmpeg -version' to verify."
