#ifndef NOMINMAX
#define NOMINMAX
#endif

#include "native_screen_capturer.h"

#include <windows.graphics.capture.interop.h>
#include <windows.graphics.directx.direct3d11.interop.h>
#include <winrt/Windows.Foundation.Metadata.h>

#include <iostream>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "windowsapp.lib")

namespace flutter_webrtc_plugin {
namespace {

winrt::Windows::Graphics::DirectX::Direct3D11::IDirect3DDevice
WrapD3D11Device(ID3D11Device* d3d) {
  ComPtr<IDXGIDevice> dxgi;
  d3d->QueryInterface(IID_PPV_ARGS(&dxgi));
  winrt::com_ptr<::IInspectable> inspectable;
  CreateDirect3D11DeviceFromDXGIDevice(dxgi.Get(), inspectable.put());
  return inspectable.as<
      winrt::Windows::Graphics::DirectX::Direct3D11::IDirect3DDevice>();
}

ID3D11Texture2D* GetDXGITexture(
    winrt::Windows::Graphics::Capture::Direct3D11CaptureFrame const& frame,
    ID3D11Device* device) {
  auto surface = frame.Surface();
  auto interop = surface.as<
      Windows::Graphics::DirectX::Direct3D11::IDirect3DDxgiInterfaceAccess>();
  ID3D11Texture2D* tex = nullptr;
  interop->GetInterface(IID_PPV_ARGS(&tex));
  return tex;
}

}  // namespace

NativeScreenCapturer::NativeScreenCapturer() {
  QueryPerformanceFrequency(&qpc_freq_);
}

NativeScreenCapturer::~NativeScreenCapturer() {
  Stop();
}

bool NativeScreenCapturer::InitD3D11() {
  D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_11_0};
  UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT |
               D3D11_CREATE_DEVICE_VIDEO_SUPPORT;
  HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
                                 flags, levels, 1, D3D11_SDK_VERSION,
                                 device_.ReleaseAndGetAddressOf(),
                                 nullptr,
                                 ctx_.ReleaseAndGetAddressOf());
  if (FAILED(hr)) {
    flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
    hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
                           flags, levels, 1, D3D11_SDK_VERSION,
                           device_.ReleaseAndGetAddressOf(),
                           nullptr,
                           ctx_.ReleaseAndGetAddressOf());
  }
  if (FAILED(hr)) {
    std::cerr << "[NativeCap] D3D11CreateDevice failed: 0x"
              << std::hex << hr << "\n";
    return false;
  }

  ComPtr<ID3D10Multithread> mt;
  if (SUCCEEDED(device_.As(&mt))) {
    mt->SetMultithreadProtected(TRUE);
  }

  return true;
}

bool NativeScreenCapturer::StartMonitor(
    HMONITOR monitor, UINT32 target_w, UINT32 target_h, UINT32 fps,
    libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source) {
  if (running_.load()) return false;

  // Get native monitor resolution.
  MONITORINFO mi = {sizeof(MONITORINFO)};
  if (!GetMonitorInfoW(monitor, &mi)) {
    std::cerr << "[NativeCap] GetMonitorInfo failed\n";
    return false;
  }
  UINT32 native_w = mi.rcMonitor.right - mi.rcMonitor.left;
  UINT32 native_h = mi.rcMonitor.bottom - mi.rcMonitor.top;

  auto interop = winrt::get_activation_factory<
      winrt::Windows::Graphics::Capture::GraphicsCaptureItem,
      IGraphicsCaptureItemInterop>();

  winrt::Windows::Graphics::Capture::GraphicsCaptureItem item{nullptr};
  HRESULT hr = interop->CreateForMonitor(
      monitor,
      winrt::guid_of<
          winrt::Windows::Graphics::Capture::GraphicsCaptureItem>(),
      reinterpret_cast<void**>(winrt::put_abi(item)));
  if (FAILED(hr) || !item) {
    std::cerr << "[NativeCap] CreateForMonitor failed: 0x"
              << std::hex << hr << "\n";
    return false;
  }

  source_ = source;
  return StartInternal(item, native_w, native_h, target_w, target_h, fps);
}

bool NativeScreenCapturer::StartWindow(
    HWND hwnd, UINT32 target_w, UINT32 target_h, UINT32 fps,
    libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source) {
  if (running_.load()) return false;

  // Get native window size.
  RECT rect;
  if (!GetClientRect(hwnd, &rect)) {
    std::cerr << "[NativeCap] GetClientRect failed\n";
    return false;
  }
  UINT32 native_w = rect.right - rect.left;
  UINT32 native_h = rect.bottom - rect.top;
  if (native_w == 0 || native_h == 0) {
    native_w = target_w;
    native_h = target_h;
  }

  auto interop = winrt::get_activation_factory<
      winrt::Windows::Graphics::Capture::GraphicsCaptureItem,
      IGraphicsCaptureItemInterop>();

  winrt::Windows::Graphics::Capture::GraphicsCaptureItem item{nullptr};
  HRESULT hr = interop->CreateForWindow(
      hwnd,
      winrt::guid_of<
          winrt::Windows::Graphics::Capture::GraphicsCaptureItem>(),
      reinterpret_cast<void**>(winrt::put_abi(item)));
  if (FAILED(hr) || !item) {
    std::cerr << "[NativeCap] CreateForWindow failed: 0x"
              << std::hex << hr << "\n";
    return false;
  }

  source_ = source;
  return StartInternal(item, native_w, native_h, target_w, target_h, fps);
}

bool NativeScreenCapturer::StartInternal(
    winrt::Windows::Graphics::Capture::GraphicsCaptureItem item,
    UINT32 native_w, UINT32 native_h,
    UINT32 target_w, UINT32 target_h, UINT32 fps) {

  native_w_ = native_w;
  native_h_ = native_h;
  target_w_ = target_w;
  target_h_ = target_h;
  fps_ = fps > 0 ? fps : 30;
  last_frame_qpc_ = 0;
  needs_scale_ = (target_w < native_w || target_h < native_h);

  if (needs_scale_) {
    scale_buf_.resize(static_cast<size_t>(target_w) * target_h * 4);
  }

  if (!InitD3D11()) {
    Cleanup();
    return false;
  }

  item_ = item;
  auto winrt_device = WrapD3D11Device(device_.Get());

  // Capture at NATIVE resolution — the full screen/window.
  pool_ = winrt::Windows::Graphics::Capture::Direct3D11CaptureFramePool::
      CreateFreeThreaded(
          winrt_device,
          winrt::Windows::Graphics::DirectX::DirectXPixelFormat::
              B8G8R8A8UIntNormalized,
          2, {static_cast<int32_t>(native_w), static_cast<int32_t>(native_h)});

  revoker_ = pool_.FrameArrived(
      winrt::auto_revoke,
      [this](auto const& pool, auto const&) {
        OnFrameArrived(pool, nullptr);
      });

  session_ = pool_.CreateCaptureSession(item_);
  session_.IsCursorCaptureEnabled(true);

  // Staging texture at native resolution for GPU→CPU readback.
  D3D11_TEXTURE2D_DESC desc = {};
  desc.Width = native_w;
  desc.Height = native_h;
  desc.MipLevels = 1;
  desc.ArraySize = 1;
  desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count = 1;
  desc.Usage = D3D11_USAGE_STAGING;
  desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  HRESULT hr = device_->CreateTexture2D(
      &desc, nullptr, staging_tex_.ReleaseAndGetAddressOf());
  if (FAILED(hr)) {
    std::cerr << "[NativeCap] CreateTexture2D(staging) failed\n";
    Cleanup();
    return false;
  }

  running_.store(true);
  session_.StartCapture();

  std::cerr << "[NativeCap] started " << native_w << "x" << native_h
            << " -> " << target_w << "x" << target_h
            << " @" << fps << "fps\n";
  return true;
}

void NativeScreenCapturer::ScaleBGRA(
    const uint8_t* src, UINT32 src_w, UINT32 src_h, UINT32 src_stride,
    uint8_t* dst, UINT32 dst_w, UINT32 dst_h) {
  const UINT32 dst_stride = dst_w * 4;
  const float x_ratio = static_cast<float>(src_w) / dst_w;
  const float y_ratio = static_cast<float>(src_h) / dst_h;

  for (UINT32 dy = 0; dy < dst_h; ++dy) {
    const float src_y = dy * y_ratio;
    const UINT32 sy = static_cast<UINT32>(src_y);
    const UINT32 sy1 = (sy + 1 < src_h) ? sy + 1 : sy;
    const float fy = src_y - sy;
    const float fy1 = 1.0f - fy;

    const uint8_t* row0 = src + sy * src_stride;
    const uint8_t* row1 = src + sy1 * src_stride;
    uint8_t* out = dst + dy * dst_stride;

    for (UINT32 dx = 0; dx < dst_w; ++dx) {
      const float src_x = dx * x_ratio;
      const UINT32 sx = static_cast<UINT32>(src_x);
      const UINT32 sx1 = (sx + 1 < src_w) ? sx + 1 : sx;
      const float fx = src_x - sx;
      const float fx1 = 1.0f - fx;

      const uint8_t* p00 = row0 + sx * 4;
      const uint8_t* p10 = row0 + sx1 * 4;
      const uint8_t* p01 = row1 + sx * 4;
      const uint8_t* p11 = row1 + sx1 * 4;

      for (int c = 0; c < 4; ++c) {
        float v = p00[c] * fx1 * fy1 + p10[c] * fx * fy1 +
                  p01[c] * fx1 * fy + p11[c] * fx * fy;
        out[c] = static_cast<uint8_t>(v + 0.5f);
      }
      out += 4;
    }
  }
}

void NativeScreenCapturer::OnFrameArrived(
    winrt::Windows::Graphics::Capture::Direct3D11CaptureFramePool const& pool,
    winrt::Windows::Foundation::IInspectable const&) {
  if (!running_.load()) return;

  auto frame = pool.TryGetNextFrame();
  if (!frame) return;

  LARGE_INTEGER qpc;
  QueryPerformanceCounter(&qpc);

  // Frame rate limiting.
  const INT64 min_interval = qpc_freq_.QuadPart / fps_;
  if (last_frame_qpc_ != 0 &&
      (qpc.QuadPart - last_frame_qpc_) < min_interval) {
    frame.Close();
    return;
  }
  last_frame_qpc_ = qpc.QuadPart;

  auto* tex = GetDXGITexture(frame, device_.Get());
  if (!tex) {
    frame.Close();
    return;
  }

  // GPU→CPU copy via staging texture (at native resolution).
  ctx_->CopyResource(staging_tex_.Get(), tex);
  tex->Release();
  frame.Close();

  D3D11_MAPPED_SUBRESOURCE mapped = {};
  HRESULT hr = ctx_->Map(staging_tex_.Get(), 0, D3D11_MAP_READ, 0, &mapped);
  if (FAILED(hr)) return;

  libwebrtc::scoped_refptr<libwebrtc::RTCVideoFrame> rtc_frame;

  if (needs_scale_) {
    // Bilinear downscale from native to target resolution.
    ScaleBGRA(static_cast<const uint8_t*>(mapped.pData),
              native_w_, native_h_, static_cast<UINT32>(mapped.RowPitch),
              scale_buf_.data(), target_w_, target_h_);
    ctx_->Unmap(staging_tex_.Get(), 0);

    rtc_frame = libwebrtc::RTCVideoFrame::CreateFromBGRA(
        static_cast<int>(target_w_), static_cast<int>(target_h_),
        scale_buf_.data(),
        static_cast<int>(target_w_ * 4));
  } else {
    // No scaling needed — target matches native.
    rtc_frame = libwebrtc::RTCVideoFrame::CreateFromBGRA(
        static_cast<int>(native_w_), static_cast<int>(native_h_),
        static_cast<const uint8_t*>(mapped.pData),
        static_cast<int>(mapped.RowPitch));
    ctx_->Unmap(staging_tex_.Get(), 0);
  }

  if (rtc_frame.get() && source_.get()) {
    source_->OnCapturedFrame(rtc_frame);
  }
}

void NativeScreenCapturer::Stop() {
  if (!running_.load()) return;
  running_.store(false);

  std::cerr << "[NativeCap] stopping\n";

  revoker_.revoke();
  if (session_) {
    session_.Close();
    session_ = nullptr;
  }
  if (pool_) {
    pool_.Close();
    pool_ = nullptr;
  }
  item_ = nullptr;

  Cleanup();
  source_ = nullptr;
}

void NativeScreenCapturer::Cleanup() {
  staging_tex_.Reset();
  ctx_.Reset();
  device_.Reset();
  scale_buf_.clear();
  scale_buf_.shrink_to_fit();
}

}  // namespace flutter_webrtc_plugin
