#ifndef FLUTTER_WEBRTC_OPUS_DECODER_WRAPPER_H_
#define FLUTTER_WEBRTC_OPUS_DECODER_WRAPPER_H_

#include <opus.h>

#include <cstdint>
#include <vector>

namespace flutter_webrtc_plugin {

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

  // Packet loss concealment — generates interpolated audio for a lost packet.
  int DecodePLC(std::vector<int16_t>& output);

  int sample_rate() const { return sample_rate_; }
  int channels() const { return channels_; }
  int frame_size_10ms() const { return sample_rate_ / 100; }

 private:
  OpusDecoder* decoder_ = nullptr;
  int sample_rate_;
  int channels_;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_OPUS_DECODER_WRAPPER_H_
