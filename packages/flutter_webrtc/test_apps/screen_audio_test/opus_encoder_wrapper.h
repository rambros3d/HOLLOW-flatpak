#ifndef SCREEN_AUDIO_TEST_OPUS_ENCODER_WRAPPER_H_
#define SCREEN_AUDIO_TEST_OPUS_ENCODER_WRAPPER_H_

#include <opus.h>

#include <cstdint>
#include <vector>

class OpusEncoderWrapper {
 public:
  // sample_rate: 8000/12000/16000/24000/48000
  // channels: 1 or 2
  // application: OPUS_APPLICATION_AUDIO or OPUS_APPLICATION_VOIP
  OpusEncoderWrapper(int sample_rate, int channels, int application);
  ~OpusEncoderWrapper();

  OpusEncoderWrapper(const OpusEncoderWrapper&) = delete;
  OpusEncoderWrapper& operator=(const OpusEncoderWrapper&) = delete;

  bool valid() const { return encoder_ != nullptr; }

  // Encode one frame of interleaved 16-bit PCM.
  // frame_size: samples per channel (e.g. 480 for 10ms at 48kHz).
  // Returns encoded byte count (written into output), or negative error code.
  int Encode(const int16_t* pcm, int frame_size,
             std::vector<uint8_t>& output);

  void SetBitrate(int bitrate);
  void SetComplexity(int complexity);

  int sample_rate() const { return sample_rate_; }
  int channels() const { return channels_; }
  int frame_size_10ms() const { return sample_rate_ / 100; }
  int lookahead() const { return lookahead_; }

 private:
  OpusEncoder* encoder_ = nullptr;
  int sample_rate_;
  int channels_;
  int lookahead_ = 0;
};

#endif  // SCREEN_AUDIO_TEST_OPUS_ENCODER_WRAPPER_H_
