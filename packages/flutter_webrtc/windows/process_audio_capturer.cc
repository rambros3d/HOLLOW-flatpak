// Process-specific audio loopback capture.
// Captures all system audio EXCEPT the calling process's own output.
// Uses AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK (Windows 10 2004+).
//
// Key API quirks (from Microsoft Q&A + samples):
// - GetMixFormat() returns E_NOTIMPL on process loopback clients
// - Must use hardcoded format (16-bit PCM, 48kHz stereo)
// - Do NOT use AUDCLNT_STREAMFLAGS_LOOPBACK (conflicts with activation)
// - AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM handles resampling internally

#include "process_audio_capturer.h"

#include <audioclientactivationparams.h>
#include <avrt.h>
#include <mmreg.h>

#include <cstring>
#include <vector>

#include "capture_log.h"

#pragma comment(lib, "mmdevapi.lib")
#pragma comment(lib, "Avrt.lib")

namespace flutter_webrtc_plugin {

// --- Static support check ---

bool ProcessAudioCapturer::IsSupported() {
  OSVERSIONINFOEXW osvi = {};
  osvi.dwOSVersionInfoSize = sizeof(osvi);
  osvi.dwBuildNumber = 19041;
  DWORDLONG mask = 0;
  VER_SET_CONDITION(mask, VER_BUILDNUMBER, VER_GREATER_EQUAL);
  return VerifyVersionInfoW(&osvi, VER_BUILDNUMBER, mask) != FALSE;
}

// --- ActivationHandler ---

ProcessAudioCapturer::ActivationHandler::ActivationHandler() {
  event_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
}

HRESULT ProcessAudioCapturer::ActivationHandler::ActivateCompleted(
    IActivateAudioInterfaceAsyncOperation* operation) {
  HRESULT hr_activate = E_UNEXPECTED;
  ComPtr<IUnknown> unknown;
  HRESULT hr = operation->GetActivateResult(&hr_activate, &unknown);
  if (SUCCEEDED(hr) && SUCCEEDED(hr_activate) && unknown) {
    unknown.As(&audio_client_);
  }
  activate_hr_ = SUCCEEDED(hr) ? hr_activate : hr;
  SetEvent(event_);
  return S_OK;
}

void ProcessAudioCapturer::ActivationHandler::Wait() {
  if (event_) {
    WaitForSingleObject(event_, 5000);
    CloseHandle(event_);
    event_ = nullptr;
  }
}

// --- ProcessAudioCapturer ---

ProcessAudioCapturer::ProcessAudioCapturer() {
  stop_event_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
}

ProcessAudioCapturer::~ProcessAudioCapturer() {
  Stop();
  if (stop_event_) {
    CloseHandle(stop_event_);
    stop_event_ = nullptr;
  }
}

bool ProcessAudioCapturer::Start(FrameCallback cb) {
  if (running_.load()) return true;
  callback_ = std::move(cb);
  ResetEvent(stop_event_);

  running_ = true;
  thread_ = std::thread([this]() { CaptureThread(); });
  return true;
}

void ProcessAudioCapturer::Stop() {
  if (!running_.exchange(false)) return;
  SetEvent(stop_event_);
  if (thread_.joinable()) {
    thread_.join();
  }
  CAPLOG("ProcessAudioCapturer: Stopped");
}

void ProcessAudioCapturer::CaptureThread() {
  HRESULT hr_com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const bool com_initialized = SUCCEEDED(hr_com);

  auto cleanup = [&]() {
    if (com_initialized) CoUninitialize();
    running_ = false;
  };

  // --- Activate process loopback ---
  AUDIOCLIENT_ACTIVATION_PARAMS activation_params = {};
  activation_params.ActivationType =
      AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK;
  activation_params.ProcessLoopbackParams.TargetProcessId =
      GetCurrentProcessId();
  activation_params.ProcessLoopbackParams.ProcessLoopbackMode =
      PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE;

  PROPVARIANT activate_params = {};
  activate_params.vt = VT_BLOB;
  activate_params.blob.cbSize = sizeof(activation_params);
  activate_params.blob.pBlobData =
      reinterpret_cast<BYTE*>(&activation_params);

  auto handler = Microsoft::WRL::Make<ActivationHandler>();
  ComPtr<IActivateAudioInterfaceAsyncOperation> async_op;

  HRESULT hr = ActivateAudioInterfaceAsync(
      VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK,
      __uuidof(IAudioClient),
      &activate_params,
      handler.Get(),
      &async_op);

  if (FAILED(hr)) {
    CAPLOG("ProcessAudioCapturer: ActivateAudioInterfaceAsync failed 0x%08x", hr);
    cleanup();
    return;
  }

  handler->Wait();

  if (FAILED(handler->GetActivateResult())) {
    CAPLOG("ProcessAudioCapturer: Activation failed 0x%08x",
           handler->GetActivateResult());
    cleanup();
    return;
  }

  ComPtr<IAudioClient> audio_client = handler->GetAudioClient();
  if (!audio_client) {
    CAPLOG("ProcessAudioCapturer: No audio client after activation");
    cleanup();
    return;
  }

  // --- Hardcoded format: 16-bit PCM stereo 44100Hz ---
  // GetMixFormat() returns E_NOTIMPL on process loopback clients.
  // Must match Microsoft's ApplicationLoopback sample exactly.
  WAVEFORMATEX format = {};
  format.wFormatTag = WAVE_FORMAT_PCM;
  format.nChannels = 2;
  format.nSamplesPerSec = 44100;
  format.wBitsPerSample = 16;
  format.nBlockAlign = format.nChannels * format.wBitsPerSample / 8;
  format.nAvgBytesPerSec = format.nSamplesPerSec * format.nBlockAlign;
  format.cbSize = 0;

  // --- Create capture event ---
  HANDLE capture_event = CreateEventW(nullptr, FALSE, FALSE, nullptr);

  // --- Initialize audio client ---
  // Flags must include LOOPBACK even with process loopback activation
  // (per Microsoft's ApplicationLoopback sample).
  hr = audio_client->Initialize(
      AUDCLNT_SHAREMODE_SHARED,
      AUDCLNT_STREAMFLAGS_LOOPBACK |
          AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
          AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM,
      0,
      0,
      &format,
      nullptr);

  if (FAILED(hr)) {
    CAPLOG("ProcessAudioCapturer: Initialize failed 0x%08x", hr);
    CloseHandle(capture_event);
    cleanup();
    return;
  }

  hr = audio_client->SetEventHandle(capture_event);
  if (FAILED(hr)) {
    CAPLOG("ProcessAudioCapturer: SetEventHandle failed 0x%08x", hr);
    CloseHandle(capture_event);
    cleanup();
    return;
  }

  ComPtr<IAudioCaptureClient> capture_client;
  hr = audio_client->GetService(__uuidof(IAudioCaptureClient),
                                 reinterpret_cast<void**>(
                                     capture_client.ReleaseAndGetAddressOf()));
  if (FAILED(hr)) {
    CAPLOG("ProcessAudioCapturer: GetService failed 0x%08x", hr);
    CloseHandle(capture_event);
    cleanup();
    return;
  }

  DWORD task_index = 0;
  HANDLE mm_task = AvSetMmThreadCharacteristicsW(L"Pro Audio", &task_index);

  hr = audio_client->Start();
  if (FAILED(hr)) {
    CAPLOG("ProcessAudioCapturer: Start failed 0x%08x", hr);
    if (mm_task) AvRevertMmThreadCharacteristics(mm_task);
    CloseHandle(capture_event);
    cleanup();
    return;
  }

  CAPLOG("ProcessAudioCapturer: Started (exclude PID %u, 44100Hz stereo 16-bit)",
         GetCurrentProcessId());

  // --- Capture loop ---
  const UINT32 sample_rate = format.nSamplesPerSec;  // 44100
  const size_t frames_per_10ms = sample_rate / 100;   // 441
  const size_t samples_per_10ms = frames_per_10ms * 2; // stereo
  std::vector<int16_t> accum;
  accum.reserve(samples_per_10ms * 2);

  HANDLE wait_handles[2] = { capture_event, stop_event_ };

  while (running_.load()) {
    DWORD wait = WaitForMultipleObjects(2, wait_handles, FALSE, 2000);
    if (!running_.load() || wait == WAIT_OBJECT_0 + 1) break;
    if (wait != WAIT_OBJECT_0) continue;

    UINT32 packet_frames = 0;
    while (SUCCEEDED(capture_client->GetNextPacketSize(&packet_frames)) &&
           packet_frames > 0 && running_.load()) {
      BYTE* raw = nullptr;
      UINT32 frames_available = 0;
      DWORD flags = 0;
      hr = capture_client->GetBuffer(&raw, &frames_available, &flags,
                                      nullptr, nullptr);
      if (FAILED(hr)) break;

      const size_t total_samples =
          static_cast<size_t>(frames_available) * 2;
      const size_t prev_size = accum.size();
      accum.resize(prev_size + total_samples);
      int16_t* out = accum.data() + prev_size;

      if (flags & AUDCLNT_BUFFERFLAGS_SILENT) {
        std::memset(out, 0, total_samples * sizeof(int16_t));
      } else {
        std::memcpy(out, raw, total_samples * sizeof(int16_t));
      }

      capture_client->ReleaseBuffer(frames_available);

      size_t emit_offset = 0;
      while (accum.size() - emit_offset >= samples_per_10ms) {
        if (callback_) {
          callback_(accum.data() + emit_offset, 16,
                    static_cast<int>(sample_rate), 2, frames_per_10ms);
        }
        emit_offset += samples_per_10ms;
      }
      if (emit_offset > 0) {
        accum.erase(accum.begin(), accum.begin() + emit_offset);
      }

      capture_client->GetNextPacketSize(&packet_frames);
    }
  }

  // --- Cleanup ---
  audio_client->Stop();
  if (mm_task) AvRevertMmThreadCharacteristics(mm_task);
  capture_client.Reset();
  audio_client.Reset();
  CloseHandle(capture_event);
  if (com_initialized) CoUninitialize();
}

}  // namespace flutter_webrtc_plugin
