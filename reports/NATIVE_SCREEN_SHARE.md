# Native Screen Share — Windows Implementation

## Overview

Windows screen sharing uses a native C++ capture pipeline integrated into the forked `flutter_webrtc` plugin. The pipeline captures screen content via Windows Graphics Capture (WGC) and feeds frames directly into WebRTC, bypassing libwebrtc's built-in `DesktopCapturer`.

macOS uses ScreenCaptureKit (implemented in the fork's `macos/Classes/`). Linux uses the libwebrtc built-in capturer.

## Architecture

### Video Pipeline
```
Windows.Graphics.Capture (BGRA32 texture, GPU)
  → CopyResource to BGRA staging texture (GPU → CPU)
  → libyuv ARGBToI420 via RTCVideoFrame::CreateFromBGRA (CPU, AVX2/SSSE3)
  → RTCVideoSource::OnCapturedFrame()
  → VP8 software encoder → RTP
```

No D3D11 Video Processor is used in the screen share path — BGRA goes directly to libyuv for color-accurate conversion. The VP (used in earlier iterations) applied color space transforms that darkened the image.

### Audio Pipeline (Windows 11 only)
```
AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK
  → Captures all system audio EXCEPT Hollow's own process
  → 44100Hz stereo 16-bit PCM (Microsoft's recommended format)
  → 10ms chunked → RTCAudioSource::CaptureFrame()
  → Opus encoder → RTP
```

Process-specific audio capture requires Windows 10 2004+ (build 19041) but the `EXCLUDE_TARGET_PROCESS_TREE` mode only works reliably on Windows 11. The audio toggle is locked on Windows in the screen share dialog with a warning message. Falls back to `WasapiLoopbackCapturer` (global loopback with echo) if `ProcessAudioCapturer` fails.

### Custom libwebrtc.dll

The Windows flutter_webrtc fork requires a custom-built `libwebrtc.dll` (not the prebuilt one from flutter-webrtc releases). The custom DLL adds:

- `RTCVideoSource::OnCapturedFrame()` — push externally-captured frames into WebRTC
- `RTCVideoFrame::CreateFromBGRA()` — libyuv AVX2/SSSE3 BGRA→I420
- `RTCVideoFrame::CreateFromNV12()` — libyuv NV12→I420
- `RTCPeerConnectionFactory::CreateCustomVideoSource()` — create video source without hardware capturer
- `MFVideoEncoderFactory` — Media Foundation hardware H.264 encoder (NVENC/AMF/QSV), available but not default (VP8 is preferred for screen share)

## Files

### flutter_webrtc fork (`packages/flutter_webrtc/`)
| File | Purpose |
|------|---------|
| `windows/win_screen_recorder.h/.cc` | WGC capture engine, D3D11 device, BGRA frame delivery |
| `windows/win_screen_share_capturer.h/.cc` | Bridges BGRA frames to WebRTC via CreateFromBGRA |
| `windows/process_audio_capturer.h/.cc` | Process-specific audio loopback (Win11) |
| `windows/wasapi_loopback_capturer.h/.cc` | Global WASAPI loopback (fallback, has echo) |
| `windows/capture_log.h` | File-based diagnostic logging to `%APPDATA%\.hollow\capture_debug.log` |
| `common/cpp/include/flutter_screen_capture.h` | Screen capture orchestration header |
| `common/cpp/src/flutter_screen_capture.cc` | GetDisplayMedia: native capturer branch + audio integration |
| `third_party/libwebrtc/include/*.h` | Custom DLL public API headers |
| `third_party/libwebrtc/lib/win64/libwebrtc.dll` | Custom-built DLL with OnCapturedFrame + MF encoder |

### Dart
| File | Purpose |
|------|---------|
| `lib/src/core/services/screen_share_service.dart` | VP8 codec preference, screen content encoding config |
| `lib/src/ui/dialogs/screen_share_dialog.dart` | Audio toggle locked on Windows with warning |

### Custom DLL build environment (`D:\libwebrtc-build\`, not in repo)
| File | Purpose |
|------|---------|
| `src/libwebrtc/src/win/mf_video_encoder.h/.cc` | MF hardware H.264 encoder |
| `src/libwebrtc/src/win/mf_video_encoder_factory.h/.cc` | VideoEncoderFactory for MF encoder |
| `src/libwebrtc/src/rtc_peerconnection_factory_impl.cc` | USE_MF_ENCODER factory wiring |
| `src/libwebrtc/BUILD.gn` | `libwebrtc_mf_encoder` build flag |
| `src/out/Windows-x64/args.gn` | Build configuration |

## Building the Custom DLL

The DLL and headers are committed to the repo — you only need to rebuild if modifying the DLL's internal code (e.g. the MF encoder).

### Prerequisites
- Visual Studio 2022 with C++ desktop development
- Windows 11 SDK (26100)
- ~30 GB disk space for WebRTC source tree

### Setup (one-time)
```powershell
# Clone depot_tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git D:\libwebrtc-build\depot_tools

# Fetch WebRTC source (m144 branch)
cd D:\libwebrtc-build
$env:PATH = "D:\libwebrtc-build\depot_tools;$env:PATH"
fetch --no-history webrtc

# Apply patches (see NATIVE_SCREEN_CAPTURE_RESEARCH.md for details)
# - custom_audio_source_m144.patch
# - CreateFromBGRA/CreateFromNV12 in rtc_video_frame_impl.cc
# - OnCapturedFrame in rtc_video_source_impl.cc
# - MF encoder files in src/win/
```

### Build
```powershell
$env:PATH = "D:\libwebrtc-build\depot_tools;$env:PATH"
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"
$env:GYP_MSVS_VERSION = "2022"
cd D:\libwebrtc-build\src

gn gen out/Windows-x64
ninja -C out/Windows-x64 libwebrtc:libwebrtc

# Copy to flutter_webrtc fork
Copy-Item "out\Windows-x64\libwebrtc.dll" "packages\flutter_webrtc\third_party\libwebrtc\lib\win64\" -Force
Copy-Item "out\Windows-x64\libwebrtc.dll.lib" "packages\flutter_webrtc\third_party\libwebrtc\lib\win64\" -Force
```

### args.gn
```
target_os = "win"
target_cpu = "x64"
is_debug = false
is_component_build = false
rtc_use_h264 = true
ffmpeg_branding = "Chrome"
rtc_include_tests = false
rtc_build_examples = false
libwebrtc_mf_encoder = true
```

## Known Limitations

- **Audio on Windows 10**: The `PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE` API doesn't reliably exclude the app's own audio output on Windows 10. Audio toggle is locked in the UI. Expected to work on Windows 11.
- **MF H.264 encoder**: Built and available in the DLL but VP8 is the default codec for screen share. H.264 can be explicitly negotiated via `setCodecPreferences` but decode reliability varies across peers.
- **Yellow border**: Windows Graphics Capture shows a yellow border around the captured screen. This is a WGC platform requirement.
- **Software VP8 encoding**: Screen content is encoded with VP8 on CPU. Hardware encoding (MF H.264) is available but not default due to cross-peer decode compatibility.
