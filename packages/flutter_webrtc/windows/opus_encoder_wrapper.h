#ifndef FLUTTER_WEBRTC_OPUS_ENCODER_WRAPPER_H_
#define FLUTTER_WEBRTC_OPUS_ENCODER_WRAPPER_H_

#include <opus.h>

#include <cstdint>
#include <vector>

namespace flutter_webrtc_plugin {

class OpusEncoderWrapper {
 public:
  OpusEncoderWrapper(int sample_rate, int channels, int application);
  ~OpusEncoderWrapper();

  OpusEncoderWrapper(const OpusEncoderWrapper&) = delete;
  OpusEncoderWrapper& operator=(const OpusEncoderWrapper&) = delete;

  bool valid() const { return encoder_ != nullptr; }

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

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_OPUS_ENCODER_WRAPPER_H_
