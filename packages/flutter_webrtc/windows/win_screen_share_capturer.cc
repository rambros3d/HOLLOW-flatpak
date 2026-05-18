#include "win_screen_share_capturer.h"
#include "win_screen_recorder.h"
#include "capture_log.h"

namespace flutter_webrtc_plugin {

WinScreenShareCapturer::WinScreenShareCapturer() = default;

WinScreenShareCapturer::~WinScreenShareCapturer() {
  Stop();
}

bool WinScreenShareCapturer::Start(
    HMONITOR monitor, uint32_t fps,
    libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> video_source) {
  if (!video_source.get()) return false;
  video_source_ = video_source;

  auto& recorder = WinScreenRecorder::GetInstance();
  bool ok = recorder.StartCapture(
      monitor, fps,
      [this](const WinScreenRecorder::BGRAFrame& bgra) {
        OnFrame(bgra);
      });

  if (!ok) {
    CAPLOG("WinScreenShareCapturer::Start failed");
    video_source_ = nullptr;
    return false;
  }
  CAPLOG("WinScreenShareCapturer::Start OK");
  return true;
}

void WinScreenShareCapturer::Stop() {
  WinScreenRecorder::GetInstance().StopCapture();
  video_source_ = nullptr;
}

bool WinScreenShareCapturer::IsCapturing() const {
  return WinScreenRecorder::GetInstance().IsCapturing();
}

void WinScreenShareCapturer::OnFrame(
    const WinScreenRecorder::BGRAFrame& bgra) {
  if (!video_source_.get()) return;
  if (bgra.width <= 0 || bgra.height <= 0) return;

  // BGRA → I420 via libyuv (AVX2/SSSE3 accelerated, color-accurate).
  auto frame = libwebrtc::RTCVideoFrame::CreateFromBGRA(
      bgra.width, bgra.height, bgra.data, bgra.stride);

  if (frame.get()) {
    static bool first = true;
    if (first) {
      CAPLOG("OnFrame: first BGRA frame → OnCapturedFrame %dx%d", bgra.width, bgra.height);
      first = false;
    }
    video_source_->OnCapturedFrame(frame);
  } else {
    static bool logged = false;
    if (!logged) {
      CAPLOG("OnFrame: CreateFromBGRA returned null!");
      logged = true;
    }
  }
}

}  // namespace flutter_webrtc_plugin
