#ifndef SCREEN_AUDIO_TEST_PROCESS_AUDIO_CAPTURER_H_
#define SCREEN_AUDIO_TEST_PROCESS_AUDIO_CAPTURER_H_

#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <ksmedia.h>
#include <wrl/client.h>
#include <wrl/implements.h>

#include <atomic>
#include <functional>
#include <thread>

using Microsoft::WRL::ComPtr;
using Microsoft::WRL::RuntimeClass;
using Microsoft::WRL::RuntimeClassFlags;
using Microsoft::WRL::ClassicCom;
using Microsoft::WRL::FtmBase;

class ProcessAudioCapturer {
 public:
  using FrameCallback = std::function<void(const void* data,
                                           int bits_per_sample,
                                           int sample_rate,
                                           size_t channels,
                                           size_t frames)>;

  ProcessAudioCapturer();
  ~ProcessAudioCapturer();

  ProcessAudioCapturer(const ProcessAudioCapturer&) = delete;
  ProcessAudioCapturer& operator=(const ProcessAudioCapturer&) = delete;

  static bool IsSupported();

  // Start capturing.
  // target_pid = 0: uses GetCurrentProcessId() (self)
  // include_mode = false: EXCLUDE target (capture everything else)
  // include_mode = true:  INCLUDE target only (capture only that process)
  bool Start(FrameCallback cb, DWORD target_pid = 0,
             bool include_mode = false);
  void Stop();

  int actual_sample_rate() const { return actual_sample_rate_.load(); }

 private:
  class ActivationHandler
      : public RuntimeClass<RuntimeClassFlags<ClassicCom>,
                            IActivateAudioInterfaceCompletionHandler,
                            FtmBase> {
   public:
    ActivationHandler();
    STDMETHOD(ActivateCompleted)(
        IActivateAudioInterfaceAsyncOperation* operation) override;

    HRESULT GetActivateResult() const { return activate_hr_; }
    ComPtr<IAudioClient> GetAudioClient() const { return audio_client_; }
    void Wait();

   private:
    HANDLE event_ = nullptr;
    HRESULT activate_hr_ = E_UNEXPECTED;
    ComPtr<IAudioClient> audio_client_;
  };

  // Activate an IAudioClient via ActivateAudioInterfaceAsync.
  static ComPtr<IAudioClient> ActivateProcessLoopback(
      DWORD pid, bool include_mode);

  void CaptureThread();

  FrameCallback callback_;
  std::atomic<bool> running_{false};
  std::thread thread_;
  HANDLE stop_event_ = nullptr;
  DWORD target_pid_ = 0;
  bool include_mode_ = false;
  std::atomic<int> actual_sample_rate_{0};
};

#endif  // SCREEN_AUDIO_TEST_PROCESS_AUDIO_CAPTURER_H_
