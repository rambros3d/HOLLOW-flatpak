#ifndef FLUTTER_WEBRTC_SCREEN_AUDIO_CAPTURER_H_
#define FLUTTER_WEBRTC_SCREEN_AUDIO_CAPTURER_H_

#include <windows.h>

#include <atomic>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "flutter_common.h"
#include "opus_encoder_wrapper.h"
#include "process_audio_capturer.h"
#include "wasapi_loopback_capturer.h"

namespace flutter_webrtc_plugin {

// Orchestrates: WASAPI capture → Opus encode → queue → EventChannel emission.
// The capture callback only encodes + pushes to a lock-free-ish queue.
// A separate drain thread pops packets and emits via EventChannel,
// keeping the WASAPI capture thread fast and never blocking.
class ScreenAudioCapturer {
 public:
  ScreenAudioCapturer(BinaryMessenger* messenger,
                      TaskRunner* task_runner,
                      const std::string& stream_id);
  ~ScreenAudioCapturer();

  ScreenAudioCapturer(const ScreenAudioCapturer&) = delete;
  ScreenAudioCapturer& operator=(const ScreenAudioCapturer&) = delete;

  bool StartSystemCapture();
  bool StartProcessCapture(DWORD target_pid, bool include_mode);
  void Stop();
  bool IsActive() const { return active_.load(); }

 private:
  void OnAudioFrame(const void* data, int bits_per_sample,
                    int sample_rate, size_t channels, size_t frames);
  void DrainThread();

  std::string stream_id_;
  std::unique_ptr<EventChannelProxy> event_channel_;
  std::unique_ptr<WasapiLoopbackCapturer> loopback_capturer_;
  std::unique_ptr<ProcessAudioCapturer> process_capturer_;
  std::unique_ptr<OpusEncoderWrapper> encoder_;
  std::vector<uint8_t> encode_buffer_;
  uint32_t sequence_number_ = 0;
  std::atomic<bool> active_{false};

  // Queue: capture thread pushes, drain thread pops.
  std::mutex queue_mutex_;
  std::deque<std::vector<uint8_t>> packet_queue_;
  HANDLE queue_event_ = nullptr;  // signaled when packets are available
  std::thread drain_thread_;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_SCREEN_AUDIO_CAPTURER_H_
