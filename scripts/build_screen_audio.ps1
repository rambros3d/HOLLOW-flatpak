# Build the screen audio capturer/renderer binary.
# Windows: builds + copies to Flutter Release folder via CMake install.
# Run from the project root.

$ErrorActionPreference = "Stop"

$testAppDir = Join-Path $PSScriptRoot "..\packages\flutter_webrtc\test_apps\screen_audio_test"
$buildDir = Join-Path $testAppDir "build"

Write-Host "=== Building screen_audio_test ===" -ForegroundColor Cyan

if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory $buildDir | Out-Null
}

Push-Location $buildDir
try {
    # Configure if needed
    if (-not (Test-Path "CMakeCache.txt")) {
        Write-Host "Configuring CMake..." -ForegroundColor Yellow
        cmake .. -G "Visual Studio 17 2022" -A x64
    }

    Write-Host "Building Release..." -ForegroundColor Yellow
    cmake --build . --config Release

    $exe = Join-Path $buildDir "Release\screen_audio_test.exe"
    if (Test-Path $exe) {
        Write-Host "Built: $exe" -ForegroundColor Green

        # Check size
        $size = (Get-Item $exe).Length / 1KB
        Write-Host ("Size: {0:N0} KB" -f $size)
    } else {
        Write-Host "ERROR: Build output not found" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "The exe is bundled automatically via windows/CMakeLists.txt during 'flutter build windows'."
Write-Host "For manual testing, copy screen_audio_test.exe next to hollow.exe."
