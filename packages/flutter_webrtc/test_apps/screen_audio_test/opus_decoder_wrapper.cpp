#include "opus_decoder_wrapper.h"

#include <cstdio>

OpusDecoderWrapper::OpusDecoderWrapper(int sample_rate, int channels)
    : sample_rate_(sample_rate), channels_(channels) {
  int error = 0;
  decoder_ = opus_decoder_create(sample_rate, channels, &error);
  if (error != OPUS_OK || !decoder_) {
    fprintf(stderr, "[OPUS-DEC] create failed: %s\n", opus_strerror(error));
    decoder_ = nullptr;
  }
}

OpusDecoderWrapper::~OpusDecoderWrapper() {
  if (decoder_) {
    opus_decoder_destroy(decoder_);
    decoder_ = nullptr;
  }
}

int OpusDecoderWrapper::Decode(const uint8_t* data, int len,
                                std::vector<int16_t>& output) {
  if (!decoder_) return -1;

  const int max_frame = 5760;  // 120ms at 48kHz
  if (output.size() < static_cast<size_t>(max_frame * channels_))
    output.resize(max_frame * channels_);

  int samples = opus_decode(decoder_, data, len, output.data(), max_frame, 0);
  if (samples < 0) {
    fprintf(stderr, "[OPUS-DEC] decode error: %s\n", opus_strerror(samples));
  }
  return samples;
}
