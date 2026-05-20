#ifndef FLUTTER_WEBRTC_WASAPI_AUDIO_RENDERER_H_
#define FLUTTER_WEBRTC_WASAPI_AUDIO_RENDERER_H_

#include <windows.h>
#include <mmsystem.h>

#include <atomic>
#include <cstdint>
#include <deque>
#include <mutex>

#pragma comment(lib, "winmm.lib")

namespace flutter_webrtc_plugin {

// Plays PCM audio using the waveOut API (simple buffer-queue model).
// Thread-safe: PushAudio can be called from any thread.
// Uses a ring of small buffers submitted to waveOut — each buffer plays
// once in order and is recycled via the completion callback. No WASAPI.
class WasapiAudioRenderer {
 public:
  WasapiAudioRenderer();
  ~WasapiAudioRenderer();

  WasapiAudioRenderer(const WasapiAudioRenderer&) = delete;
  WasapiAudioRenderer& operator=(const WasapiAudioRenderer&) = delete;

  bool Start();
  void Stop();
  bool IsRunning() const { return running_.load(); }

  // Push decoded PCM samples (interleaved int16, stereo).
  // frames = samples per channel.
  void PushAudio(const int16_t* data, size_t frames, int channels);

 private:
  static void CALLBACK WaveOutCallback(HWAVEOUT hwo, UINT uMsg,
                                       DWORD_PTR dwInstance,
                                       DWORD_PTR dwParam1,
                                       DWORD_PTR dwParam2);
  void OnBufferDone(WAVEHDR* hdr);
  void SubmitBuffer();

  // 8 buffers of 10ms each = 80ms ring. Enough to absorb jitter.
  static constexpr int kNumBuffers = 8;
  static constexpr int kSampleRate = 48000;
  static constexpr int kChannels = 2;
  static constexpr int kFramesPerBuffer = kSampleRate / 100;  // 480 (10ms)
  static constexpr int kSamplesPerBuffer = kFramesPerBuffer * kChannels;
  static constexpr int kBytesPerBuffer = kSamplesPerBuffer * sizeof(int16_t);

  std::atomic<bool> running_{false};
  HWAVEOUT hwo_ = nullptr;

  WAVEHDR headers_[kNumBuffers] = {};
  int16_t buffers_[kNumBuffers][kSamplesPerBuffer] = {};

  std::mutex queue_mutex_;
  std::deque<int16_t> queue_;

  static constexpr size_t kMaxQueueSamples = kSampleRate * kChannels;  // 500ms
  static constexpr size_t kDropThreshold = kSampleRate / 5 * kChannels;  // 100ms
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_WASAPI_AUDIO_RENDERER_H_
