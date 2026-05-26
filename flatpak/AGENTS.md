# HOLLOW Flatpak Build Guide

## Local Dev Build

```bash
flatpak-builder --disable-rofiles-fuse --force-clean flatpak-build com.anonlisten.hollow.yml

flatpak build-export repo flatpak-build/
flatpak build-bundle repo HOLLOW.flatpak com.anonlisten.hollow
flatpak install --user -y --bundle HOLLOW.flatpak
xvfb-run flatpak run com.anonlisten.hollow
```

Output: `HOLLOW.flatpak` (~33 MB).

## Two-Manifest Workflow

| Manifest | Location | Purpose |
|----------|----------|---------|
| `com.anonlisten.hollow.yml` | repo root | Local dev build. Uses `type: dir` source, network access (`--share=network`), prebuilt `flutter_tools.snapshot`. All fixes applied. |
| `flatpak/flatpak-flutter.yml` | `flatpak/` | Flathub submission template for [flatpak-flutter](https://github.com/TheAppgineer/flatpak-flutter). Uses `type: git` sources, no `--share=network`, no prebuilt artifacts. All fixes applied. |

### Local Dev (`com.anonlisten.hollow.yml`)

- Single `flutter-sdk` module + shared-modules libappindicator
- Network enabled for `dart pub get` / `cargo` dependency resolution
- Uses prebuilt `flutter_tools.snapshot` from `flatpak/scripts/`
- Rust/cargokit via rust-stable SDK extension + rustup shim

### Flathub Template (`flatpak/flatpak-flutter.yml`)

Process with flatpak-flutter to generate an offline manifest:
```bash
flatpak-flutter flatpak/flatpak-flutter.yml
```

This pins all Dart and Rust dependencies as manifest sources, replaces the Flutter SDK with a downloadable module, and generates `com.anonlisten.hollow.yml` suitable for Flathub's sandboxed (no-network) build.

## Critical Details

### Rust SDK Extension (`org.freedesktop.Sdk.Extension.rust-stable`)

- Runtime 25.08 provides Rust 1.95.0 at `/usr/lib/sdk/rust-stable/bin/` (cargo, rustc)
- **No `rustup`** — the extension bundles cargo/rustc directly
- Cargokit's build_tool requires `rustup` for toolchain/target management
- **Solution:** Carogkit is patched (see below) and a `rustup` shim is installed before build

### rustup Shim (`flatpak/scripts/rustup-wrapper.sh`)

Arch-aware via `uname -m`. Installed at `/run/build/flutter-sdk/.cargo/bin/rustup` (local dev) or `/run/build/hollow/.cargo/bin/rustup` (Flathub). Handles the commands cargokit calls:

| Command | Shim behavior |
|---------|---------------|
| `rustup toolchain list` | Returns `stable-{arch}-unknown-linux-gnu` (x86_64 or aarch64) |
| `rustup target list --installed` | Returns `{arch}-unknown-linux-gnu` |
| `rustup toolchain install` / `target add` / `component add` | No-op (exit 0) |
| `rustup run <tc> <cmd> ...` | `exec <cmd> ...` (delegates to PATH) |

### Cargokit Patches

- **`run_build_tool.sh`** (line 87): `export PATH="/run/build/flutter-sdk/.cargo/bin:$PATH"` — ensures rustup shim is found by the Dart build_tool
- **Flathub:** patch referenced in `flatpak/foreign.json` — flatpak-flutter applies it during offline manifest generation. Adds `--offline` to cargokit's `dart pub get` calls for network-less builds.
- **Local dev:** patch NOT applied — local builds have `--share=network` and the `--offline` flag prevents cargokit from resolving its own Dart dependencies (`yaml` package).

### Arch Awareness (`$FLATPAK_ARCH`)

Both manifests use `$FLATPAK_ARCH` (Flathub standard env var) to resolve arch-specific paths:

| Component | x86_64 | aarch64 |
|-----------|--------|---------|
| `$FLUTTER_ARCH` | `x64` | `arm64` |
| `$LIBWEBRTC_ARCH_DIR` | `linux-x64` | `linux-arm64` |
| Build output | `build/linux/x64/release/bundle/` | `build/linux/arm64/release/bundle/` |

Detection block is at the top of arch-dependent build-commands (single `|` block since env vars don't persist between separate `sh -c` invocations).

### Flutter SDK Setup (Local Dev)

The manifest provisions a patched Flutter SDK (3.38.5) with:
1. Prebuilt engine stamp (`engine.stamp`)
2. Custom `flutter_tools.snapshot` (from `flatpak/scripts/`)
3. LLVM 20 SDK extension for C/C++ compilation
4. Rust SDK extension for cargo builds

### Library Install

All bundle `.so` files are installed to `/app/bin/lib/` (RPATH-relative, binary has `$ORIGIN/lib`) via `flatpak/scripts/copy-flutter-libs.sh`.

`copy-flutter-libs.sh` accepts `$1` as the Flutter arch (`x64` or `arm64`), defaulting to `x64` for backward compatibility.

All libs are installed — NO exclusions. `libapp.so`, `libflutter_linux_gtk.so`, and `libsuper_native_extensions.so` are all needed.

### Data Directory

```bash
cp -r build/linux/$FLUTTER_ARCH/release/bundle/data /app/bin/data
```

Includes `flutter_assets/` and `icudtl.dat`.

### Runtime Library Path

`LD_LIBRARY_PATH: /app/bin/lib` in both top-level and module `env:` in both manifests — covers the bundled plugin libs (includes libapp.so, libflutter_linux_gtk.so, libsuper_native_extensions.so, and libhollow_core.so).

### WebRTC

- `crow-misia/libwebrtc-bin` 144.7559.3.0, static `.a` build
- 17 header dirs copied: `api audio call common_audio common_video logging media modules net p2p pc rtc_base rtc_tools sdk stats system_wrappers video`
- `svpng.hpp` downloaded from `miloyip/svpng` GitHub
- `packages/flutter_webrtc/linux/CMakeLists.txt` patched for static libwebrtc
- `libwebrtc_missing_symbols.cc` provides stubs for missing `libwebrtc.a` symbols and non-null device/capability factories
- Both x86_64 and aarch64 binary sources declared with `only-arches` and SHA-256 checksums

### Flathub Review Comments

Inline comments in both manifests justify:
- `separate-locales: false` — Flutter bundles i18n in `flutter_assets`; locale splitting saves no space
- `--filesystem=xdg-download` — needed to save received files (peer-to-peer file sharing platform)

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

## CI Workflow (Flathub Simulation)

File: `.github/workflows/flatpak.yml`

**Trigger:** Push of a tag ending in `-flatpak` (e.g., `v1.0.0-flatpak`).

**Container:** `ghcr.io/flathub-infra/flatpak-github-actions:gnome-48` (privileged).

**Steps:**
1. `pip3 install flatpak-flutter` — the same tool Flathub uses to generate offline manifests
2. `flatpak-flutter flatpak/flatpak-flutter.yml` — generates `com.anonlisten.hollow.yml` with all Dart/Rust deps pinned as archive sources, Flutter SDK replaced with downloadable module, `--share=network` removed
3. `flatpak/flatpak-github-actions/flatpak-builder@v6` — builds from the generated offline manifest, produces `HOLLOW.flatpak`
4. Install bundle + `xvfb-run` smoke test (30s timeout — exit 124 = success)
5. `softprops/action-gh-release@v2` — attaches `HOLLOW.flatpak` to the release created by the tag push

**Cache:** Keyed on `hashFiles('flatpak/flatpak-flutter.yml', 'flatpak/foreign.json')`.

**Note:** The generated manifest overwrites the root `com.anonlisten.hollow.yml` (ephemeral CI runner — harmless). First run may fail if the `gnome-48` container lacks `pip3` — add `apt-get install -y python3-pip` if needed.

## Known Issues

- XDG desktop portal warnings in headless/GitHub CI — harmless, only affects dark theme detection
- DRI3 warnings with xvfb — no GPU available, expected
