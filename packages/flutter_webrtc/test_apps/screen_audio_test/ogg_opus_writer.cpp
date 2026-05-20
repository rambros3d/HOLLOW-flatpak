#include "ogg_opus_writer.h"

#include <cstring>
#include <vector>

namespace {

void WriteLE16(uint8_t* p, uint16_t v) {
  p[0] = static_cast<uint8_t>(v);
  p[1] = static_cast<uint8_t>(v >> 8);
}

void WriteLE32(uint8_t* p, uint32_t v) {
  p[0] = static_cast<uint8_t>(v);
  p[1] = static_cast<uint8_t>(v >> 8);
  p[2] = static_cast<uint8_t>(v >> 16);
  p[3] = static_cast<uint8_t>(v >> 24);
}

}  // namespace

OggOpusWriter::OggOpusWriter(const char* filename, int sample_rate,
                             int channels, int pre_skip)
    : sample_rate_(sample_rate),
      channels_(channels),
      pre_skip_(pre_skip) {
  file_ = fopen(filename, "wb");
  if (!file_) {
    fprintf(stderr, "[OGG] Failed to open %s for writing\n", filename);
    return;
  }

  ogg_stream_init(&os_, 1);  // serial number = 1

  WriteOpusHead();
  WriteOpusTags();
}

OggOpusWriter::~OggOpusWriter() {
  if (!finalized_) Finalize();
}

// RFC 7845 Section 5.1 — OpusHead
void OggOpusWriter::WriteOpusHead() {
  uint8_t head[19] = {};
  memcpy(head, "OpusHead", 8);
  head[8] = 1;                                          // version
  head[9] = static_cast<uint8_t>(channels_);            // channel count
  WriteLE16(head + 10, static_cast<uint16_t>(pre_skip_));
  WriteLE32(head + 12, static_cast<uint32_t>(sample_rate_));
  WriteLE16(head + 16, 0);                              // output gain
  head[18] = 0;                                         // channel mapping family

  ogg_packet op = {};
  op.packet = head;
  op.bytes = 19;
  op.b_o_s = 1;
  op.e_o_s = 0;
  op.granulepos = 0;
  op.packetno = packet_no_++;

  ogg_stream_packetin(&os_, &op);

  // BOS page must be flushed immediately.
  ogg_page page;
  while (ogg_stream_flush(&os_, &page)) {
    WritePage(&page);
  }
}

// RFC 7845 Section 5.2 — OpusTags
void OggOpusWriter::WriteOpusTags() {
  const char* vendor = "screen_audio_test";
  uint32_t vendor_len = static_cast<uint32_t>(strlen(vendor));

  // OpusTags = "OpusTags" + vendor_string_length(LE32) + vendor_string +
  //            comment_count(LE32) + [comments...]
  size_t tags_size = 8 + 4 + vendor_len + 4;
  std::vector<uint8_t> tags(tags_size);

  memcpy(tags.data(), "OpusTags", 8);
  WriteLE32(tags.data() + 8, vendor_len);
  memcpy(tags.data() + 12, vendor, vendor_len);
  WriteLE32(tags.data() + 12 + vendor_len, 0);  // zero comments

  ogg_packet op = {};
  op.packet = tags.data();
  op.bytes = static_cast<long>(tags_size);
  op.b_o_s = 0;
  op.e_o_s = 0;
  op.granulepos = 0;
  op.packetno = packet_no_++;

  ogg_stream_packetin(&os_, &op);

  ogg_page page;
  while (ogg_stream_flush(&os_, &page)) {
    WritePage(&page);
  }
}

bool OggOpusWriter::WritePacket(const uint8_t* data, int size,
                                int frame_samples) {
  if (!file_ || finalized_) return false;

  granule_pos_ += frame_samples;

  ogg_packet op = {};
  op.packet = const_cast<uint8_t*>(data);
  op.bytes = size;
  op.b_o_s = 0;
  op.e_o_s = 0;
  op.granulepos = granule_pos_ + pre_skip_;
  op.packetno = packet_no_++;

  ogg_stream_packetin(&os_, &op);
  FlushPages();
  return true;
}

void OggOpusWriter::Finalize() {
  if (!file_ || finalized_) return;
  finalized_ = true;

  // Write an empty EOS packet to signal end-of-stream.
  ogg_packet op = {};
  op.packet = nullptr;
  op.bytes = 0;
  op.b_o_s = 0;
  op.e_o_s = 1;
  op.granulepos = granule_pos_ + pre_skip_;
  op.packetno = packet_no_++;

  ogg_stream_packetin(&os_, &op);

  ogg_page page;
  while (ogg_stream_flush(&os_, &page)) {
    WritePage(&page);
  }

  ogg_stream_clear(&os_);
  fclose(file_);
  file_ = nullptr;
}

void OggOpusWriter::FlushPages() {
  ogg_page page;
  while (ogg_stream_pageout(&os_, &page)) {
    WritePage(&page);
  }
}

void OggOpusWriter::WritePage(ogg_page* page) {
  fwrite(page->header, 1, page->header_len, file_);
  fwrite(page->body, 1, page->body_len, file_);
}
