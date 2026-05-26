#ifndef FLUTTER_WEBRTC_NATIVE_SCREEN_CAPTURER_H_
#define FLUTTER_WEBRTC_NATIVE_SCREEN_CAPTURER_H_

#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <wrl/client.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>

#include <atomic>
#include <mutex>
#include <vector>

#include "rtc_video_frame.h"
#include "rtc_video_source.h"

namespace flutter_webrtc_plugin {

using Microsoft::WRL::ComPtr;

// Native screen/window capturer using Windows Graphics Capture API.
// Captures at a specified target resolution (GPU-accelerated downscaling)
// and pushes BGRA frames into a custom RTCVideoSource.
class NativeScreenCapturer {
 public:
  NativeScreenCapturer();
  ~NativeScreenCapturer();

  NativeScreenCapturer(const NativeScreenCapturer&) = delete;
  NativeScreenCapturer& operator=(const NativeScreenCapturer&) = delete;

  // Capture a monitor at the given target resolution.
  bool StartMonitor(HMONITOR monitor, UINT32 target_w, UINT32 target_h,
                    UINT32 fps,
                    libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source);

  // Capture a window at the given target resolution.
  bool StartWindow(HWND hwnd, UINT32 target_w, UINT32 target_h,
                   UINT32 fps,
                   libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source);

  void Stop();
  bool IsRunning() const { return running_.load(); }

 private:
  bool InitD3D11();
  bool StartInternal(
      winrt::Windows::Graphics::Capture::GraphicsCaptureItem item,
      UINT32 native_w, UINT32 native_h,
      UINT32 target_w, UINT32 target_h, UINT32 fps);
  void OnFrameArrived(
      winrt::Windows::Graphics::Capture::Direct3D11CaptureFramePool const& pool,
      winrt::Windows::Foundation::IInspectable const&);
  void Cleanup();

  static void ScaleBGRA(const uint8_t* src, UINT32 src_w, UINT32 src_h,
                        UINT32 src_stride, uint8_t* dst, UINT32 dst_w,
                        UINT32 dst_h);

  std::atomic<bool> running_{false};
  std::mutex mtx_;
  UINT32 native_w_ = 0;
  UINT32 native_h_ = 0;
  UINT32 target_w_ = 0;
  UINT32 target_h_ = 0;
  UINT32 fps_ = 30;
  bool needs_scale_ = false;
  std::vector<uint8_t> scale_buf_;

  // D3D11
  ComPtr<ID3D11Device> device_;
  ComPtr<ID3D11DeviceContext> ctx_;
  ComPtr<ID3D11Texture2D> staging_tex_;

  // Graphics Capture
  winrt::Windows::Graphics::Capture::GraphicsCaptureItem item_{nullptr};
  winrt::Windows::Graphics::Capture::Direct3D11CaptureFramePool pool_{nullptr};
  winrt::Windows::Graphics::Capture::GraphicsCaptureSession session_{nullptr};
  winrt::Windows::Graphics::Capture::Direct3D11CaptureFramePool::FrameArrived_revoker revoker_;

  // Frame rate limiting
  LARGE_INTEGER qpc_freq_ = {};
  INT64 last_frame_qpc_ = 0;

  // WebRTC video source to push frames into
  libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source_;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_NATIVE_SCREEN_CAPTURER_H_
