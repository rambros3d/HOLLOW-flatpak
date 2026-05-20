#include "opus_encoder_wrapper.h"

#include <cstdio>

OpusEncoderWrapper::OpusEncoderWrapper(int sample_rate, int channels,
                                       int application)
    : sample_rate_(sample_rate), channels_(channels) {
  int error = 0;
  encoder_ = opus_encoder_create(sample_rate, channels, application, &error);
  if (error != OPUS_OK || !encoder_) {
    fprintf(stderr, "[OPUS] encoder create failed: %s\n",
            opus_strerror(error));
    encoder_ = nullptr;
    return;
  }

  SetBitrate(128000);
  SetComplexity(10);

  opus_encoder_ctl(encoder_, OPUS_GET_LOOKAHEAD(&lookahead_));
  fprintf(stderr, "[OPUS] Encoder ready: %dHz %dch, lookahead=%d samples\n",
          sample_rate, channels, lookahead_);
}

OpusEncoderWrapper::~OpusEncoderWrapper() {
  if (encoder_) {
    opus_encoder_destroy(encoder_);
    encoder_ = nullptr;
  }
}

int OpusEncoderWrapper::Encode(const int16_t* pcm, int frame_size,
                                std::vector<uint8_t>& output) {
  if (!encoder_) return -1;
  if (output.size() < 4000) output.resize(4000);

  int bytes = opus_encode(encoder_, pcm, frame_size, output.data(),
                          static_cast<opus_int32>(output.size()));
  if (bytes < 0) {
    fprintf(stderr, "[OPUS] encode error: %s\n", opus_strerror(bytes));
  }
  return bytes;
}

void OpusEncoderWrapper::SetBitrate(int bitrate) {
  if (encoder_)
    opus_encoder_ctl(encoder_, OPUS_SET_BITRATE(bitrate));
}

void OpusEncoderWrapper::SetComplexity(int complexity) {
  if (encoder_)
    opus_encoder_ctl(encoder_, OPUS_SET_COMPLEXITY(complexity));
}
