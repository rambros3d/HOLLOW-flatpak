#ifndef SCREEN_AUDIO_TEST_WAV_WRITER_H_
#define SCREEN_AUDIO_TEST_WAV_WRITER_H_

#include <cstdint>
#include <cstdio>
#include <cstring>

class WavWriter {
 public:
  ~WavWriter() { Close(); }

  bool Open(const char* filename, int sample_rate, int channels,
            int bits_per_sample) {
    file_ = fopen(filename, "wb");
    if (!file_) return false;

    sample_rate_ = sample_rate;
    channels_ = channels;
    bits_per_sample_ = bits_per_sample;
    block_align_ = channels * bits_per_sample / 8;
    data_bytes_ = 0;

    uint8_t header[44] = {};
    memcpy(header, "RIFF", 4);
    memcpy(header + 8, "WAVE", 4);
    memcpy(header + 12, "fmt ", 4);
    WriteLE32(header + 16, 16);  // fmt chunk size
    WriteLE16(header + 20, 1);   // PCM format
    WriteLE16(header + 22, static_cast<uint16_t>(channels));
    WriteLE32(header + 24, static_cast<uint32_t>(sample_rate));
    WriteLE32(header + 28,
              static_cast<uint32_t>(sample_rate * block_align_));
    WriteLE16(header + 32, static_cast<uint16_t>(block_align_));
    WriteLE16(header + 34, static_cast<uint16_t>(bits_per_sample));
    memcpy(header + 36, "data", 4);
    // data chunk size placeholder at offset 40 — patched in Close()

    fwrite(header, 1, 44, file_);
    return true;
  }

  void WriteSamples(const int16_t* data, size_t sample_count) {
    if (!file_) return;
    size_t bytes = sample_count * sizeof(int16_t);
    fwrite(data, 1, bytes, file_);
    data_bytes_ += static_cast<uint32_t>(bytes);
  }

  void Close() {
    if (!file_) return;

    // Patch RIFF chunk size (offset 4) and data chunk size (offset 40).
    uint8_t buf[4];

    fseek(file_, 4, SEEK_SET);
    WriteLE32(buf, data_bytes_ + 36);
    fwrite(buf, 1, 4, file_);

    fseek(file_, 40, SEEK_SET);
    WriteLE32(buf, data_bytes_);
    fwrite(buf, 1, 4, file_);

    fclose(file_);
    file_ = nullptr;
  }

 private:
  static void WriteLE16(uint8_t* p, uint16_t v) {
    p[0] = static_cast<uint8_t>(v);
    p[1] = static_cast<uint8_t>(v >> 8);
  }

  static void WriteLE32(uint8_t* p, uint32_t v) {
    p[0] = static_cast<uint8_t>(v);
    p[1] = static_cast<uint8_t>(v >> 8);
    p[2] = static_cast<uint8_t>(v >> 16);
    p[3] = static_cast<uint8_t>(v >> 24);
  }

  FILE* file_ = nullptr;
  int sample_rate_ = 0;
  int channels_ = 0;
  int bits_per_sample_ = 0;
  int block_align_ = 0;
  uint32_t data_bytes_ = 0;
};

#endif  // SCREEN_AUDIO_TEST_WAV_WRITER_H_
