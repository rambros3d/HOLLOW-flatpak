# Screen Audio Test

Standalone test app for WASAPI audio capture + Opus encoding on Windows.
Validates the capture pipeline in isolation before wiring it to WebRTC data channels (Phase 2).

## What it does

Captures system audio or a specific process's audio via WASAPI loopback, Opus-encodes it in real-time, and writes both a raw PCM `.wav` and an Opus-encoded `.ogg` file.

## Build

Requires Visual Studio 2022 and CMake 3.20+. First build downloads Opus v1.5.2 and libogg v1.3.5 via FetchContent.

```
cd packages/flutter_webrtc/test_apps/screen_audio_test
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

## Usage

```
# Capture all desktop audio for 10 seconds
build\Release\screen_audio_test.exe --mode system --duration 10

# Capture all audio EXCEPT this process (EXCLUDE self)
build\Release\screen_audio_test.exe --mode process --duration 10

# Capture ONLY a specific process's audio (INCLUDE mode)
build\Release\screen_audio_test.exe --mode process --pid 12345 --duration 10

# WAV only (skip Opus encoding)
build\Release\screen_audio_test.exe --mode system --format wav

# Custom output basename
build\Release\screen_audio_test.exe --mode system --output my_capture
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--mode` | `system` | `system` (all desktop audio) or `process` (per-process) |
| `--pid` | self | Target PID for process mode. Omit = EXCLUDE self. Specify = INCLUDE only that process |
| `--duration` | `10` | Capture duration in seconds |
| `--format` | `both` | `wav`, `opus`, or `both` |
| `--output` | `captured_audio` | Output file basename (extensions added automatically) |

### Finding a process PID

```powershell
Get-Process | Where-Object { $_.MainWindowTitle } | Format-Table Id, ProcessName, MainWindowTitle -AutoSize
```

## Capture modes

- **System loopback** (`--mode system`): Captures the default audio render endpoint — everything playing through your speakers/headphones. Uses `WasapiLoopbackCapturer` (same as the screen recorder). Requires audio to be playing.

- **Process EXCLUDE** (`--mode process`, no `--pid`): Captures all system audio EXCEPT this test app's own output. Uses `PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE`. Requires Windows 10 2004+ (build 19041).

- **Process INCLUDE** (`--mode process --pid <PID>`): Captures ONLY the specified process's audio output. Uses `PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE`. Fully isolates one app's audio — no bleed from other processes or microphone.

## Output

- `*.wav` — Raw 48kHz stereo 16-bit PCM. Ground truth for verifying capture quality.
- `*.ogg` — Opus-encoded at 128kbps stereo. Playable in VLC, Chrome, ffmpeg, etc.

## Technical details

- WASAPI loopback at 48kHz stereo 16-bit (matches Opus native rate)
- Process loopback uses `ActivateAudioInterfaceAsync` with `AUTOCONVERTPCM` + `SRC_DEFAULT_QUALITY` for 48kHz
- Opus encoder: `OPUS_APPLICATION_AUDIO`, 128kbps, complexity 10
- OGG container per RFC 7845 (OpusHead + OpusTags + audio pages)
- 10ms frames (480 samples/channel) — direct match between WASAPI callback and Opus frame size
