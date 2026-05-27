// Stub definitions for symbols declared in libwebrtc headers
// but not defined in libwebrtc.a (crow-misia/libwebrtc-bin 144.7559.3.0).
// Without these the dynamic linker reports undefined symbol at runtime.
// The raw webrtc:: symbols ARE present in the .a; the libwebrtc:: wrapper
// layer is not. These stubs satisfy the linker so the app can start.
// Features that hit a nullptr stub will return errors to Dart.

#include <cstring>
#include <cstdlib>
#include <string>

#include "base/portable.h"
#include "base/refcountedobject.h"
#include "rtc_mediaconstraints.h"
#include "rtc_session_description.h"
#include "rtc_ice_candidate.h"
#include "rtc_frame_cryptor.h"
#include "rtc_data_packet_cryptor.h"
#include "rtc_rtp_transceiver.h"
#include "rtc_rtp_parameters.h"
#include "rtc_rtp_capabilities.h"
#include "rtc_logging.h"
#include "helper.h"
#include "libwebrtc.h"
#include "rtc_audio_device.h"
#include "rtc_audio_processing.h"
#include "rtc_video_device.h"
#include "rtc_desktop_device.h"
#include "rtc_peerconnection.h"
#include "rtc_desktop_capturer.h"
#include "rtc_desktop_media_list.h"

// ---- portable::string implementation ----

namespace portable {

string::string() : m_dynamic(0), m_length(0) { m_buf[0] = 0; }

void string::init(const char* str, size_t len) {
  if (m_dynamic) {
    delete[] m_dynamic;
    m_dynamic = 0;
  }
  m_length = len;
  if (len >= PORTABLE_STRING_BUF_SIZE) {
    m_dynamic = new char[len + 1];
    std::memcpy(m_dynamic, str, len);
    m_dynamic[len] = 0;
  } else {
    std::memcpy(m_buf, str, len);
    m_buf[len] = 0;
  }
}

void string::destroy() {
  if (m_dynamic) {
    delete[] m_dynamic;
    m_dynamic = 0;
  }
  m_length = 0;
}

string::~string() { destroy(); }

}  // namespace portable

// ---- Concrete stub implementations ----

namespace libwebrtc {

// ---- RTCMediaConstraints static data ----

const char* RTCMediaConstraints::kValueTrue  = "true";
const char* RTCMediaConstraints::kValueFalse = "false";

// Other RTCMediaConstraints const char* statics — declared in the header
// with LIB_WEBRTC_API but never referenced from the flutter_webrtc .cc files
// on Linux, so they don't cause linker errors. Only kValueTrue/kValueFalse
// are needed.

// ---- RTCMediaConstraints stub ----

class RTCMediaConstraintsStub : public RefCountedObject<RTCMediaConstraints> {
 public:
  void AddMandatoryConstraint(const string key, const string value) override {}
  void AddOptionalConstraint(const string key, const string value) override {}
};

scoped_refptr<RTCMediaConstraints> RTCMediaConstraints::Create() {
  return new RefCountedObject<RTCMediaConstraintsStub>();
}

// ---- RTCSessionDescription stub ----

class RTCSessionDescriptionStub
    : public RefCountedObject<RTCSessionDescription> {
  string sdp_;
  string type_;
  SdpType sdp_type_;

 public:
  RTCSessionDescriptionStub(const string& type, const string& sdp)
      : sdp_(sdp), type_(type) {
    if (type_.std_string() == "offer") sdp_type_ = kOffer;
    else if (type_.std_string() == "pranswer") sdp_type_ = kPrAnswer;
    else sdp_type_ = kAnswer;
  }
  const string sdp() const override { return sdp_; }
  const string type() override { return type_; }
  SdpType GetType() override { return sdp_type_; }
  bool ToString(string& out) override { out = sdp_; return true; }
};

scoped_refptr<RTCSessionDescription> RTCSessionDescription::Create(
    const string type, const string sdp, SdpParseError* error) {
  return new RefCountedObject<RTCSessionDescriptionStub>(type, sdp);
}

// ---- RTCIceCandidate stub ----

class RTCIceCandidateStub : public RefCountedObject<RTCIceCandidate> {
  string sdp_;
  string sdp_mid_;
  int sdp_mline_index_;

 public:
  RTCIceCandidateStub(const string& sdp, const string& mid, int idx)
      : sdp_(sdp), sdp_mid_(mid), sdp_mline_index_(idx) {}
  const string candidate() const override { return sdp_; }
  const string sdp_mid() const override { return sdp_mid_; }
  int sdp_mline_index() const override { return sdp_mline_index_; }
  bool ToString(string& out) override { out = sdp_; return true; }
};

scoped_refptr<RTCIceCandidate> RTCIceCandidate::Create(
    const string sdp, const string sdp_mid, int sdp_mline_index,
    SdpParseError* error) {
  return new RefCountedObject<RTCIceCandidateStub>(sdp, sdp_mid,
                                                    sdp_mline_index);
}

// ---- EncryptedPacket stub ----

class EncryptedPacketStub : public RefCountedObject<EncryptedPacket> {
  vector<uint8_t> data_;
  vector<uint8_t> iv_;
  uint8_t key_index_;

 public:
  EncryptedPacketStub(vector<uint8_t> d, vector<uint8_t> i, uint8_t ki)
      : data_(d), iv_(i), key_index_(ki) {}
  vector<uint8_t> data() override { return data_; }
  vector<uint8_t> iv() override { return iv_; }
  uint8_t key_index() override { return key_index_; }
};

scoped_refptr<EncryptedPacket> EncryptedPacket::Create(
    vector<uint8_t> data, vector<uint8_t> iv, uint8_t key_index) {
  return new RefCountedObject<EncryptedPacketStub>(
      std::move(data), std::move(iv), key_index);
}

// ---- RTCDataPacketCryptor stub ----

class RTCDataPacketCryptorStub
    : public RefCountedObject<RTCDataPacketCryptor> {
 public:
  scoped_refptr<EncryptedPacket> encrypt(
      string, int, vector<uint8_t> data) override {
    return nullptr;
  }
  vector<uint8_t> decrypt(
      string, int, scoped_refptr<EncryptedPacket>) override {
    return vector<uint8_t>();
  }
};

scoped_refptr<RTCDataPacketCryptor> RTCDataPacketCryptor::Create(
    scoped_refptr<KeyProvider>, FrameCryptorAlgorithm) {
  return new RefCountedObject<RTCDataPacketCryptorStub>();
}

// ---- KeyProvider stub ----

scoped_refptr<KeyProvider> KeyProvider::Create(KeyProviderOptions*) {
  return nullptr;
}

// ---- FrameCryptorFactory stubs ----

scoped_refptr<RTCFrameCryptor>
FrameCryptorFactory::frameCryptorFromRtpSender(
    scoped_refptr<RTCPeerConnectionFactory>, const string,
    scoped_refptr<RTCRtpSender>, FrameCryptorAlgorithm,
    scoped_refptr<KeyProvider>) {
  return nullptr;
}

scoped_refptr<RTCFrameCryptor>
FrameCryptorFactory::frameCryptorFromRtpReceiver(
    scoped_refptr<RTCPeerConnectionFactory>, const string,
    scoped_refptr<RTCRtpReceiver>, FrameCryptorAlgorithm,
    scoped_refptr<KeyProvider>) {
  return nullptr;
}

// ---- RTCRtpTransceiverInit stub ----

class RTCRtpTransceiverInitStub
    : public RefCountedObject<RTCRtpTransceiverInit> {
  RTCRtpTransceiverDirection direction_;
  vector<string> stream_ids_;
  vector<scoped_refptr<RTCRtpEncodingParameters>> send_encodings_;

 public:
  explicit RTCRtpTransceiverInitStub(
      RTCRtpTransceiverDirection dir, const vector<string>& sids,
      const vector<scoped_refptr<RTCRtpEncodingParameters>>& encs)
      : direction_(dir), stream_ids_(sids), send_encodings_(encs) {}
  RTCRtpTransceiverDirection direction() override { return direction_; }
  void set_direction(RTCRtpTransceiverDirection v) override { direction_ = v; }
  const vector<string> stream_ids() override { return stream_ids_; }
  void set_stream_ids(const vector<string> ids) override { stream_ids_ = ids; }
  const vector<scoped_refptr<RTCRtpEncodingParameters>> send_encodings()
      override { return send_encodings_; }
  void set_send_encodings(
      const vector<scoped_refptr<RTCRtpEncodingParameters>> encs) override {
    send_encodings_ = encs;
  }
};

scoped_refptr<RTCRtpTransceiverInit> RTCRtpTransceiverInit::Create(
    RTCRtpTransceiverDirection direction, const vector<string> stream_ids,
    const vector<scoped_refptr<RTCRtpEncodingParameters>> encodings) {
  return new RefCountedObject<RTCRtpTransceiverInitStub>(
      direction, stream_ids, encodings);
}

// ---- RTCRtpEncodingParameters stub ----

class RTCRtpEncodingParametersStub
    : public RefCountedObject<RTCRtpEncodingParameters> {
  uint32_t ssrc_ = 0;
  double bitrate_priority_ = 1.0;
  RTCPriority network_priority_ = RTCPriority::kLow;
  int max_bitrate_bps_ = 0;
  int min_bitrate_bps_ = 0;
  double max_framerate_ = 0;
  int num_temporal_layers_ = 0;
  double scale_resolution_down_by_ = 1.0;
  string scalability_mode_;
  bool active_ = true;
  string rid_;
  bool adaptive_ptime_ = false;

 public:
  uint32_t ssrc() override { return ssrc_; }
  void set_ssrc(uint32_t v) override { ssrc_ = v; }
  double bitrate_priority() override { return bitrate_priority_; }
  void set_bitrate_priority(double v) override { bitrate_priority_ = v; }
  RTCPriority network_priority() override { return network_priority_; }
  void set_network_priority(RTCPriority v) override { network_priority_ = v; }
  int max_bitrate_bps() override { return max_bitrate_bps_; }
  void set_max_bitrate_bps(int v) override { max_bitrate_bps_ = v; }
  int min_bitrate_bps() override { return min_bitrate_bps_; }
  void set_min_bitrate_bps(int v) override { min_bitrate_bps_ = v; }
  double max_framerate() override { return max_framerate_; }
  void set_max_framerate(double v) override { max_framerate_ = v; }
  int num_temporal_layers() override { return num_temporal_layers_; }
  void set_num_temporal_layers(int v) override { num_temporal_layers_ = v; }
  double scale_resolution_down_by() override { return scale_resolution_down_by_; }
  void set_scale_resolution_down_by(double v) override { scale_resolution_down_by_ = v; }
  const string scalability_mode() override { return scalability_mode_; }
  void set_scalability_mode(const string v) override { scalability_mode_ = v; }
  bool active() override { return active_; }
  void set_active(bool v) override { active_ = v; }
  const string rid() override { return rid_; }
  void set_rid(const string v) override { rid_ = v; }
  bool adaptive_ptime() override { return adaptive_ptime_; }
  void set_adaptive_ptime(bool v) override { adaptive_ptime_ = v; }
  bool operator==(scoped_refptr<RTCRtpEncodingParameters> o) const override {
    return this == o.get();
  }
  bool operator!=(scoped_refptr<RTCRtpEncodingParameters> o) const override {
    return this != o.get();
  }
};

scoped_refptr<RTCRtpEncodingParameters> RTCRtpEncodingParameters::Create() {
  return new RefCountedObject<RTCRtpEncodingParametersStub>();
}

// ---- RTCRtpCodecCapability stub ----

class RTCRtpCodecCapabilityStub
    : public RefCountedObject<RTCRtpCodecCapability> {
  string mime_type_;
  int clock_rate_ = 0;
  int channels_ = 1;
  string sdp_fmtp_line_;

 public:
  void set_mime_type(const string& v) override { mime_type_ = v; }
  void set_clock_rate(int v) override { clock_rate_ = v; }
  void set_channels(int v) override { channels_ = v; }
  void set_sdp_fmtp_line(const string& v) override { sdp_fmtp_line_ = v; }
  string mime_type() const override { return mime_type_; }
  int clock_rate() const override { return clock_rate_; }
  int channels() const override { return channels_; }
  string sdp_fmtp_line() const override { return sdp_fmtp_line_; }
};

scoped_refptr<RTCRtpCodecCapability> RTCRtpCodecCapability::Create() {
  return new RefCountedObject<RTCRtpCodecCapabilityStub>();
}

// ---- Device & capabilities stub classes ----

class RTCAudioDeviceStub : public RefCountedObject<RTCAudioDevice> {
 public:
  int16_t PlayoutDevices() override { return 0; }
  int16_t RecordingDevices() override { return 0; }
  int32_t PlayoutDeviceName(uint16_t, char name[128], char guid[128]) override { return -1; }
  int32_t RecordingDeviceName(uint16_t, char name[128], char guid[128]) override { return -1; }
  int32_t SetPlayoutDevice(uint16_t) override { return -1; }
  int32_t SetRecordingDevice(uint16_t) override { return -1; }
  int32_t OnDeviceChange(OnDeviceChangeCallback) override { return -1; }
  int32_t SetMicrophoneVolume(uint32_t) override { return -1; }
  int32_t MicrophoneVolume(uint32_t& volume) override { volume = 0; return -1; }
  int32_t SetSpeakerVolume(uint32_t) override { return -1; }
  int32_t SpeakerVolume(uint32_t& volume) override { volume = 0; return -1; }
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

// ---- LibWebRTC stubs ----

bool LibWebRTC::Initialize() { return true; }

#ifndef __linux__
scoped_refptr<RTCPeerConnectionFactory>
LibWebRTC::CreateRTCPeerConnectionFactory() {
  // Minimal stub for non-Linux platforms. On Linux the real factory in
  // linux_factory.cc provides a working LibWebRTC::CreateRTCPeerConnectionFactory
  // that uses raw webrtc:: APIs from libwebrtc.a.
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
  return new StubFactory();
}
#endif

void LibWebRTC::Terminate() {}

// ---- LibWebRTCLogging stubs ----

void LibWebRTCLogging::setMinDebugLogLevel(RTCLoggingSeverity) {}
void LibWebRTCLogging::setLogSink(RTCLoggingSeverity,
                                   RTCCallbackLoggerMessageHandler) {}
void LibWebRTCLogging::removeLogSink() {}

// ---- Helper stub ----

string Helper::CreateRandomUuid() {
  portable::string result;
  result.init("00000000-0000-0000-0000-000000000000", 36);
  return result;
}

}  // namespace libwebrtc
