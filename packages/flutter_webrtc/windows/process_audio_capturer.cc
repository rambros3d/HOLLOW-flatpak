#include "process_audio_capturer.h"

#include <audioclientactivationparams.h>
#include <avrt.h>
#include <mmreg.h>
#include <winternl.h>

#include <cstdio>
#include <cstring>
#include <vector>

#pragma comment(lib, "mmdevapi.lib")
#pragma comment(lib, "Avrt.lib")
#pragma comment(lib, "ntdll.lib")

namespace flutter_webrtc_plugin {

bool ProcessAudioCapturer::IsSupported() {
  using RtlGetVersionFn = NTSTATUS(WINAPI*)(PRTL_OSVERSIONINFOW);
  auto RtlGetVersion = reinterpret_cast<RtlGetVersionFn>(
      GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));
  if (!RtlGetVersion) return false;

  RTL_OSVERSIONINFOW osvi = {};
  osvi.dwOSVersionInfoSize = sizeof(osvi);
  if (RtlGetVersion(&osvi) != 0) return false;

  return osvi.dwBuildNumber >= 19041;
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

ComPtr<IAudioClient> ProcessAudioCapturer::ActivateProcessLoopback(
    DWORD pid, bool include_mode) {
  AUDIOCLIENT_ACTIVATION_PARAMS activation_params = {};
  activation_params.ActivationType =
      AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK;
  activation_params.ProcessLoopbackParams.TargetProcessId = pid;
  activation_params.ProcessLoopbackParams.ProcessLoopbackMode =
      include_mode ? PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE
                   : PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE;

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

  if (FAILED(hr)) return nullptr;

  handler->Wait();

  if (FAILED(handler->GetActivateResult())) return nullptr;

  return handler->GetAudioClient();
}

bool ProcessAudioCapturer::Start(FrameCallback cb, DWORD target_pid,
                                 bool include_mode) {
  if (running_.load()) return true;
  callback_ = std::move(cb);
  target_pid_ = target_pid ? target_pid : GetCurrentProcessId();
  include_mode_ = include_mode;
  ResetEvent(stop_event_);

  running_ = true;
  thread_ = std::thread([this]() { CaptureThread(); });
  return true;
}

void ProcessAudioCapturer::Stop() {
  if (!running_.exchange(false)) return;
  SetEvent(stop_event_);
  if (thread_.joinable()) thread_.join();
}

void ProcessAudioCapturer::CaptureThread() {
  HRESULT hr_com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const bool com_initialized = SUCCEEDED(hr_com);

  auto final_cleanup = [&]() {
    if (com_initialized) CoUninitialize();
    running_ = false;
  };

  // Try 48kHz first, then fall back to 44.1kHz.
  static const UINT32 rates[] = {48000, 44100};
  ComPtr<IAudioClient> audio_client;
  UINT32 chosen_rate = 0;

  for (UINT32 rate : rates) {
    ComPtr<IAudioClient> client =
        ActivateProcessLoopback(target_pid_, include_mode_);
    if (!client) {
      final_cleanup();
      return;
    }

    WAVEFORMATEX format = {};
    format.wFormatTag = WAVE_FORMAT_PCM;
    format.nChannels = 2;
    format.nSamplesPerSec = rate;
    format.wBitsPerSample = 16;
    format.nBlockAlign = format.nChannels * format.wBitsPerSample / 8;
    format.nAvgBytesPerSec = rate * format.nBlockAlign;
    format.cbSize = 0;

    HRESULT hr = client->Initialize(
        AUDCLNT_SHAREMODE_SHARED,
        AUDCLNT_STREAMFLAGS_LOOPBACK |
            AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
            AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
            AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
        0, 0, &format, nullptr);

    if (SUCCEEDED(hr)) {
      audio_client = client;
      chosen_rate = rate;
      break;
    }
  }

  if (!audio_client) {
    final_cleanup();
    return;
  }

  actual_sample_rate_.store(static_cast<int>(chosen_rate));

  HANDLE capture_event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  HRESULT hr = audio_client->SetEventHandle(capture_event);
  if (FAILED(hr)) {
    CloseHandle(capture_event);
    final_cleanup();
    return;
  }

  ComPtr<IAudioCaptureClient> capture_client;
  hr = audio_client->GetService(
      __uuidof(IAudioCaptureClient),
      reinterpret_cast<void**>(capture_client.ReleaseAndGetAddressOf()));
  if (FAILED(hr)) {
    CloseHandle(capture_event);
    final_cleanup();
    return;
  }

  DWORD task_index = 0;
  HANDLE mm_task = AvSetMmThreadCharacteristicsW(L"Pro Audio", &task_index);

  hr = audio_client->Start();
  if (FAILED(hr)) {
    if (mm_task) AvRevertMmThreadCharacteristics(mm_task);
    CloseHandle(capture_event);
    final_cleanup();
    return;
  }

  const size_t frames_per_10ms = chosen_rate / 100;
  const size_t samples_per_10ms = frames_per_10ms * 2;
  std::vector<int16_t> accum;
  accum.reserve(samples_per_10ms * 2);

  HANDLE wait_handles[2] = {capture_event, stop_event_};

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
                    static_cast<int>(chosen_rate), 2, frames_per_10ms);
        }
        emit_offset += samples_per_10ms;
      }
      if (emit_offset > 0) {
        accum.erase(accum.begin(), accum.begin() + emit_offset);
      }

      capture_client->GetNextPacketSize(&packet_frames);
    }
  }

  audio_client->Stop();
  if (mm_task) AvRevertMmThreadCharacteristics(mm_task);
  capture_client.Reset();
  audio_client.Reset();
  CloseHandle(capture_event);
  if (com_initialized) CoUninitialize();
}

}  // namespace flutter_webrtc_plugin
