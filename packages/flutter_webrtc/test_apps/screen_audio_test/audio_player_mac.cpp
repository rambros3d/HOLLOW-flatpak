#ifdef __APPLE__

#include "audio_player.h"

#include <AudioToolbox/AudioToolbox.h>
#include <cstdio>

static constexpr int kNumBuffers = 8;

struct MacState {
  AudioQueueRef queue = nullptr;
  AudioQueueBufferRef buffers[kNumBuffers] = {};
  AudioPlayer* player = nullptr;
};

static void AQOutputCallback(void* userData, AudioQueueRef, AudioQueueBufferRef buf) {
  auto* ms = static_cast<MacState*>(userData);
  if (!ms || !ms->player) {
    buf->mAudioDataByteSize = AudioPlayer::kBytesPerBuf;
    std::memset(buf->mAudioData, 0, buf->mAudioDataByteSize);
    AudioQueueEnqueueBuffer(ms->queue, buf, 0, nullptr);
    return;
  }

  auto* out = static_cast<int16_t*>(buf->mAudioData);
  size_t n = ms->player->FillBuffer(out, AudioPlayer::kSamplesPerBuf);
  if (n < AudioPlayer::kSamplesPerBuf)
    std::memset(out + n, 0, (AudioPlayer::kSamplesPerBuf - n) * sizeof(int16_t));
  buf->mAudioDataByteSize = AudioPlayer::kBytesPerBuf;

  AudioQueueEnqueueBuffer(ms->queue, buf, 0, nullptr);
}

AudioPlayer::AudioPlayer() = default;

AudioPlayer::~AudioPlayer() { Stop(); }

bool AudioPlayer::Start() {
  if (running_) return true;

  auto* ms = new MacState();
  ms->player = this;

  AudioStreamBasicDescription fmt = {};
  fmt.mSampleRate = kSampleRate;
  fmt.mFormatID = kAudioFormatLinearPCM;
  fmt.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
  fmt.mBitsPerChannel = 16;
  fmt.mChannelsPerFrame = kChannels;
  fmt.mBytesPerFrame = kChannels * sizeof(int16_t);
  fmt.mFramesPerPacket = 1;
  fmt.mBytesPerPacket = fmt.mBytesPerFrame;

  OSStatus err = AudioQueueNewOutput(&fmt, AQOutputCallback, ms,
                                      nullptr, nullptr, 0, &ms->queue);
  if (err != noErr) {
    fprintf(stderr, "[AUDIO-PLAYER] AudioQueueNewOutput failed: %d\n", (int)err);
    delete ms;
    return false;
  }

  for (int i = 0; i < kNumBuffers; ++i) {
    err = AudioQueueAllocateBuffer(ms->queue, kBytesPerBuf, &ms->buffers[i]);
    if (err != noErr) {
      fprintf(stderr, "[AUDIO-PLAYER] AudioQueueAllocateBuffer failed: %d\n", (int)err);
      AudioQueueDispose(ms->queue, true);
      delete ms;
      return false;
    }
    ms->buffers[i]->mAudioDataByteSize = kBytesPerBuf;
    std::memset(ms->buffers[i]->mAudioData, 0, kBytesPerBuf);
    AudioQueueEnqueueBuffer(ms->queue, ms->buffers[i], 0, nullptr);
  }

  err = AudioQueueStart(ms->queue, nullptr);
  if (err != noErr) {
    fprintf(stderr, "[AUDIO-PLAYER] AudioQueueStart failed: %d\n", (int)err);
    AudioQueueDispose(ms->queue, true);
    delete ms;
    return false;
  }

  running_ = true;
  platform_handle_ = ms;
  return true;
}

void AudioPlayer::Stop() {
  running_ = false;
  auto* ms = static_cast<MacState*>(platform_handle_);
  if (!ms) return;

  ms->player = nullptr;
  AudioQueueStop(ms->queue, true);
  AudioQueueDispose(ms->queue, true);

  delete ms;
  platform_handle_ = nullptr;
}

void AudioPlayer::Push(const int16_t* data, size_t frames, int channels) {
  const size_t total = frames * channels;
  std::lock_guard<std::mutex> lock(mu_);
  if (queue_.size() + total > static_cast<size_t>(kSampleRate * kChannels)) {
    size_t drop = queue_.size() + total - kSampleRate / 5 * kChannels;
    if (drop > queue_.size()) drop = queue_.size();
    drop -= drop % channels;
    for (size_t i = 0; i < drop; ++i) queue_.pop_front();
  }
  for (size_t i = 0; i < total; ++i) queue_.push_back(data[i]);
}

size_t AudioPlayer::FillBuffer(int16_t* out, size_t max_samples) {
  std::lock_guard<std::mutex> lock(mu_);
  size_t n = (queue_.size() >= max_samples) ? max_samples : queue_.size();
  for (size_t i = 0; i < n; ++i) {
    out[i] = queue_.front();
    queue_.pop_front();
  }
  return n;
}

#endif  // __APPLE__
