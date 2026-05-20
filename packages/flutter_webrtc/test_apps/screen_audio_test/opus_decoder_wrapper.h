#ifndef SCREEN_AUDIO_TEST_OPUS_DECODER_WRAPPER_H_
#define SCREEN_AUDIO_TEST_OPUS_DECODER_WRAPPER_H_

#include <opus.h>

#include <cstdint>
#include <vector>

class OpusDecoderWrapper {
 public:
  OpusDecoderWrapper(int sample_rate, int channels);
  ~OpusDecoderWrapper();

  OpusDecoderWrapper(const OpusDecoderWrapper&) = delete;
  OpusDecoderWrapper& operator=(const OpusDecoderWrapper&) = delete;

  bool valid() const { return decoder_ != nullptr; }

  // Decode one Opus packet. Returns decoded samples per channel,
  // or negative error code. Writes interleaved 16-bit PCM into output.
  int Decode(const uint8_t* data, int len, std::vector<int16_t>& output);

  int sample_rate() const { return sample_rate_; }
  int channels() const { return channels_; }

 private:
  OpusDecoder* decoder_ = nullptr;
  int sample_rate_;
  int channels_;
};

#endif  // SCREEN_AUDIO_TEST_OPUS_DECODER_WRAPPER_H_
