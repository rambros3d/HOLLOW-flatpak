#!/bin/bash
# Build the screen audio capturer/renderer binary for macOS/Linux.
# Run from the project root.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_APP_DIR="$SCRIPT_DIR/../packages/flutter_webrtc/test_apps/screen_audio_test"
BUILD_DIR="$TEST_APP_DIR/build"

echo "=== Building screen_audio_test ==="

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure
if [ ! -f "CMakeCache.txt" ]; then
    echo "Configuring CMake..."
    cmake ..
fi

echo "Building..."
cmake --build . --config Release

EXE="$BUILD_DIR/screen_audio_test"
if [ -f "$EXE" ]; then
    echo "Built: $EXE"
    ls -lh "$EXE"
else
    echo "ERROR: Build output not found"
    exit 1
fi

echo ""
echo "=== Done ==="

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "To bundle into the macOS app:"
    echo "  cp $EXE build/macos/Build/Products/Release/hollow.app/Contents/Resources/screen_audio_capturer"
    echo "  chmod +x build/macos/Build/Products/Release/hollow.app/Contents/Resources/screen_audio_capturer"
elif [[ "$OSTYPE" == "linux"* ]]; then
    echo "To bundle into the Linux app:"
    echo "  cp $EXE build/linux/x64/release/bundle/screen_audio_capturer"
    echo "  chmod +x build/linux/x64/release/bundle/screen_audio_capturer"
fi
