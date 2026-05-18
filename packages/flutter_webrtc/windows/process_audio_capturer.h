#ifndef FLUTTER_WEBRTC_PROCESS_AUDIO_CAPTURER_H_
#define FLUTTER_WEBRTC_PROCESS_AUDIO_CAPTURER_H_

#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <ksmedia.h>
#include <wrl/client.h>
#include <wrl/implements.h>

#include <atomic>
#include <functional>
#include <thread>

namespace flutter_webrtc_plugin {

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

  bool Start(FrameCallback cb);
  void Stop();

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

  void CaptureThread();

  FrameCallback callback_;
  std::atomic<bool> running_{false};
  std::thread thread_;
  HANDLE stop_event_ = nullptr;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_PROCESS_AUDIO_CAPTURER_H_
