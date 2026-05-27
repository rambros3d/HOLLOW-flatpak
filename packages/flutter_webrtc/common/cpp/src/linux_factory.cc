#include <cstdint>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>
#include <map>

#include "api/create_peerconnection_factory.h"
#include "api/environment/environment_factory.h"
#include "api/media_stream_interface.h"
#include "api/peer_connection_interface.h"
#include "api/video/i420_buffer.h"
#include "api/video/video_frame.h"
#include "api/video/video_frame_buffer.h"
#include "api/video/video_sink_interface.h"
#include "api/video/video_source_interface.h"
#include "api/video_codecs/builtin_video_decoder_factory.h"
#include "api/video_codecs/builtin_video_encoder_factory.h"
#include "api/audio_codecs/builtin_audio_encoder_factory.h"
#include "api/audio_codecs/builtin_audio_decoder_factory.h"
#include "api/audio_options.h"
#include "pc/video_track_source.h"
#include "media/base/video_broadcaster.h"
#include "rtc_base/thread.h"
#include "rtc_base/time_utils.h"
#include "rtc_base/ref_counted_object.h"
#include "api/make_ref_counted.h"
#include "modules/audio_device/include/audio_device.h"
#include "modules/audio_processing/include/audio_processing.h"
#include "modules/audio_mixer/audio_mixer_impl.h"
#include "api/audio/create_audio_device_module.h"
#include "api/audio/builtin_audio_processing_builder.h"

#include "base/refcountedobject.h"
#include "rtc_audio_device.h"
#include "rtc_audio_processing.h"
#include "rtc_audio_source.h"
#include "rtc_audio_track.h"
#include "rtc_desktop_capturer.h"
#include "rtc_desktop_media_list.h"
#include "rtc_media_stream.h"
#include "rtc_media_track.h"
#include "rtc_peerconnection.h"
#include "rtc_rtp_receiver.h"
#include "rtc_rtp_sender.h"
#include "rtc_rtp_transceiver.h"
#include "rtc_video_device.h"
#include "rtc_video_frame.h"
#include "rtc_video_source.h"
#include "rtc_video_track.h"
#include "libwebrtc.h"
#include "helper.h"
#include "rtc_desktop_device.h"
#include "rtc_desktop_capturer.h"
#include "api/media_types.h"

namespace libwebrtc {

using namespace webrtc;

// ============================================================================
// LinuxRTCVideoFrame — wraps webrtc::VideoFrame
// ============================================================================

class LinuxRTCVideoFrame : public RTCVideoFrame {
 public:
  static scoped_refptr<RTCVideoFrame> CreateFromVideoFrame(
      const webrtc::VideoFrame& frame) {
    return new RefCountedObject<LinuxRTCVideoFrame>(frame);
  }

  explicit LinuxRTCVideoFrame(const webrtc::VideoFrame& frame)
      : frame_(frame) {}

  scoped_refptr<RTCVideoFrame> Copy() override {
    return new RefCountedObject<LinuxRTCVideoFrame>(frame_);
  }

  int width() const override {
    if (!frame_.video_frame_buffer()) return 0;
    return frame_.video_frame_buffer()->width();
  }

  int height() const override {
    if (!frame_.video_frame_buffer()) return 0;
    return frame_.video_frame_buffer()->height();
  }

  VideoRotation rotation() override {
    return static_cast<VideoRotation>(frame_.rotation());
  }

  const uint8_t* DataY() const override {
    auto buf = frame_.video_frame_buffer();
    if (!buf) return nullptr;
    auto i420 = buf->ToI420();
    if (!i420) return nullptr;
    return i420->DataY();
  }

  const uint8_t* DataU() const override {
    auto buf = frame_.video_frame_buffer();
    if (!buf) return nullptr;
    auto i420 = buf->ToI420();
    if (!i420) return nullptr;
    return i420->DataU();
  }

  const uint8_t* DataV() const override {
    auto buf = frame_.video_frame_buffer();
    if (!buf) return nullptr;
    auto i420 = buf->ToI420();
    if (!i420) return nullptr;
    return i420->DataV();
  }

  int StrideY() const override {
    auto buf = frame_.video_frame_buffer();
    if (!buf) return 0;
    auto i420 = buf->ToI420();
    if (!i420) return 0;
    return i420->StrideY();
  }

  int StrideU() const override {
    auto buf = frame_.video_frame_buffer();
    if (!buf) return 0;
    auto i420 = buf->ToI420();
    if (!i420) return 0;
    return i420->StrideU();
  }

  int StrideV() const override {
    auto buf = frame_.video_frame_buffer();
    if (!buf) return 0;
    auto i420 = buf->ToI420();
    if (!i420) return 0;
    return i420->StrideV();
  }

  int ConvertToARGB(Type type, uint8_t* dst_argb, int dst_stride_argb,
                    int dest_width, int dest_height) override {
    auto buf = frame_.video_frame_buffer();
    if (!buf) return -1;
    auto i420 = buf->ToI420();
    if (!i420) return -1;

    int src_w = i420->width();
    int src_h = i420->height();

    if (dest_width <= 0) dest_width = src_w;
    if (dest_height <= 0) dest_height = src_h;

    int stride_argb = dst_stride_argb;
    if (stride_argb <= 0) stride_argb = dest_width * 4;

    const uint8_t* src_y = i420->DataY();
    const uint8_t* src_u = i420->DataU();
    const uint8_t* src_v = i420->DataV();
    int stride_y = i420->StrideY();
    int stride_u = i420->StrideU();
    int stride_v = i420->StrideV();

    for (int h = 0; h < dest_height; h++) {
      int src_h_idx = h * src_h / dest_height;
      for (int w = 0; w < dest_width; w++) {
        int src_w_idx = w * src_w / dest_width;

        int y = src_y[src_h_idx * stride_y + src_w_idx];
        int u = src_u[(src_h_idx / 2) * stride_u + (src_w_idx / 2)];
        int v = src_v[(src_h_idx / 2) * stride_v + (src_w_idx / 2)];

        int c = y - 16;
        int d = u - 128;
        int e = v - 128;

        int r = (298 * c + 409 * e + 128) >> 8;
        int g = (298 * c - 100 * d - 208 * e + 128) >> 8;
        int b = (298 * c + 516 * d + 128) >> 8;

        if (r < 0) r = 0; if (r > 255) r = 255;
        if (g < 0) g = 0; if (g > 255) g = 255;
        if (b < 0) b = 0; if (b > 255) b = 255;

        uint8_t* pixel = dst_argb + h * stride_argb + w * 4;
        if (type == Type::kARGB) {
          pixel[0] = r; pixel[1] = g; pixel[2] = b; pixel[3] = 255;
        } else if (type == Type::kBGRA) {
          pixel[0] = b; pixel[1] = g; pixel[2] = r; pixel[3] = 255;
        } else if (type == Type::kABGR) {
          pixel[0] = b; pixel[1] = g; pixel[2] = r; pixel[3] = 255;
        } else {
          pixel[0] = r; pixel[1] = g; pixel[2] = b; pixel[3] = 255;
        }
      }
    }
    return 0;
  }

  const webrtc::VideoFrame& webrtc_frame() const { return frame_; }

 private:
  webrtc::VideoFrame frame_;
};

static void I420CopyManual(const uint8_t* src_y, int stride_y,
                            const uint8_t* src_u, int stride_u,
                            const uint8_t* src_v, int stride_v,
                            uint8_t* dst_y, int dst_stride_y,
                            uint8_t* dst_u, int dst_stride_u,
                            uint8_t* dst_v, int dst_stride_v,
                            int width, int height) {
  for (int h = 0; h < height; h++)
    memcpy(dst_y + h * dst_stride_y, src_y + h * stride_y, width);
  int uv_h = (height + 1) / 2;
  int uv_w = (width + 1) / 2;
  for (int h = 0; h < uv_h; h++) {
    memcpy(dst_u + h * dst_stride_u, src_u + h * stride_u, uv_w);
    memcpy(dst_v + h * dst_stride_v, src_v + h * stride_v, uv_w);
  }
}

static void NV12ToI420Manual(const uint8_t* src_y, int stride_y,
                              const uint8_t* src_uv, int stride_uv,
                              uint8_t* dst_y, int dst_stride_y,
                              uint8_t* dst_u, int dst_stride_u,
                              uint8_t* dst_v, int dst_stride_v,
                              int width, int height) {
  for (int h = 0; h < height; h++)
    memcpy(dst_y + h * dst_stride_y, src_y + h * stride_y, width);
  int uv_h = (height + 1) / 2;
  int uv_w = (width + 1) / 2;
  for (int h = 0; h < uv_h; h++) {
    for (int w = 0; w < uv_w; w++) {
      dst_u[h * dst_stride_u + w] = src_uv[h * stride_uv + w * 2];
      dst_v[h * dst_stride_v + w] = src_uv[h * stride_uv + w * 2 + 1];
    }
  }
}

static void BGRAtoI420(const uint8_t* bgra, int stride_bgra,
                       uint8_t* y_plane, int stride_y,
                       uint8_t* u_plane, int stride_u,
                       uint8_t* v_plane, int stride_v,
                       int width, int height) {
  for (int h = 0; h < height; h++) {
    for (int w = 0; w < width; w++) {
      int idx = h * stride_bgra + w * 4;
      int b = bgra[idx];
      int g = bgra[idx + 1];
      int r = bgra[idx + 2];

      int y = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
      if (y < 0) y = 0; if (y > 255) y = 255;
      y_plane[h * stride_y + w] = static_cast<uint8_t>(y);

      if ((h & 1) == 0 && (w & 1) == 0) {
        int u = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
        int v = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;
        if (u < 0) u = 0; if (u > 255) u = 255;
        if (v < 0) v = 0; if (v > 255) v = 255;
        u_plane[(h / 2) * stride_u + (w / 2)] = static_cast<uint8_t>(u);
        v_plane[(h / 2) * stride_v + (w / 2)] = static_cast<uint8_t>(v);
      }
    }
  }
}

// ============================================================================
// RTCVideoFrame static factories
// ============================================================================

scoped_refptr<RTCVideoFrame> RTCVideoFrame::Create(
    int width, int height, const uint8_t* buffer, int length) {
  auto i420 = webrtc::I420Buffer::Create(width, height);
  memcpy(i420->MutableDataY(), buffer, width * height);
  int uv_w = (width + 1) / 2;
  int uv_h = (height + 1) / 2;
  memset(i420->MutableDataU(), 128, uv_w * uv_h);
  memset(i420->MutableDataV(), 128, uv_w * uv_h);
  auto frame = webrtc::VideoFrame::Builder()
      .set_video_frame_buffer(i420)
      .set_rotation(webrtc::kVideoRotation_0)
      .set_timestamp_us(TimeMicros())
      .build();
  return new RefCountedObject<LinuxRTCVideoFrame>(frame);
}

scoped_refptr<RTCVideoFrame> RTCVideoFrame::Create(
    int width, int height,
    const uint8_t* data_y, int stride_y,
    const uint8_t* data_u, int stride_u,
    const uint8_t* data_v, int stride_v) {
  auto i420 = webrtc::I420Buffer::Create(width, height);
  I420CopyManual(data_y, stride_y, data_u, stride_u, data_v, stride_v,
                 i420->MutableDataY(), i420->StrideY(),
                 i420->MutableDataU(), i420->StrideU(),
                 i420->MutableDataV(), i420->StrideV(),
                 width, height);
  auto frame = webrtc::VideoFrame::Builder()
      .set_video_frame_buffer(i420)
      .set_rotation(webrtc::kVideoRotation_0)
      .set_timestamp_us(TimeMicros())
      .build();
  return new RefCountedObject<LinuxRTCVideoFrame>(frame);
}

scoped_refptr<RTCVideoFrame> RTCVideoFrame::CreateFromBGRA(
    int width, int height, const uint8_t* bgra, int stride_bgra) {
  auto i420 = webrtc::I420Buffer::Create(width, height);
  BGRAtoI420(bgra, stride_bgra,
             i420->MutableDataY(), i420->StrideY(),
             i420->MutableDataU(), i420->StrideU(),
             i420->MutableDataV(), i420->StrideV(),
             width, height);
  auto frame = webrtc::VideoFrame::Builder()
      .set_video_frame_buffer(i420)
      .set_rotation(webrtc::kVideoRotation_0)
      .set_timestamp_us(TimeMicros())
      .build();
  return new RefCountedObject<LinuxRTCVideoFrame>(frame);
}

scoped_refptr<RTCVideoFrame> RTCVideoFrame::CreateFromNV12(
    int width, int height,
    const uint8_t* data_y, int stride_y,
    const uint8_t* data_uv, int stride_uv) {
  auto i420 = webrtc::I420Buffer::Create(width, height);
  NV12ToI420Manual(data_y, stride_y, data_uv, stride_uv,
                   i420->MutableDataY(), i420->StrideY(),
                   i420->MutableDataU(), i420->StrideU(),
                   i420->MutableDataV(), i420->StrideV(),
                   width, height);
  auto frame = webrtc::VideoFrame::Builder()
      .set_video_frame_buffer(i420)
      .set_rotation(webrtc::kVideoRotation_0)
      .set_timestamp_us(TimeMicros())
      .build();
  return new RefCountedObject<LinuxRTCVideoFrame>(frame);
}

// ============================================================================
// LinuxRTCVideoSource — implements RTCVideoSource, wraps webrtc::VideoTrackSource
// ============================================================================

class LinuxRTCVideoSource : public RTCVideoSource {
 public:
  class InternalVideoTrackSource : public webrtc::VideoTrackSource {
   public:
    InternalVideoTrackSource()
        : webrtc::VideoTrackSource(false) {}

    void PushFrame(const webrtc::VideoFrame& frame) {
      broadcaster_.OnFrame(frame);
    }

   protected:
    webrtc::VideoSourceInterface<webrtc::VideoFrame>* source() override {
      return &broadcaster_;
    }

   private:
    webrtc::VideoBroadcaster broadcaster_;
  };

  LinuxRTCVideoSource()
      : track_source_(make_ref_counted<InternalVideoTrackSource>()) {}

  void OnCapturedFrame(scoped_refptr<RTCVideoFrame> frame) override {
    auto* linux_frame = static_cast<LinuxRTCVideoFrame*>(frame.get());
    if (linux_frame) {
      track_source_->PushFrame(linux_frame->webrtc_frame());
    }
  }

  SourceType GetSourceType() const override {
    return SourceType::kCustom;
  }

  webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> webrtc_source() const {
    return track_source_;
  }

 private:
  webrtc::scoped_refptr<InternalVideoTrackSource> track_source_;
};

// ============================================================================
// LinuxRTCVideoTrack — implements RTCVideoTrack, wraps webrtc::VideoTrackInterface
// ============================================================================

class LinuxRTCVideoTrack : public RTCVideoTrack {
 public:
  explicit LinuxRTCVideoTrack(
      webrtc::scoped_refptr<webrtc::VideoTrackInterface> track)
      : track_(std::move(track)) {}

  void AddRenderer(
      RTCVideoRenderer<scoped_refptr<RTCVideoFrame>>* renderer) override {
    renderers_.push_back(renderer);
  }

  void RemoveRenderer(
      RTCVideoRenderer<scoped_refptr<RTCVideoFrame>>* renderer) override {
    auto it = std::find(renderers_.begin(), renderers_.end(), renderer);
    if (it != renderers_.end()) renderers_.erase(it);
  }

  RTCTrackState state() const override {
    return track_->state() == webrtc::MediaStreamTrackInterface::kLive
        ? kLive : kEnded;
  }

  const string kind() const override {
    portable::string result;
    result.init("video", 5);
    return result;
  }

  const string id() const override {
    auto sid = track_->id();
    portable::string result;
    result.init(sid.data(), sid.size());
    return result;
  }

  bool enabled() const override { return track_->enabled(); }

  bool set_enabled(bool enable) override {
    return track_->set_enabled(enable);
  }

  webrtc::scoped_refptr<webrtc::VideoTrackInterface> webrtc_track() const {
    return track_;
  }

 private:
  webrtc::scoped_refptr<webrtc::VideoTrackInterface> track_;
  std::vector<RTCVideoRenderer<scoped_refptr<RTCVideoFrame>>*> renderers_;
};

// ============================================================================
// LinuxRTCAudioTrack — implements RTCAudioTrack, wraps webrtc::AudioTrackInterface
// ============================================================================

class LinuxRTCAudioTrack : public RTCAudioTrack,
                            public webrtc::AudioTrackSinkInterface {
 public:
  explicit LinuxRTCAudioTrack(
      webrtc::scoped_refptr<webrtc::AudioTrackInterface> track)
      : track_(std::move(track)) {}

  webrtc::scoped_refptr<webrtc::AudioTrackInterface> webrtc_track() const {
    return track_;
  }

  void SetVolume(double volume) override {
    // Volume is set on the audio source, not the track — no-op
  }

  void AddSink(AudioTrackSink* sink) override {
    sinks_.push_back(sink);
    track_->AddSink(this);
  }

  void RemoveSink(AudioTrackSink* sink) override {
    auto it = std::find(sinks_.begin(), sinks_.end(), sink);
    if (it != sinks_.end()) sinks_.erase(it);
  }

  void OnData(const void* audio_data, int bits_per_sample,
              int sample_rate, size_t number_of_channels,
              size_t number_of_frames) override {
    for (auto* sink : sinks_) {
      sink->OnData(audio_data, bits_per_sample, sample_rate,
                    number_of_channels, number_of_frames);
    }
  }

  RTCTrackState state() const override {
    return track_->state() == webrtc::MediaStreamTrackInterface::kLive
        ? kLive : kEnded;
  }

  const string kind() const override {
    portable::string result;
    result.init("audio", 5);
    return result;
  }

  const string id() const override {
    auto sid = track_->id();
    portable::string result;
    result.init(sid.data(), sid.size());
    return result;
  }

  bool enabled() const override { return track_->enabled(); }
  bool set_enabled(bool enable) override { return track_->set_enabled(enable); }

 private:
  webrtc::scoped_refptr<webrtc::AudioTrackInterface> track_;
  std::vector<AudioTrackSink*> sinks_;
};

// ============================================================================
// LinuxRTCMediaStream — implements RTCMediaStream, wraps webrtc::MediaStreamInterface
// ============================================================================

class LinuxRTCMediaStream : public RTCMediaStream {
 public:
  explicit LinuxRTCMediaStream(
      webrtc::scoped_refptr<webrtc::MediaStreamInterface> stream)
      : stream_(std::move(stream)) {}

  bool AddTrack(scoped_refptr<RTCAudioTrack> track) override {
    auto* linux_track = static_cast<LinuxRTCAudioTrack*>(track.get());
    if (!linux_track) return false;
    return stream_->AddTrack(linux_track->webrtc_track());
  }

  bool AddTrack(scoped_refptr<RTCVideoTrack> track) override {
    auto* linux_track = static_cast<LinuxRTCVideoTrack*>(track.get());
    if (!linux_track) return false;
    return stream_->AddTrack(linux_track->webrtc_track());
  }

  bool RemoveTrack(scoped_refptr<RTCAudioTrack> track) override {
    auto* linux_track = static_cast<LinuxRTCAudioTrack*>(track.get());
    if (!linux_track) return false;
    return stream_->RemoveTrack(linux_track->webrtc_track());
  }

  bool RemoveTrack(scoped_refptr<RTCVideoTrack> track) override {
    auto* linux_track = static_cast<LinuxRTCVideoTrack*>(track.get());
    if (!linux_track) return false;
    return stream_->RemoveTrack(linux_track->webrtc_track());
  }

  vector<scoped_refptr<RTCAudioTrack>> audio_tracks() override {
    auto rt = stream_->GetAudioTracks();
    return vector<scoped_refptr<RTCAudioTrack>>(rt,
        [](const webrtc::scoped_refptr<webrtc::AudioTrackInterface>& t) {
          return scoped_refptr<RTCAudioTrack>(
              static_cast<RTCAudioTrack*>(
                  new RefCountedObject<LinuxRTCAudioTrack>(t)));
        });
  }

  vector<scoped_refptr<RTCVideoTrack>> video_tracks() override {
    auto rt = stream_->GetVideoTracks();
    return vector<scoped_refptr<RTCVideoTrack>>(rt,
        [](const webrtc::scoped_refptr<webrtc::VideoTrackInterface>& t) {
          return scoped_refptr<RTCVideoTrack>(
              static_cast<RTCVideoTrack*>(
                  new RefCountedObject<LinuxRTCVideoTrack>(t)));
        });
  }

  vector<scoped_refptr<RTCMediaTrack>> tracks() override {
    auto audio = stream_->GetAudioTracks();
    auto video = stream_->GetVideoTracks();
    std::vector<scoped_refptr<RTCMediaTrack>> all;
    for (auto& t : audio)
      all.push_back(scoped_refptr<RTCMediaTrack>(
          static_cast<RTCMediaTrack*>(
              new RefCountedObject<LinuxRTCAudioTrack>(t))));
    for (auto& t : video)
      all.push_back(scoped_refptr<RTCMediaTrack>(
          static_cast<RTCMediaTrack*>(
              new RefCountedObject<LinuxRTCVideoTrack>(t))));
    return vector<scoped_refptr<RTCMediaTrack>>(all);
  }

  scoped_refptr<RTCAudioTrack> FindAudioTrack(const string track_id) override {
    auto t = stream_->FindAudioTrack(track_id.std_string());
    if (!t) return nullptr;
    return new RefCountedObject<LinuxRTCAudioTrack>(t);
  }

  scoped_refptr<RTCVideoTrack> FindVideoTrack(const string track_id) override {
    auto t = stream_->FindVideoTrack(track_id.std_string());
    if (!t) return nullptr;
    return new RefCountedObject<LinuxRTCVideoTrack>(t);
  }

  const string label() override {
    auto l = stream_->id();
    portable::string result;
    result.init(l.data(), l.size());
    return result;
  }

  const string id() override {
    auto sid = stream_->id();
    portable::string result;
    result.init(sid.data(), sid.size());
    return result;
  }

  webrtc::scoped_refptr<webrtc::MediaStreamInterface> webrtc_stream() const {
    return stream_;
  }

 private:
  webrtc::scoped_refptr<webrtc::MediaStreamInterface> stream_;
};

// ============================================================================
// LinuxRTCRtpSender — implements RTCRtpSender, wraps webrtc::RtpSenderInterface
// ============================================================================

class LinuxRTCRtpSender : public RTCRtpSender {
 public:
  explicit LinuxRTCRtpSender(
      webrtc::scoped_refptr<webrtc::RtpSenderInterface> sender)
      : sender_(std::move(sender)) {}

  bool set_track(scoped_refptr<RTCMediaTrack> track) override {
    webrtc::scoped_refptr<webrtc::MediaStreamTrackInterface> webrtc_track;
    if (track) {
      if (auto* vt = static_cast<LinuxRTCVideoTrack*>(track.get())) {
        webrtc_track = vt->webrtc_track();
      } else if (auto* at = static_cast<LinuxRTCAudioTrack*>(track.get())) {
        webrtc_track = at->webrtc_track();
      }
    }
    return sender_->SetTrack(webrtc_track.get());
  }

  scoped_refptr<RTCMediaTrack> track() const override {
    auto t = sender_->track();
    if (!t) return nullptr;
    if (t->kind() == webrtc::MediaStreamTrackInterface::kVideoKind) {
      auto* raw = static_cast<webrtc::VideoTrackInterface*>(t.get());
      return new RefCountedObject<LinuxRTCVideoTrack>(
          webrtc::scoped_refptr<webrtc::VideoTrackInterface>(raw));
    }
    auto* raw = static_cast<webrtc::AudioTrackInterface*>(t.get());
    return new RefCountedObject<LinuxRTCAudioTrack>(
        webrtc::scoped_refptr<webrtc::AudioTrackInterface>(raw));
  }

  scoped_refptr<RTCDtlsTransport> dtls_transport() const override {
    return nullptr;
  }
  uint32_t ssrc() const override { return sender_->ssrc(); }
  RTCMediaType media_type() const override {
    return sender_->media_type() == webrtc::MediaType::VIDEO
        ? RTCMediaType::VIDEO
        : RTCMediaType::AUDIO;
  }
  const string id() const override {
    portable::string result;
    auto sid = sender_->id();
    result.init(sid.data(), sid.size());
    return result;
  }
  const vector<string> stream_ids() const override {
    auto ids = sender_->stream_ids();
    return vector<string>(ids,
        [](const std::string& s) {
          portable::string ps;
          ps.init(s.data(), s.size());
          return ps;
        });
  }
  void set_stream_ids(const vector<string> stream_ids) const override {}
  const vector<scoped_refptr<RTCRtpEncodingParameters>>
  init_send_encodings() const override {
    return {};
  }
  scoped_refptr<RTCRtpParameters> parameters() const override {
    return nullptr;
  }
  bool set_parameters(const scoped_refptr<RTCRtpParameters> parameters) override {
    return false;
  }
  scoped_refptr<RTCDtmfSender> dtmf_sender() const override {
    return nullptr;
  }

  webrtc::scoped_refptr<webrtc::RtpSenderInterface> webrtc_sender() const {
    return sender_;
  }

 private:
  webrtc::scoped_refptr<webrtc::RtpSenderInterface> sender_;
};

// ============================================================================
// LinuxRTCRtpReceiver — implements RTCRtpReceiver, wraps webrtc::RtpReceiverInterface
// ============================================================================

class LinuxRTCRtpReceiver : public RTCRtpReceiver {
 public:
  explicit LinuxRTCRtpReceiver(
      webrtc::scoped_refptr<webrtc::RtpReceiverInterface> receiver)
      : receiver_(std::move(receiver)) {}

  scoped_refptr<RTCMediaTrack> track() const override {
    auto t = receiver_->track();
    if (!t) return nullptr;
    if (t->kind() == webrtc::MediaStreamTrackInterface::kVideoKind) {
      auto* raw = static_cast<webrtc::VideoTrackInterface*>(t.get());
      return new RefCountedObject<LinuxRTCVideoTrack>(
          webrtc::scoped_refptr<webrtc::VideoTrackInterface>(raw));
    }
    auto* raw = static_cast<webrtc::AudioTrackInterface*>(t.get());
    return new RefCountedObject<LinuxRTCAudioTrack>(
        webrtc::scoped_refptr<webrtc::AudioTrackInterface>(raw));
  }

  const vector<string> stream_ids() const override {
    auto ids = receiver_->stream_ids();
    return vector<string>(ids,
        [](const std::string& s) {
          portable::string ps;
          ps.init(s.data(), s.size());
          return ps;
        });
  }

  const string id() const override {
    portable::string result;
    auto rid = receiver_->id();
    result.init(rid.data(), rid.size());
    return result;
  }

  RTCMediaType media_type() const override {
    return receiver_->media_type() == webrtc::MediaType::VIDEO
        ? RTCMediaType::VIDEO
        : RTCMediaType::AUDIO;
  }

  scoped_refptr<RTCDtlsTransport> dtls_transport() const override {
    return nullptr;
  }

  vector<scoped_refptr<RTCMediaStream>> streams() const override {
    return vector<scoped_refptr<RTCMediaStream>>();
  }

  scoped_refptr<RTCRtpParameters> parameters() const override {
    return nullptr;
  }

  bool set_parameters(scoped_refptr<RTCRtpParameters> parameters) override {
    return false;
  }

  void SetObserver(RTCRtpReceiverObserver* observer) override {}

  void SetJitterBufferMinimumDelay(double delay_seconds) override {}

 private:
  webrtc::scoped_refptr<webrtc::RtpReceiverInterface> receiver_;
};

// ============================================================================
// LinuxRTCRtpTransceiver — wraps webrtc::RtpTransceiverInterface
// ============================================================================

class LinuxRTCRtpTransceiver : public RTCRtpTransceiver {
 public:
  explicit LinuxRTCRtpTransceiver(
      webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> transceiver)
      : transceiver_(std::move(transceiver)) {}

  RTCMediaType media_type() const override {
    return transceiver_->media_type() == webrtc::MediaType::VIDEO
        ? RTCMediaType::VIDEO
        : RTCMediaType::AUDIO;
  }

  const string mid() const override {
    auto m = transceiver_->mid();
    portable::string result;
    if (m.has_value()) result.init(m->data(), m->size());
    return result;
  }

  scoped_refptr<RTCRtpSender> sender() const override {
    return new RefCountedObject<LinuxRTCRtpSender>(transceiver_->sender());
  }

  scoped_refptr<RTCRtpReceiver> receiver() const override {
    return new RefCountedObject<LinuxRTCRtpReceiver>(
        transceiver_->receiver());
  }

  bool Stopped() const override { return transceiver_->stopped(); }
  bool Stopping() const override { return transceiver_->stopping(); }

  RTCRtpTransceiverDirection direction() const override {
    return static_cast<RTCRtpTransceiverDirection>(
        transceiver_->direction());
  }

  const string SetDirectionWithError(
      RTCRtpTransceiverDirection new_direction) override {
    auto result = transceiver_->SetDirectionWithError(
        static_cast<webrtc::RtpTransceiverDirection>(new_direction));
    if (result.ok()) return portable::string();
    portable::string err;
    std::string msg = result.message();
    err.init(msg.data(), msg.size());
    return err;
  }

  RTCRtpTransceiverDirection current_direction() const override {
    auto d = transceiver_->current_direction();
    if (d.has_value())
      return static_cast<RTCRtpTransceiverDirection>(*d);
    return RTCRtpTransceiverDirection::kStopped;
  }

  RTCRtpTransceiverDirection fired_direction() const override {
    auto d = transceiver_->fired_direction();
    if (d.has_value())
      return static_cast<RTCRtpTransceiverDirection>(*d);
    return RTCRtpTransceiverDirection::kStopped;
  }

  const string StopStandard() override {
    auto result = transceiver_->StopStandard();
    if (result.ok()) return portable::string();
    portable::string err;
    std::string msg = result.message();
    err.init(msg.data(), msg.size());
    return err;
  }

  void StopInternal() override { transceiver_->StopInternal(); }

  void SetCodecPreferences(
      vector<scoped_refptr<RTCRtpCodecCapability>> codecs) override {}

  const string transceiver_id() const override {
    portable::string result;
    auto mid = transceiver_->mid();
    if (mid.has_value()) result.init(mid->data(), mid->size());
    return result;
  }

 private:
  webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> transceiver_;
};

// ============================================================================
// LinuxRTCPeerConnection — wraps webrtc::PeerConnectionInterface
// ============================================================================

class LinuxRTCPeerConnection : public RTCPeerConnection {
 public:
  // Proxy observer — passed to PeerConnectionDependencies at PC creation.
  // Holds a settable delegate pointer used via RegisterRTCPeerConnectionObserver.
  class ProxyObserver : public webrtc::PeerConnectionObserver {
   public:
    void SetDelegate(RTCPeerConnectionObserver* delegate) {
      delegate_ = delegate;
    }

    void OnSignalingChange(
        webrtc::PeerConnectionInterface::SignalingState state) override {
      if (delegate_)
        delegate_->OnSignalingState(static_cast<RTCSignalingState>(state));
    }

    void OnIceConnectionChange(
        webrtc::PeerConnectionInterface::IceConnectionState state) override {
      if (delegate_)
        delegate_->OnIceConnectionState(static_cast<RTCIceConnectionState>(state));
    }

    void OnStandardizedIceConnectionChange(
        webrtc::PeerConnectionInterface::IceConnectionState state) override {
      if (delegate_)
        delegate_->OnIceConnectionState(static_cast<RTCIceConnectionState>(state));
    }

    void OnConnectionChange(
        webrtc::PeerConnectionInterface::PeerConnectionState state) override {
      if (delegate_)
        delegate_->OnPeerConnectionState(static_cast<RTCPeerConnectionState>(state));
    }

    void OnIceGatheringChange(
        webrtc::PeerConnectionInterface::IceGatheringState state) override {
      if (delegate_)
        delegate_->OnIceGatheringState(static_cast<RTCIceGatheringState>(state));
    }

    void OnIceCandidate(const webrtc::IceCandidate* candidate) override {
      if (delegate_ && candidate) {
        std::string sdp, mid;
        int idx = 0;
        candidate->ToString(&sdp);
        mid = candidate->sdp_mid();
        idx = candidate->sdp_mline_index();
        portable::string sp, mp;
        sp.init(sdp.data(), sdp.size());
        mp.init(mid.data(), mid.size());
        auto ice = RTCIceCandidate::Create(sp, mp, idx, nullptr);
        delegate_->OnIceCandidate(ice);
      }
    }

    void OnAddStream(
        webrtc::scoped_refptr<webrtc::MediaStreamInterface> stream) override {
      if (delegate_)
        delegate_->OnAddStream(
            new RefCountedObject<LinuxRTCMediaStream>(stream));
    }

    void OnRemoveStream(
        webrtc::scoped_refptr<webrtc::MediaStreamInterface> stream) override {
      if (delegate_)
        delegate_->OnRemoveStream(
            new RefCountedObject<LinuxRTCMediaStream>(stream));
    }

    void OnDataChannel(
        webrtc::scoped_refptr<webrtc::DataChannelInterface> data_channel) override {
      if (delegate_) delegate_->OnDataChannel(nullptr);
    }

    void OnRenegotiationNeeded() override {
      if (delegate_) delegate_->OnRenegotiationNeeded();
    }

    void OnTrack(
        webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> transceiver) override {
      if (delegate_) {
        delegate_->OnTrack(
            new RefCountedObject<LinuxRTCRtpTransceiver>(transceiver));
      }
    }

    void OnAddTrack(
        webrtc::scoped_refptr<webrtc::RtpReceiverInterface> receiver,
        const std::vector<webrtc::scoped_refptr<webrtc::MediaStreamInterface>>&
            streams) override {
      if (delegate_) {
        vector<scoped_refptr<RTCMediaStream>> s;
        std::vector<scoped_refptr<RTCMediaStream>> tmp;
        for (auto& st : streams)
          tmp.push_back(new RefCountedObject<LinuxRTCMediaStream>(st));
        s = vector<scoped_refptr<RTCMediaStream>>(tmp);
        delegate_->OnAddTrack(
            s, new RefCountedObject<LinuxRTCRtpReceiver>(receiver));
      }
    }

    void OnRemoveTrack(
        webrtc::scoped_refptr<webrtc::RtpReceiverInterface> receiver) override {
      if (delegate_)
        delegate_->OnRemoveTrack(
            new RefCountedObject<LinuxRTCRtpReceiver>(receiver));
    }

   private:
    RTCPeerConnectionObserver* delegate_ = nullptr;
  };

  explicit LinuxRTCPeerConnection(
      webrtc::scoped_refptr<webrtc::PeerConnectionInterface> pc,
      webrtc::scoped_refptr<webrtc::PeerConnectionFactoryInterface> pcf,
      std::unique_ptr<ProxyObserver> proxy)
      : pc_(std::move(pc)), pcf_(std::move(pcf)), proxy_observer_(std::move(proxy)) {}

  int AddStream(scoped_refptr<RTCMediaStream> stream) override {
    return 0;
  }

  int RemoveStream(scoped_refptr<RTCMediaStream> stream) override {
    return 0;
  }

  scoped_refptr<RTCMediaStream> CreateLocalMediaStream(
      const string stream_id) override {
    auto stream = pcf_->CreateLocalMediaStream(stream_id.std_string());
    return new RefCountedObject<LinuxRTCMediaStream>(stream);
  }

  scoped_refptr<RTCDataChannel> CreateDataChannel(
      const string label, RTCDataChannelInit* dataChannelDict) override {
    return nullptr;
  }

  void CreateOffer(OnSdpCreateSuccess success,
                   OnSdpCreateFailure failure,
                   scoped_refptr<RTCMediaConstraints> constraints) override {
    class Observer : public webrtc::CreateSessionDescriptionObserver {
     public:
      Observer(OnSdpCreateSuccess s, OnSdpCreateFailure f)
          : success_(s), failure_(f) {}
      void OnSuccess(webrtc::SessionDescriptionInterface* desc) override {
        std::string sdp_str, type_str;
        if (desc) {
          desc->ToString(&sdp_str);
          type_str = webrtc::SdpTypeToString(desc->GetType());
        }
        portable::string sp, tp;
        sp.init(sdp_str.data(), sdp_str.size());
        tp.init(type_str.data(), type_str.size());
        success_(sp, tp);
      }
      void OnFailure(webrtc::RTCError error) override {
        portable::string err;
        std::string msg = error.message();
        err.init(msg.data(), msg.size());
        failure_(err.c_string());
      }
     protected:
      ~Observer() override = default;
     private:
      OnSdpCreateSuccess success_;
      OnSdpCreateFailure failure_;
    };
    webrtc::PeerConnectionInterface::RTCOfferAnswerOptions options;
    pc_->CreateOffer(new webrtc::RefCountedObject<Observer>(success, failure),
                     options);
  }

  void CreateAnswer(OnSdpCreateSuccess success,
                    OnSdpCreateFailure failure,
                    scoped_refptr<RTCMediaConstraints> constraints) override {
    class Observer : public webrtc::CreateSessionDescriptionObserver {
     public:
      Observer(OnSdpCreateSuccess s, OnSdpCreateFailure f)
          : success_(s), failure_(f) {}
      void OnSuccess(webrtc::SessionDescriptionInterface* desc) override {
        std::string sdp_str, type_str;
        if (desc) {
          desc->ToString(&sdp_str);
          type_str = webrtc::SdpTypeToString(desc->GetType());
        }
        portable::string sp, tp;
        sp.init(sdp_str.data(), sdp_str.size());
        tp.init(type_str.data(), type_str.size());
        success_(sp, tp);
      }
      void OnFailure(webrtc::RTCError error) override {
        portable::string err;
        std::string msg = error.message();
        err.init(msg.data(), msg.size());
        failure_(err.c_string());
      }
     protected:
      ~Observer() override = default;
     private:
      OnSdpCreateSuccess success_;
      OnSdpCreateFailure failure_;
    };
    webrtc::PeerConnectionInterface::RTCOfferAnswerOptions options;
    pc_->CreateAnswer(new webrtc::RefCountedObject<Observer>(success, failure),
                      options);
  }

  void RestartIce() override { pc_->RestartIce(); }

  void Close() override { pc_->Close(); }

  void SetLocalDescription(const string sdp, const string type,
                             OnSetSdpSuccess success,
                             OnSetSdpFailure failure) override {
    class Observer : public webrtc::SetSessionDescriptionObserver {
     public:
      Observer(OnSetSdpSuccess s, OnSetSdpFailure f)
          : success_(s), failure_(f) {}
      void OnSuccess() override { success_(); }
      void OnFailure(webrtc::RTCError error) override {
        std::string msg = error.message();
        portable::string err;
        err.init(msg.data(), msg.size());
        failure_(err.c_string());
      }
     protected:
      ~Observer() override = default;
     private:
      OnSetSdpSuccess success_;
      OnSetSdpFailure failure_;
    };
    webrtc::SdpParseError error;
    auto sdp_type = webrtc::SdpTypeFromString(type.std_string());
    if (!sdp_type.has_value()) {
      portable::string err;
      std::string msg = "Unknown SDP type: " + type.std_string();
      err.init(msg.data(), msg.size());
      failure(err.c_string());
      return;
    }
    auto desc = webrtc::CreateSessionDescription(*sdp_type, sdp.std_string(), &error);
    if (!desc) {
      portable::string err;
      err.init(error.description.data(), error.description.size());
      failure(err.c_string());
      return;
    }
    pc_->SetLocalDescription(
        new webrtc::RefCountedObject<Observer>(success, failure),
        desc.release());
  }

  void SetRemoteDescription(const string sdp, const string type,
                              OnSetSdpSuccess success,
                              OnSetSdpFailure failure) override {
    class Observer : public webrtc::SetSessionDescriptionObserver {
     public:
      Observer(OnSetSdpSuccess s, OnSetSdpFailure f)
          : success_(s), failure_(f) {}
      void OnSuccess() override { success_(); }
      void OnFailure(webrtc::RTCError error) override {
        std::string msg = error.message();
        portable::string err;
        err.init(msg.data(), msg.size());
        failure_(err.c_string());
      }
     protected:
      ~Observer() override = default;
     private:
      OnSetSdpSuccess success_;
      OnSetSdpFailure failure_;
    };
    webrtc::SdpParseError error;
    auto sdp_type = webrtc::SdpTypeFromString(type.std_string());
    if (!sdp_type.has_value()) {
      portable::string err;
      std::string msg = "Unknown SDP type: " + type.std_string();
      err.init(msg.data(), msg.size());
      failure(err.c_string());
      return;
    }
    auto desc = webrtc::CreateSessionDescription(*sdp_type, sdp.std_string(), &error);
    if (!desc) {
      portable::string err;
      err.init(error.description.data(), error.description.size());
      failure(err.c_string());
      return;
    }
    pc_->SetRemoteDescription(
        new webrtc::RefCountedObject<Observer>(success, failure),
        desc.release());
  }

  void GetLocalDescription(OnGetSdpSuccess success,
                            OnGetSdpFailure failure) override {
    auto desc = pc_->local_description();
    if (desc) {
      std::string sdp_str, type_str;
      desc->ToString(&sdp_str);
      type_str = desc->type();
      portable::string s, t;
      s.init(sdp_str.data(), sdp_str.size());
      t.init(type_str.data(), type_str.size());
      portable::string cs, ct;
      cs = s; ct = t;
      success(cs.c_string(), ct.c_string());
    }
  }

  void GetRemoteDescription(OnGetSdpSuccess success,
                             OnGetSdpFailure failure) override {
    auto desc = pc_->remote_description();
    if (desc) {
      std::string sdp_str, type_str;
      desc->ToString(&sdp_str);
      type_str = desc->type();
      portable::string s, t;
      s.init(sdp_str.data(), sdp_str.size());
      t.init(type_str.data(), type_str.size());
      portable::string cs, ct;
      cs = s; ct = t;
      success(cs.c_string(), ct.c_string());
    }
  }

  void AddCandidate(const string mid, int mid_mline_index,
                     const string candidate) override {
    webrtc::SdpParseError error;
    auto ice_candidate = webrtc::CreateIceCandidate(
        mid.std_string(), mid_mline_index,
        candidate.std_string(), &error);
    if (ice_candidate) {
      pc_->AddIceCandidate(ice_candidate);
    }
  }

  void RegisterRTCPeerConnectionObserver(
      RTCPeerConnectionObserver* observer) override {
    observer_ = observer;
  }

  void DeRegisterRTCPeerConnectionObserver() override {
    observer_ = nullptr;
  }

  vector<scoped_refptr<RTCMediaStream>> local_streams() override {
    std::vector<scoped_refptr<RTCMediaStream>> tmp;
    for (auto& r : pc_->GetReceivers()) {
      for (auto& st : r->streams()) {
        tmp.push_back(new RefCountedObject<LinuxRTCMediaStream>(st));
      }
    }
    return vector<scoped_refptr<RTCMediaStream>>(tmp);
  }

  vector<scoped_refptr<RTCMediaStream>> remote_streams() override {
    std::vector<scoped_refptr<RTCMediaStream>> tmp;
    for (auto& r : pc_->GetReceivers()) {
      for (auto& st : r->streams()) {
        tmp.push_back(new RefCountedObject<LinuxRTCMediaStream>(st));
      }
    }
    return vector<scoped_refptr<RTCMediaStream>>(tmp);
  }

  bool GetStats(scoped_refptr<RTCRtpSender> sender,
                OnStatsCollectorSuccess success,
                OnStatsCollectorFailure failure) override { return false; }

  bool GetStats(scoped_refptr<RTCRtpReceiver> receiver,
                OnStatsCollectorSuccess success,
                OnStatsCollectorFailure failure) override { return false; }

  void GetStats(OnStatsCollectorSuccess success,
                OnStatsCollectorFailure failure) override {}

  scoped_refptr<RTCRtpTransceiver> AddTransceiver(
      scoped_refptr<RTCMediaTrack> track,
      scoped_refptr<RTCRtpTransceiverInit> init) override {
    webrtc::scoped_refptr<webrtc::MediaStreamTrackInterface> webrtc_track;
    if (auto* vt = static_cast<LinuxRTCVideoTrack*>(track.get()))
      webrtc_track = vt->webrtc_track();
    else if (auto* at = static_cast<LinuxRTCAudioTrack*>(track.get()))
      webrtc_track = at->webrtc_track();

    webrtc::RtpTransceiverInit rtc_init;
    auto result = pc_->AddTransceiver(webrtc_track, rtc_init);
    if (result.ok()) {
      return new RefCountedObject<LinuxRTCRtpTransceiver>(result.MoveValue());
    }
    return nullptr;
  }

  scoped_refptr<RTCRtpTransceiver> AddTransceiver(
      scoped_refptr<RTCMediaTrack> track) override {
    webrtc::RtpTransceiverInit init;
    auto result = pc_->AddTransceiver(
        static_cast<LinuxRTCVideoTrack*>(track.get())->webrtc_track(), init);
    if (result.ok())
      return new RefCountedObject<LinuxRTCRtpTransceiver>(result.MoveValue());
    return nullptr;
  }

  scoped_refptr<RTCRtpSender> AddTrack(
      scoped_refptr<RTCMediaTrack> track,
      const vector<string> streamIds) override {
    webrtc::scoped_refptr<webrtc::MediaStreamTrackInterface> webrtc_track;
    std::vector<std::string> ids;
    std::vector<std::string> tmp_ids;
    for (size_t i = 0; i < streamIds.size(); i++)
      tmp_ids.push_back(streamIds[i].std_string());
    ids = std::move(tmp_ids);

    if (auto* vt = static_cast<LinuxRTCVideoTrack*>(track.get()))
      webrtc_track = vt->webrtc_track();
    else if (auto* at = static_cast<LinuxRTCAudioTrack*>(track.get()))
      webrtc_track = at->webrtc_track();

    auto result = pc_->AddTrack(webrtc_track, ids);
    if (result.ok())
      return new RefCountedObject<LinuxRTCRtpSender>(result.MoveValue());
    return nullptr;
  }

  scoped_refptr<RTCRtpTransceiver> AddTransceiver(
      RTCMediaType media_type) override {
    auto result = pc_->AddTransceiver(
        static_cast<webrtc::MediaType>(media_type));
    if (result.ok())
      return new RefCountedObject<LinuxRTCRtpTransceiver>(result.MoveValue());
    return nullptr;
  }

  scoped_refptr<RTCRtpTransceiver> AddTransceiver(
      RTCMediaType media_type,
      scoped_refptr<RTCRtpTransceiverInit> init) override {
    webrtc::RtpTransceiverInit rtc_init;
    auto result = pc_->AddTransceiver(
        static_cast<webrtc::MediaType>(media_type), rtc_init);
    if (result.ok())
      return new RefCountedObject<LinuxRTCRtpTransceiver>(result.MoveValue());
    return nullptr;
  }

  bool RemoveTrack(scoped_refptr<RTCRtpSender> render) override {
    auto* linux_sender = static_cast<LinuxRTCRtpSender*>(render.get());
    if (!linux_sender) return false;
    auto result = pc_->RemoveTrackOrError(
        linux_sender->webrtc_sender());
    return result.ok();
  }

  vector<scoped_refptr<RTCRtpSender>> senders() override {
    std::vector<scoped_refptr<RTCRtpSender>> tmp;
    for (auto& s : pc_->GetSenders())
      tmp.push_back(new RefCountedObject<LinuxRTCRtpSender>(s));
    return vector<scoped_refptr<RTCRtpSender>>(tmp);
  }

  vector<scoped_refptr<RTCRtpTransceiver>> transceivers() override {
    std::vector<scoped_refptr<RTCRtpTransceiver>> tmp;
    for (auto& t : pc_->GetTransceivers())
      tmp.push_back(new RefCountedObject<LinuxRTCRtpTransceiver>(t));
    return vector<scoped_refptr<RTCRtpTransceiver>>(tmp);
  }

  vector<scoped_refptr<RTCRtpReceiver>> receivers() override {
    std::vector<scoped_refptr<RTCRtpReceiver>> tmp;
    for (auto& r : pc_->GetReceivers())
      tmp.push_back(new RefCountedObject<LinuxRTCRtpReceiver>(r));
    return vector<scoped_refptr<RTCRtpReceiver>>(tmp);
  }

  RTCSignalingState signaling_state() override {
    return static_cast<RTCSignalingState>(pc_->signaling_state());
  }

  RTCIceConnectionState ice_connection_state() override {
    return static_cast<RTCIceConnectionState>(pc_->ice_connection_state());
  }

  RTCIceConnectionState standardized_ice_connection_state() override {
    return static_cast<RTCIceConnectionState>(
        pc_->standardized_ice_connection_state());
  }

  RTCPeerConnectionState peer_connection_state() override {
    return static_cast<RTCPeerConnectionState>(pc_->peer_connection_state());
  }

  RTCIceGatheringState ice_gathering_state() override {
    return static_cast<RTCIceGatheringState>(pc_->ice_gathering_state());
  }

 private:
  webrtc::scoped_refptr<webrtc::PeerConnectionInterface> pc_;
  webrtc::scoped_refptr<webrtc::PeerConnectionFactoryInterface> pcf_;
  RTCPeerConnectionObserver* observer_ = nullptr;
  std::unique_ptr<ProxyObserver> proxy_observer_;
};

// ============================================================================
// Stub classes for device/capability types
// ============================================================================

class RTCAudioDeviceStub : public RefCountedObject<RTCAudioDevice> {
 public:
  int16_t PlayoutDevices() override { return 0; }
  int16_t RecordingDevices() override { return 0; }
  int32_t PlayoutDeviceName(uint16_t, char[128], char[128]) override { return -1; }
  int32_t RecordingDeviceName(uint16_t, char[128], char[128]) override { return -1; }
  int32_t SetPlayoutDevice(uint16_t) override { return -1; }
  int32_t SetRecordingDevice(uint16_t) override { return -1; }
  int32_t OnDeviceChange(OnDeviceChangeCallback) override { return -1; }
  int32_t SetMicrophoneVolume(uint32_t) override { return -1; }
  int32_t MicrophoneVolume(uint32_t& v) override { v = 0; return -1; }
  int32_t SetSpeakerVolume(uint32_t) override { return -1; }
  int32_t SpeakerVolume(uint32_t& v) override { v = 0; return -1; }
};

class RTCVideoDeviceStub : public RefCountedObject<RTCVideoDevice> {
 public:
  uint32_t NumberOfDevices() override { return 0; }
  int32_t GetDeviceName(uint32_t, char*, uint32_t, char*, uint32_t, char*, uint32_t) override { return -1; }
  scoped_refptr<RTCVideoCapturer> Create(const char*, uint32_t, size_t, size_t, size_t) override { return nullptr; }
};

class RTCAudioProcessingStub : public RefCountedObject<RTCAudioProcessing> {
 public:
  void SetCapturePostProcessing(CustomProcessing*) override {}
  void SetRenderPreProcessing(CustomProcessing*) override {}
};

class RTCDesktopDeviceStub : public RefCountedObject<RTCDesktopDevice> {
 public:
  scoped_refptr<RTCDesktopCapturer> CreateDesktopCapturer(
      scoped_refptr<MediaSource>, bool) override { return nullptr; }
  scoped_refptr<RTCDesktopMediaList> GetDesktopMediaList(DesktopType) override { return nullptr; }
};

class RTCRtpCapabilitiesStub : public RefCountedObject<RTCRtpCapabilities> {
  vector<scoped_refptr<RTCRtpCodecCapability>> empty_codecs_;
  vector<scoped_refptr<RTCRtpHeaderExtensionCapability>> empty_extensions_;
 public:
  const vector<scoped_refptr<RTCRtpCodecCapability>> codecs() override { return empty_codecs_; }
  void set_codecs(const vector<scoped_refptr<RTCRtpCodecCapability>> c) override { empty_codecs_ = c; }
  const vector<scoped_refptr<RTCRtpHeaderExtensionCapability>> header_extensions() override { return empty_extensions_; }
  void set_header_extensions(const vector<scoped_refptr<RTCRtpHeaderExtensionCapability>> h) override { empty_extensions_ = h; }
};

class StubFactory : public RefCountedObject<RTCPeerConnectionFactory> {
 public:
  bool Initialize() override { return true; }
  bool Terminate() override { return true; }
  scoped_refptr<RTCPeerConnection> Create(
      const RTCConfiguration&,
      scoped_refptr<RTCMediaConstraints>) override { return nullptr; }
  void Delete(scoped_refptr<RTCPeerConnection>) override {}
  scoped_refptr<RTCAudioDevice> GetAudioDevice() override {
    return new RefCountedObject<RTCAudioDeviceStub>();
  }
  scoped_refptr<RTCAudioProcessing> GetAudioProcessing() override {
    return new RefCountedObject<RTCAudioProcessingStub>();
  }
  scoped_refptr<RTCVideoDevice> GetVideoDevice() override {
    return new RefCountedObject<RTCVideoDeviceStub>();
  }
  scoped_refptr<RTCDesktopDevice> GetDesktopDevice() override {
    return new RefCountedObject<RTCDesktopDeviceStub>();
  }
  scoped_refptr<RTCAudioSource> CreateAudioSource(
      const string, RTCAudioSource::SourceType,
      RTCAudioOptions) override { return nullptr; }
  scoped_refptr<RTCVideoSource> CreateVideoSource(
      scoped_refptr<RTCVideoCapturer>, const string,
      scoped_refptr<RTCMediaConstraints>) override { return nullptr; }
  scoped_refptr<RTCVideoSource> CreateCustomVideoSource(
      const string, scoped_refptr<RTCMediaConstraints>) override { return nullptr; }
  scoped_refptr<RTCVideoSource> CreateDesktopSource(
      scoped_refptr<RTCDesktopCapturer>, const string,
      scoped_refptr<RTCMediaConstraints>) override { return nullptr; }
  scoped_refptr<RTCAudioTrack> CreateAudioTrack(
      scoped_refptr<RTCAudioSource>, const string) override { return nullptr; }
  scoped_refptr<RTCVideoTrack> CreateVideoTrack(
      scoped_refptr<RTCVideoSource>, const string) override { return nullptr; }
  scoped_refptr<RTCMediaStream> CreateStream(const string) override { return nullptr; }
  scoped_refptr<RTCRtpCapabilities> GetRtpSenderCapabilities(
      RTCMediaType) override {
    return new RefCountedObject<RTCRtpCapabilitiesStub>();
  }
  scoped_refptr<RTCRtpCapabilities> GetRtpReceiverCapabilities(
      RTCMediaType) override {
    return new RefCountedObject<RTCRtpCapabilitiesStub>();
  }
};

// ============================================================================
// LinuxPeerConnectionFactory — implements RTCPeerConnectionFactory
// ============================================================================

class LinuxPeerConnectionFactory
    : public RefCountedObject<RTCPeerConnectionFactory> {
 public:
  LinuxPeerConnectionFactory(
      webrtc::scoped_refptr<webrtc::PeerConnectionFactoryInterface> pcf,
      webrtc::scoped_refptr<webrtc::AudioDeviceModule> adm)
      : pcf_(std::move(pcf)), adm_(std::move(adm)) {}

  bool Initialize() override { return true; }
  bool Terminate() override { return true; }

  scoped_refptr<RTCPeerConnection> Create(
      const RTCConfiguration& config,
      scoped_refptr<RTCMediaConstraints> constraints) override {
    webrtc::PeerConnectionInterface::RTCConfiguration rtc_config;
    rtc_config.sdp_semantics = webrtc::SdpSemantics::kUnifiedPlan;
    // Copy ICE servers from config (fixed-size C array)
    for (size_t i = 0; i < kMaxIceServerSize; i++) {
      std::string uri = config.ice_servers[i].uri.std_string();
      if (uri.empty()) continue;
      webrtc::PeerConnectionInterface::IceServer server;
      server.uri = uri;
      rtc_config.servers.push_back(server);
    }
    rtc_config.type = webrtc::PeerConnectionInterface::kAll;

    // Create proxy observer — delegate set later via RegisterRTCPeerConnectionObserver
    auto proxy = std::make_unique<
        LinuxRTCPeerConnection::ProxyObserver>();
    webrtc::PeerConnectionDependencies deps(proxy.get());
    auto result = pcf_->CreatePeerConnectionOrError(
        rtc_config, std::move(deps));
    if (result.ok()) {
      return new RefCountedObject<LinuxRTCPeerConnection>(
          result.MoveValue(), pcf_, std::move(proxy));
    }
    return nullptr;
  }

  void Delete(scoped_refptr<RTCPeerConnection> pc) override {}

  scoped_refptr<RTCAudioDevice> GetAudioDevice() override {
    return new RefCountedObject<RTCAudioDeviceStub>();
  }

  scoped_refptr<RTCAudioProcessing> GetAudioProcessing() override {
    return new RefCountedObject<RTCAudioProcessingStub>();
  }

  scoped_refptr<RTCVideoDevice> GetVideoDevice() override {
    return new RefCountedObject<RTCVideoDeviceStub>();
  }

  scoped_refptr<RTCDesktopDevice> GetDesktopDevice() override {
    return new RefCountedObject<RTCDesktopDeviceStub>();
  }

  scoped_refptr<RTCAudioSource> CreateAudioSource(
      const string label, RTCAudioSource::SourceType source_type,
      RTCAudioOptions options) override {
    return nullptr;
  }

  scoped_refptr<RTCVideoSource> CreateVideoSource(
      scoped_refptr<RTCVideoCapturer> capturer, const string label,
      scoped_refptr<RTCMediaConstraints> constraints) override {
    return nullptr;
  }

  scoped_refptr<RTCVideoSource> CreateCustomVideoSource(
      const string label,
      scoped_refptr<RTCMediaConstraints> constraints) override {
    return new RefCountedObject<LinuxRTCVideoSource>();
  }

  scoped_refptr<RTCVideoSource> CreateDesktopSource(
      scoped_refptr<RTCDesktopCapturer> capturer,
      const string label,
      scoped_refptr<RTCMediaConstraints> constraints) override {
    return nullptr;
  }

  scoped_refptr<RTCAudioTrack> CreateAudioTrack(
      scoped_refptr<RTCAudioSource> source,
      const string track_id) override {
    return nullptr;
  }

  scoped_refptr<RTCVideoTrack> CreateVideoTrack(
      scoped_refptr<RTCVideoSource> source,
      const string track_id) override {
    auto* linux_source = static_cast<LinuxRTCVideoSource*>(source.get());
    if (!linux_source) return nullptr;
    auto webrtc_track = pcf_->CreateVideoTrack(
        linux_source->webrtc_source(), track_id.std_string());
    if (!webrtc_track) return nullptr;
    return new RefCountedObject<LinuxRTCVideoTrack>(webrtc_track);
  }

  scoped_refptr<RTCMediaStream> CreateStream(
      const string stream_id) override {
    auto stream = pcf_->CreateLocalMediaStream(stream_id.std_string());
    if (!stream) return nullptr;
    return new RefCountedObject<LinuxRTCMediaStream>(stream);
  }

  scoped_refptr<RTCRtpCapabilities> GetRtpSenderCapabilities(
      RTCMediaType media_type) override {
    return new RefCountedObject<RTCRtpCapabilitiesStub>();
  }

  scoped_refptr<RTCRtpCapabilities> GetRtpReceiverCapabilities(
      RTCMediaType media_type) override {
    return new RefCountedObject<RTCRtpCapabilitiesStub>();
  }

 private:
  webrtc::scoped_refptr<webrtc::PeerConnectionFactoryInterface> pcf_;
  webrtc::scoped_refptr<webrtc::AudioDeviceModule> adm_;
};

// ============================================================================
// LibWebRTC entry point — replaces the StubFactory on Linux
// ============================================================================

scoped_refptr<RTCPeerConnectionFactory>
LibWebRTC::CreateRTCPeerConnectionFactory() {
  auto env = webrtc::CreateEnvironment();

  auto adm = webrtc::CreateAudioDeviceModule(
      env, webrtc::AudioDeviceModule::kPlatformDefaultAudio);
  if (!adm) {
    // ADM creation failed — return stub factory for basic operation
    return new RefCountedObject<StubFactory>();
  }

  auto audio_encoder = webrtc::CreateBuiltinAudioEncoderFactory();
  auto audio_decoder = webrtc::CreateBuiltinAudioDecoderFactory();
  auto video_encoder = webrtc::CreateBuiltinVideoEncoderFactory();
  auto video_decoder = webrtc::CreateBuiltinVideoDecoderFactory();
  auto audio_mixer = webrtc::AudioMixerImpl::Create();
  auto audio_processing =
      webrtc::BuiltinAudioProcessingBuilder().Build(env);

  auto pcf = webrtc::CreatePeerConnectionFactory(
      nullptr, nullptr, nullptr,
      adm, audio_encoder, audio_decoder,
      std::move(video_encoder), std::move(video_decoder),
      audio_mixer, audio_processing);

  if (!pcf) {
    return new RefCountedObject<StubFactory>();
  }

  return new LinuxPeerConnectionFactory(pcf, adm);
}

}  // namespace libwebrtc
