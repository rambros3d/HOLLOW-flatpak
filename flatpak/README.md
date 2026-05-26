# HOLLOW — Flatpak

Flatpak build for [HOLLOW](https://hollow.anonlisten.com), a distributed, encrypted communication platform.

## Quick Start (Local Dev)

### Prerequisites

```bash
flatpak install flathub org.freedesktop.Platform//25.08 org.freedesktop.Sdk//25.08
flatpak install flathub org.freedesktop.Sdk.Extension.llvm20//25.08
```

NVIDIA users: `flatpak install flathub org.freedesktop.Platform.GL.nvidia-<version>`

### Build & Run

```bash
# Build
flatpak-builder --disable-rofiles-fuse --force-clean flatpak-build ../com.anonlisten.hollow.yml

# Bundle
flatpak build-export repo flatpak-build/
flatpak build-bundle repo HOLLOW.flatpak com.anonlisten.hollow
flatpak install --user -y --bundle HOLLOW.flatpak
flatpak run com.anonlisten.hollow
```

### NVIDIA Optimus Laptops

```bash
flatpak override --user --env=__NV_PRIME_RENDER_OFFLOAD=1 --env=__GLX_VENDOR_LIBRARY_NAME=nvidia com.anonlisten.hollow
```

### Smoke Test

```bash
xvfb-run flatpak run com.anonlisten.hollow
```

Expected: `fvp plugin version: 0.35.2` within 10 seconds.

## Flathub Submission Path

The current manifest (`com.anonlisten.hollow.yml` at repo root) builds locally but needs these changes for submission:

1. **Migrate to [flatpak-flutter](https://github.com/TheAppgineer/flatpak-flutter)** — generates a complete offline manifest with all Dart/Rust dependency sources pinned. Currently uses network during build (`--share=network`, no `--offline`). The cargokit patch at `flatpak/patches/cargokit/` adds `--offline` and is applied during build (safe no-op when `patch` isn't available).

2. **Switch source from `type: dir` to `type: git`** — Flathub builds from remote git tags, not local directories.

3. **Add aarch64 build-commands** — Currently hardcoded `linux-x64` paths in header copy and lib installation. Source block for aarch64 libwebrtc is already present.

### Flathub Requirements Status

| Requirement | Status |
|------------|--------|
| Build from source | ⚠️ Needs flatpak-flutter migration |
| No network during build | ⚠️ cargokit patch available, flatpak-flutter needed for deps |
| Rust/cargokit handling | ✅ rustup shim + patch ready |
| libwebrtc binary | ✅ Declared as `type: archive` with URL + sha256 (standard for Flathub — WebRTC too large to build from source) |
| aarch64 support | ✅ Source block added; build-commands need arch-awareness |
| Finish-args clean | ✅ `--socket=camera` + `--socket=pulseaudio`, no `--device=all` |
| Metainfo complete | ❌ Needs screenshots, releases, content_rating, categories |
