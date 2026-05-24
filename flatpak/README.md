# HOLLOW — Flatpak

Flatpak build for [HOLLOW](https://hollow.anonlisten.com), a distributed, encrypted communication platform.

## Install

### Prerequisites

- Flatpak with the Flathub remote configured
- [Freedesktop 25.08](https://flathub.org/apps/org.freedesktop.Platform) runtime and SDK
  
  ```bash
  flatpak install flathub org.freedesktop.Platform//25.08 org.freedesktop.Sdk//25.08
  ```

- NVIDIA users: install the matching GL extension
  
  ```bash
  # Check your host driver version
  nvidia-smi --query-gpu=driver_version --format=csv,noheader
  
  # Install the matching flatpak extension (replace version as needed)
  flatpak install flathub org.freedesktop.Platform.GL.nvidia-<version>
  ```

### From a bundle

```bash
flatpak install --user -y --bundle HOLLOW.flatpak
flatpak run com.anonlisten.hollow
```

### Build from source

```bash
flatpak-builder --disable-rofiles-fuse --force-clean flatpak-build flatpak/com.anonlisten.hollow.yml
flatpak build-export repo flatpak-build/
flatpak build-bundle repo HOLLOW.flatpak com.anonlisten.hollow
flatpak install --user -y --bundle HOLLOW.flatpak
```

## NVIDIA Optimus Laptops

On hybrid GPU systems (NVIDIA Optimus), the app may default to the integrated Intel GPU, causing poor performance. Run once to fix:

```bash
flatpak override --user --env=__NV_PRIME_RENDER_OFFLOAD=1 --env=__GLX_VENDOR_LIBRARY_NAME=nvidia com.anonlisten.hollow
```

## Smoke test

```bash
xvfb-run flatpak run com.anonlisten.hollow
```

The app should start and log `fvp plugin version: 0.35.2` within 10 seconds.
