# HOLLOW Flatpak Build Guide

## Build Command

```bash
flatpak-builder --disable-rofiles-fuse --user --install flatpak-build flatpak/com.anonlisten.hollow.yml
flatpak build-export repo flatpak-build/
flatpak build-bundle repo HOLLOW.flatpak com.anonlisten.hollow
```

Output: `HOLLOW.flatpak` (~32-69 MB).

## Manifest Structure

`flatpak/com.anonlisten.hollow.yml` — 8 modules:

| # | Module | System | Purpose |
|---|--------|--------|---------|
| 1 | `flutter-sdk` | simple | git clone flutter 3.38.5, `precache --linux` |
| 2 | `ffmpeg` | simple | BtbN static builds, strip to `bin/ffmpeg` |
| 3 | `intltool` | autotools | libdbusmenu dependency |
| 4 | `dbus-glib` | autotools | libdbusmenu dependency |
| 5 | `libdbusmenu` | **simple** | two-pass autoreconf + `HAVE_VALGRIND` sed patch |
| 6 | `libindicator` | autotools | shell sed patch for `$LIBM` |
| 7 | `libappindicator` | autotools | Python stubs + `-Wno-incompatible-pointer-types` |
| 8 | `hollow` | simple | flutter pub get → flutter build linux --release |

## Critical Module Details

### libdbusmenu (module 5)
**Must use `buildsystem: simple`** — autotools buildsystem applies `type: shell` patches AFTER autoreconf, so the `HAVE_VALGRIND` patch never takes effect.

Build commands:
1. `sed -i '/^AM_CONDITIONAL(\[HAVE_VALGRIND\]/d' configure.ac`
2. `sed -i '/^AC_SUBST(DBUSMENUTESTS_CFLAGS)/i\AM_CONDITIONAL([HAVE_VALGRIND], [false])' configure.ac`
3. `autoreconf -sfi`
4. `./configure --prefix=/app --disable-tests --disable-gtk-doc`
5. `make -j$(nproc) && make install`

### libappindicator (module 7)
Python detection requires three workarounds:
1. `type: shell` patch: `sed -i 's/AM_PATH_PYTHON(2.3.5)/PYTHON=echo; AC_SUBST(PYTHON)/' configure.ac`
2. `type: shell` patch: `sed -i 's/AM_CHECK_PYTHON_HEADERS.*/true/' configure.ac`
3. `build-options.env`: `APPINDICATOR_PYTHON_CFLAGS: " "`, `APPINDICATOR_PYTHON_LIBS: " "`
4. `CFLAGS: -Wno-error -Wno-incompatible-pointer-types` (GCC 14+ fix)

### hollow (module 8)
- Sources: `type: dir` at `path: .` (repo root) + flutter git + libwebrtc archive + svpng download
- `build-options.append-path`: `.../llvm19/bin:.../rust-stable/bin:...flutter/bin`
- `build-options.env`: `CXX: /usr/bin/g++`, `CC: /usr/bin/gcc`
- Must install `libapp.so` to `/app/bin/lib/` and copy `data/` to `/app/bin/data/`
- Must exclude `libapp.so`, `libflutter_linux_gtk.so`, `libsuper_native_extensions.so` from the `.so` bulk install

### WebRTC setup (in hollow module)
- `crow-misia/libwebrtc-bin` 144.7559.3.0, static `.a` build
- Copy 17 header dirs: `api audio call common_audio common_video logging media modules net p2p pc rtc_base rtc_tools sdk stats system_wrappers video`
- Download `svpng.hpp` from `miloyip/svpng` GitHub raw
- `packages/flutter_webrtc/linux/CMakeLists.txt` patched for static libwebrtc (`.a` instead of `.so`)

## Runtime Requirements
- `env: LD_LIBRARY_PATH: /app/lib/lib` at top-level manifest (for plugin `.so` resolution)
- `libwebrtc_missing_symbols.cc` provides stubs for missing `libwebrtc.a` symbols and non-null device/capability factories

## DOs and DON'Ts

### DO
- Use `--disable-rofiles-fuse` — stale FUSE mounts from aborted runs cause failures
- Register the runtime SDK extension paths in `append-path` — they're not on `PATH` by default
- Set `CFLAGS: -Wno-error` on all old autotools projects (GCC 14+ is stricter)
- Install `libapp.so` and `data/flutter_assets/` — `FlutterEngineCreateAOTData` will SIGSEGV without them
- Use `buildsystem: simple` when `type: shell` patches modify `configure.ac` — autotools buildsystem runs autoreconf AFTER patches
- Set `CC`/`CXX` to GCC explicitly — Flutter's bundled LLVM has issues with some native deps
- Pass empty-but-non-null env vars to skip `PKG_CHECK_MODULES` checks (e.g. `APPINDICATOR_PYTHON_CFLAGS: " "`)

### DON'T
- Don't use `--no-pub` flag on `flutter build` — it doesn't exist; run `flutter pub get` separately
- Don't exclude `libapp.so` from install — the Flutter engine AOT loader needs it
- Don't add `install -D` flag on the binary install step — just `install -Dm755`
- Don't use `-Dm644` on `.so` files — they need executable permission (`-Dm755`)
- Don't delete `AC_CONFIG_FILES` entries from `configure.ac` — causes syntax errors in generated configure
- Don't skip `HAVE_VALGRIND` check by deleting the `AM_CONDITIONAL` — flatpak-builder errors on undefined conditionals; move it outside the `AS_IF` block instead
- Don't use `buildsystem: autotools` for modules needing `configure.ac` patches — `type: shell` patches run before autoreconf but autotools system re-runs autoreconf again, overwriting the patch
- Don't use `--disable-python` on libappindicator — the flag doesn't exist, use the stub+env approach
