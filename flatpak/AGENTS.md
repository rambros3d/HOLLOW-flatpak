# HOLLOW Flatpak Build Guide

## Build & Bundle

```bash
# Full build (clean)
flatpak-builder --disable-rofiles-fuse --force-clean flatpak-build flatpak/com.anonlisten.hollow.yml

# Export and bundle
flatpak build-export repo flatpak-build/
flatpak build-bundle repo HOLLOW.flatpak com.anonlisten.hollow

# Install and test locally
flatpak install --user -y --bundle HOLLOW.flatpak
xvfb-run flatpak run com.anonlisten.hollow
```

Output: `HOLLOW.flatpak` (~33 MB).

## Manifest Structure

`flatpak/com.anonlisten.hollow.yml` — single `flutter-sdk` module + shared-modules libappindicator:

| # | Module | System | Purpose |
|---|--------|--------|---------|
| 1 | `shared-modules/libappindicator/...` | autotools | GTK tray icon via `libappindicator3` |
| 2 | `flutter-sdk` | simple | Flutter SDK + project source → `flutter build linux --release` |

## Critical Details

### Rust SDK Extension (`org.freedesktop.Sdk.Extension.rust-stable`)

- Runtime 25.08 provides Rust 1.95.0 at `/usr/lib/sdk/rust-stable/bin/` (cargo, rustc)
- **No `rustup`** — the extension bundles cargo/rustc directly
- Cargokit's build_tool requires `rustup` for toolchain/target management
- **Solution:** Carogkit is patched (see below) and a `rustup` shim is installed before build

### rustup Shim (`flatpak/scripts/rustup-wrapper.sh`)

Installed at `/run/build/flutter-sdk/.cargo/bin/rustup` during build. Handles the commands cargokit calls:

| Command | Shim behavior |
|---------|---------------|
| `rustup toolchain list` | Returns `stable-x86_64-unknown-linux-gnu` |
| `rustup target list --installed` | Returns `x86_64-unknown-linux-gnu` |
| `rustup toolchain install` / `target add` / `component add` | No-op (exit 0) |
| `rustup run <tc> <cmd> ...` | `exec <cmd> ...` (delegates to PATH) |

### Cargokit Patches

- **`run_build_tool.sh`** (line 87): `export PATH="/run/build/flutter-sdk/.cargo/bin:$PATH"` — ensures rustup shim is found by the Dart build_tool
- **`--offline` removed** from both `dart pub get` calls (lines 75, 93) — network needed for dependency resolution

### Flutter SDK Setup

The manifest provisions a patched Flutter SDK (3.38.5) with:
1. Prebuilt engine stamp (`engine.stamp`)
2. Custom `flutter_tools.snapshot` (from `flatpak/scripts/`)
3. LLVM 20 SDK extension for C/C++ compilation
4. Rust SDK extension for cargo builds

### Library Install

All bundle `.so` files are installed to `/app/bin/lib/` (RPATH-relative, binary has `$ORIGIN/lib`):

```bash
for f in build/linux/x64/release/bundle/lib/lib*.so*; do
  install -Dm755 "$f" /app/bin/lib/
done
```

All libs are installed — NO exclusions. `libapp.so`, `libflutter_linux_gtk.so`, and `libsuper_native_extensions.so` are all needed.

### Data Directory

```bash
cp -r build/linux/x64/release/bundle/data /app/bin/data
```

Includes `flutter_assets/` and `icudtl.dat`.

### Runtime Library Path

`LD_LIBRARY_PATH: /app/lib/lib:/app/bin/lib` in both top-level and module `env:` — covers both the main libs and the bundled plugin libs.

### WebRTC

- `crow-misia/libwebrtc-bin` 144.7559.3.0, static `.a` build
- 17 header dirs copied: `api audio call common_audio common_video logging media modules net p2p pc rtc_base rtc_tools sdk stats system_wrappers video`
- `svpng.hpp` downloaded from `miloyip/svpng` GitHub
- `packages/flutter_webrtc/linux/CMakeLists.txt` patched for static libwebrtc
- `libwebrtc_missing_symbols.cc` provides stubs for missing `libwebrtc.a` symbols and non-null device/capability factories

## Smoke Test

Inside CI or a headless environment:

```bash
xvfb-run flatpak run com.anonlisten.hollow
```

Expected output (within 10s):
```
fvp plugin version: 0.35.2
```
Exit code 124 (timeout) = success (app runs without crashing). Missing library errors indicate broken install.

## Known Issues

- XDG desktop portal warnings in headless/GitHub CI — harmless, only affects dark theme detection
- DRI3 warnings with xvfb — no GPU available, expected
