#include "screen_audio_capturer.h"

#include <opus.h>

#include <cstdio>
#include <cstring>

#include "opus_decoder_wrapper.h"

namespace flutter_webrtc_plugin {

ScreenAudioCapturer::ScreenAudioCapturer(BinaryMessenger* messenger,
                                         TaskRunner* task_runner,
                                         const std::string& stream_id)
    : stream_id_(stream_id) {
  std::string channel_name = "FlutterWebRTC/screenAudio" + stream_id;
  event_channel_ = EventChannelProxy::Create(messenger, task_runner,
                                             channel_name);
  queue_event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
}

ScreenAudioCapturer::~ScreenAudioCapturer() {
  Stop();
  if (queue_event_) {
    CloseHandle(queue_event_);
    queue_event_ = nullptr;
  }
}

bool ScreenAudioCapturer::StartSystemCapture() {
  if (active_.load()) return true;

  encoder_ = std::make_unique<OpusEncoderWrapper>(
      48000, 2, OPUS_APPLICATION_AUDIO);
  if (!encoder_->valid()) return false;

  encode_buffer_.resize(4000);
  sequence_number_ = 0;

  active_.store(true);

  // Start drain thread BEFORE capture so it's ready to consume.
  drain_thread_ = std::thread(&ScreenAudioCapturer::DrainThread, this);

  auto callback = [this](const void* data, int bits_per_sample,
                         int sample_rate, size_t channels, size_t frames) {
    OnAudioFrame(data, bits_per_sample, sample_rate, channels, frames);
  };

  loopback_capturer_ = std::make_unique<WasapiLoopbackCapturer>();
  if (!loopback_capturer_->Start(callback)) {
    active_.store(false);
    SetEvent(queue_event_);
    if (drain_thread_.joinable()) drain_thread_.join();
    loopback_capturer_.reset();
    encoder_.reset();
    return false;
  }

  return true;
}

bool ScreenAudioCapturer::StartProcessCapture(DWORD target_pid,
                                               bool include_mode) {
  if (active_.load()) return true;

  if (!ProcessAudioCapturer::IsSupported()) return false;

  encoder_ = std::make_unique<OpusEncoderWrapper>(
      48000, 2, OPUS_APPLICATION_AUDIO);
  if (!encoder_->valid()) return false;

  encode_buffer_.resize(4000);
  sequence_number_ = 0;

  active_.store(true);

  drain_thread_ = std::thread(&ScreenAudioCapturer::DrainThread, this);

  auto callback = [this](const void* data, int bits_per_sample,
                         int sample_rate, size_t channels, size_t frames) {
    OnAudioFrame(data, bits_per_sample, sample_rate, channels, frames);
  };

  process_capturer_ = std::make_unique<ProcessAudioCapturer>();
  if (!process_capturer_->Start(callback, target_pid, include_mode)) {
    active_.store(false);
    SetEvent(queue_event_);
    if (drain_thread_.joinable()) drain_thread_.join();
    process_capturer_.reset();
    encoder_.reset();
    return false;
  }

  return true;
}

void ScreenAudioCapturer::Stop() {
  if (!active_.exchange(false)) return;

  if (loopback_capturer_) {
    loopback_capturer_->Stop();
    loopback_capturer_.reset();
  }
  if (process_capturer_) {
    process_capturer_->Stop();
    process_capturer_.reset();
  }

  // Wake drain thread so it exits.
  if (queue_event_) SetEvent(queue_event_);
  if (drain_thread_.joinable()) drain_thread_.join();

  encoder_.reset();

  std::lock_guard<std::mutex> lock(queue_mutex_);
  packet_queue_.clear();
}

// Called on the WASAPI capture thread — must be FAST.
// Only encode + push to queue, never touch EventChannel here.
void ScreenAudioCapturer::OnAudioFrame(const void* data, int bits_per_sample,
                                        int sample_rate, size_t channels,
                                        size_t frames) {
  if (!active_.load() || !encoder_) return;

  auto* pcm = static_cast<const int16_t*>(data);

  // --- DEBUG: write raw + roundtrip WAV on sender ---
  static FILE* dbg_raw = nullptr;
  static FILE* dbg_dec = nullptr;
  static uint32_t dbg_raw_bytes = 0;
  static uint32_t dbg_dec_bytes = 0;
  static std::unique_ptr<OpusDecoderWrapper> dbg_decoder;
  static int dbg_count = 0;
  static std::vector<int16_t> dbg_pcm_out;

  if (dbg_count == 0) {
    char* appdata = nullptr;
    size_t alen = 0;
    if (_dupenv_s(&appdata, &alen, "APPDATA") == 0 && appdata) {
      std::string dir = std::string(appdata) + "\\.hollow";
      free(appdata);
      CreateDirectoryA(dir.c_str(), nullptr);

      auto writeWavHdr = [](FILE* f) {
        uint8_t hdr[44] = {};
        memcpy(hdr, "RIFF", 4);
        memcpy(hdr + 8, "WAVE", 4);
        memcpy(hdr + 12, "fmt ", 4);
        uint32_t v = 16; memcpy(hdr + 16, &v, 4);
        uint16_t s = 1; memcpy(hdr + 20, &s, 2);
        s = 2; memcpy(hdr + 22, &s, 2);
        v = 48000; memcpy(hdr + 24, &v, 4);
        v = 48000 * 4; memcpy(hdr + 28, &v, 4);
        s = 4; memcpy(hdr + 32, &s, 2);
        s = 16; memcpy(hdr + 34, &s, 2);
        memcpy(hdr + 36, "data", 4);
        fwrite(hdr, 1, 44, f);
      };

      fopen_s(&dbg_raw, (dir + "\\debug_sender_raw.wav").c_str(), "wb");
      fopen_s(&dbg_dec, (dir + "\\debug_sender_roundtrip.wav").c_str(), "wb");
      if (dbg_raw) writeWavHdr(dbg_raw);
      if (dbg_dec) writeWavHdr(dbg_dec);
      dbg_decoder = std::make_unique<OpusDecoderWrapper>(48000, 2);
    }
  }
  dbg_count++;
  // --- END DEBUG INIT ---

  int encoded = encoder_->Encode(pcm, static_cast<int>(frames),
                                 encode_buffer_);
  if (encoded <= 0) return;

  // --- DEBUG: write files (first 1000 packets = ~10 sec) ---
  if (dbg_count <= 1000) {
    if (dbg_raw) {
      size_t bytes = frames * channels * sizeof(int16_t);
      fwrite(pcm, 1, bytes, dbg_raw);
      dbg_raw_bytes += static_cast<uint32_t>(bytes);
    }
    if (dbg_dec && dbg_decoder) {
      int dec = dbg_decoder->Decode(encode_buffer_.data(), encoded, dbg_pcm_out);
      if (dec > 0) {
        size_t bytes = dec * channels * sizeof(int16_t);
        fwrite(dbg_pcm_out.data(), 1, bytes, dbg_dec);
        dbg_dec_bytes += static_cast<uint32_t>(bytes);
      }
    }
  }
  if (dbg_count == 1000) {
    auto patchWav = [](FILE*& f, uint32_t data_bytes) {
      if (!f) return;
      fseek(f, 4, SEEK_SET);
      uint32_t riff = data_bytes + 36;
      fwrite(&riff, 4, 1, f);
      fseek(f, 40, SEEK_SET);
      fwrite(&data_bytes, 4, 1, f);
      fclose(f);
      f = nullptr;
    };
    patchWav(dbg_raw, dbg_raw_bytes);
    patchWav(dbg_dec, dbg_dec_bytes);
    dbg_decoder.reset();
  }
  // --- END DEBUG ---

  // Build packet: [uint32_le: seq][...opus_bytes...]
  uint32_t seq = sequence_number_++;
  std::vector<uint8_t> packet(4 + encoded);
  packet[0] = static_cast<uint8_t>(seq);
  packet[1] = static_cast<uint8_t>(seq >> 8);
  packet[2] = static_cast<uint8_t>(seq >> 16);
  packet[3] = static_cast<uint8_t>(seq >> 24);
  std::memcpy(packet.data() + 4, encode_buffer_.data(), encoded);

  {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    if (packet_queue_.size() < 50) {
      packet_queue_.push_back(std::move(packet));
    }
  }

  SetEvent(queue_event_);
}

// Runs on its own thread — drains the queue and emits via EventChannel.
void ScreenAudioCapturer::DrainThread() {
  while (active_.load()) {
    WaitForSingleObject(queue_event_, 100);
    if (!active_.load()) break;

    // Drain all available packets.
    std::deque<std::vector<uint8_t>> batch;
    {
      std::lock_guard<std::mutex> lock(queue_mutex_);
      batch.swap(packet_queue_);
    }

    for (auto& pkt : batch) {
      if (!active_.load()) break;

      EncodableMap event;
      event[EncodableValue("event")] = EncodableValue("screenAudioPacket");
      event[EncodableValue("data")] = EncodableValue(std::move(pkt));

      if (event_channel_) {
        event_channel_->Success(EncodableValue(event), false);
      }
    }
  }
}

}  // namespace flutter_webrtc_plugin
