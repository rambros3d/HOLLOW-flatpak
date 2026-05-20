#include "wasapi_audio_renderer.h"

#include <cstring>

namespace flutter_webrtc_plugin {

WasapiAudioRenderer::WasapiAudioRenderer() = default;

WasapiAudioRenderer::~WasapiAudioRenderer() {
  Stop();
}

bool WasapiAudioRenderer::Start() {
  if (running_.load()) return true;

  WAVEFORMATEX wfx = {};
  wfx.wFormatTag = WAVE_FORMAT_PCM;
  wfx.nChannels = kChannels;
  wfx.nSamplesPerSec = kSampleRate;
  wfx.wBitsPerSample = 16;
  wfx.nBlockAlign = kChannels * sizeof(int16_t);
  wfx.nAvgBytesPerSec = kSampleRate * wfx.nBlockAlign;
  wfx.cbSize = 0;

  MMRESULT mr = waveOutOpen(&hwo_, WAVE_MAPPER, &wfx,
                             reinterpret_cast<DWORD_PTR>(WaveOutCallback),
                             reinterpret_cast<DWORD_PTR>(this),
                             CALLBACK_FUNCTION);
  if (mr != MMSYSERR_NOERROR) return false;

  running_.store(true);

  // Prepare all headers and submit them pre-filled with silence.
  for (int i = 0; i < kNumBuffers; ++i) {
    std::memset(buffers_[i], 0, kBytesPerBuffer);
    headers_[i].lpData = reinterpret_cast<LPSTR>(buffers_[i]);
    headers_[i].dwBufferLength = kBytesPerBuffer;
    headers_[i].dwFlags = 0;
    waveOutPrepareHeader(hwo_, &headers_[i], sizeof(WAVEHDR));
    waveOutWrite(hwo_, &headers_[i], sizeof(WAVEHDR));
  }

  return true;
}

void WasapiAudioRenderer::Stop() {
  if (!running_.exchange(false)) return;

  if (hwo_) {
    waveOutReset(hwo_);
    for (int i = 0; i < kNumBuffers; ++i) {
      waveOutUnprepareHeader(hwo_, &headers_[i], sizeof(WAVEHDR));
    }
    waveOutClose(hwo_);
    hwo_ = nullptr;
  }

  std::lock_guard<std::mutex> lock(queue_mutex_);
  queue_.clear();
}

void WasapiAudioRenderer::PushAudio(const int16_t* data, size_t frames,
                                     int channels) {
  const size_t total = frames * channels;
  std::lock_guard<std::mutex> lock(queue_mutex_);

  // Drop oldest if queue is too large (latency protection).
  if (queue_.size() + total > kMaxQueueSamples) {
    size_t to_drop = queue_.size() + total - kDropThreshold;
    if (to_drop > queue_.size()) to_drop = queue_.size();
    to_drop -= to_drop % channels;
    for (size_t i = 0; i < to_drop; ++i) queue_.pop_front();
  }

  for (size_t i = 0; i < total; ++i) {
    queue_.push_back(data[i]);
  }
}

void CALLBACK WasapiAudioRenderer::WaveOutCallback(
    HWAVEOUT, UINT uMsg, DWORD_PTR dwInstance, DWORD_PTR dwParam1,
    DWORD_PTR) {
  if (uMsg != WOM_DONE) return;

  auto* self = reinterpret_cast<WasapiAudioRenderer*>(dwInstance);
  auto* hdr = reinterpret_cast<WAVEHDR*>(dwParam1);
  self->OnBufferDone(hdr);
}

void WasapiAudioRenderer::OnBufferDone(WAVEHDR* hdr) {
  if (!running_.load()) return;

  // Fill this buffer with queued PCM data (or silence if queue empty).
  auto* out = reinterpret_cast<int16_t*>(hdr->lpData);

  {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    size_t available = queue_.size();
    size_t to_copy = (available >= kSamplesPerBuffer)
                         ? kSamplesPerBuffer
                         : available;

    for (size_t i = 0; i < to_copy; ++i) {
      out[i] = queue_.front();
      queue_.pop_front();
    }
    // Zero-fill remainder.
    if (to_copy < kSamplesPerBuffer) {
      std::memset(out + to_copy, 0,
                  (kSamplesPerBuffer - to_copy) * sizeof(int16_t));
    }
  }

  // Resubmit the buffer for playback.
  waveOutWrite(hwo_, hdr, sizeof(WAVEHDR));
}

}  // namespace flutter_webrtc_plugin
