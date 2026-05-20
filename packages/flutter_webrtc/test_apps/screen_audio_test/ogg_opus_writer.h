#ifndef SCREEN_AUDIO_TEST_OGG_OPUS_WRITER_H_
#define SCREEN_AUDIO_TEST_OGG_OPUS_WRITER_H_

#include <ogg/ogg.h>

#include <cstdint>
#include <cstdio>

// Writes an OGG/Opus file per RFC 7845.
// Handles OpusHead, OpusTags, and audio packet pages.
class OggOpusWriter {
 public:
  // pre_skip: encoder lookahead in samples (from OpusEncoderWrapper::lookahead())
  OggOpusWriter(const char* filename, int sample_rate, int channels,
                int pre_skip);
  ~OggOpusWriter();

  OggOpusWriter(const OggOpusWriter&) = delete;
  OggOpusWriter& operator=(const OggOpusWriter&) = delete;

  bool valid() const { return file_ != nullptr; }

  // Write one encoded Opus packet.
  // frame_samples: PCM samples per channel this packet represents (e.g. 480).
  bool WritePacket(const uint8_t* data, int size, int frame_samples);

  // Write final EOS page and close.
  void Finalize();

 private:
  void WriteOpusHead();
  void WriteOpusTags();
  void FlushPages();
  void WritePage(ogg_page* page);

  FILE* file_ = nullptr;
  ogg_stream_state os_;
  int64_t granule_pos_ = 0;
  int packet_no_ = 0;
  int sample_rate_;
  int channels_;
  int pre_skip_;
  bool finalized_ = false;
};

#endif  // SCREEN_AUDIO_TEST_OGG_OPUS_WRITER_H_
