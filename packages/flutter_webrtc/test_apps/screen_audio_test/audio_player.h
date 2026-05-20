#ifndef SCREEN_AUDIO_TEST_AUDIO_PLAYER_H_
#define SCREEN_AUDIO_TEST_AUDIO_PLAYER_H_

#include <cstdint>
#include <cstring>
#include <deque>
#include <mutex>

// Cross-platform PCM audio player.
// Windows: waveOut, macOS: AudioQueue, Linux: PulseAudio simple API.

class AudioPlayer {
 public:
  static constexpr int kSampleRate = 48000;
  static constexpr int kChannels = 2;
  static constexpr int kFramesPerBuf = kSampleRate / 100;  // 480 = 10ms
  static constexpr int kSamplesPerBuf = kFramesPerBuf * kChannels;
  static constexpr int kBytesPerBuf = kSamplesPerBuf * sizeof(int16_t);

  AudioPlayer();
  ~AudioPlayer();

  AudioPlayer(const AudioPlayer&) = delete;
  AudioPlayer& operator=(const AudioPlayer&) = delete;

  bool Start();
  void Stop();

  void Push(const int16_t* data, size_t frames, int channels);

  // Called by platform callback to fill a buffer.
  size_t FillBuffer(int16_t* out, size_t max_samples);

  bool running_ = false;
  std::mutex mu_;
  std::deque<int16_t> queue_;

  // Platform-specific handle storage.
  void* platform_handle_ = nullptr;
};

#endif  // SCREEN_AUDIO_TEST_AUDIO_PLAYER_H_
