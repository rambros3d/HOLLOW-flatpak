import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../rust/api/network.dart' as network_api;

/// Log to hollow_debug.log (visible in release builds).
void _log(String msg) {
  network_api.logFromDart(message: msg);
}

/// Manages a dedicated voice/video RTCPeerConnection for 1:1 calls.
///
/// Separate from [WebRtcService] which handles data channel file transfers.
/// Voice has a different lifecycle: no idle timeout, no keepalive, no chunked
/// binary protocol. Created when a call starts, destroyed when it ends.
/// Each call gets its own ICE negotiation — this is critical for cross-internet
/// connectivity where the data channel's ICE path may not carry media.
class VoiceService {
  final String localPeerId;

  /// ICE configuration (STUN + TURN). Updated by CallNotifier.
  Map<String, dynamic> iceServers;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _activePeerId;
  String? _activeCallId;
  bool _isMuted = false;

  /// ICE candidates received before the peer connection is ready.
  final List<RTCIceCandidate> _pendingCandidates = [];

  // -- Video state --
  MediaStream? _localVideoStream;
  bool _isVideoEnabled = false;
  bool _useFrontCamera = true;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  MediaStream? _remoteStream;

  // Callbacks
  void Function(String peerId)? onConnected;
  void Function(String peerId)? onDisconnected;
  void Function(String peerId)? onRemoteVideoTrack;

  /// Preferred device IDs (set by CallNotifier from settings providers).
  String? preferredAudioInputDeviceId;
  String? preferredAudioOutputDeviceId;

  VoiceService({required this.localPeerId, Map<String, dynamic>? iceServers})
      : iceServers = iceServers ?? _defaultIceServers;

  bool get isMuted => _isMuted;
  bool get hasActiveCall => _pc != null;
  String? get activePeerId => _activePeerId;
  String? get activeCallId => _activeCallId;
  bool get isVideoEnabled => _isVideoEnabled;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;
  RTCPeerConnection? get peerConnection => _pc;

  // ---------------------------------------------------------------------------
  // SDP: offer / answer / ICE
  // ---------------------------------------------------------------------------

  /// Start mic capture, create RTCPeerConnection, and generate an SDP offer.
  /// Returns the SDP offer string.
  Future<String> createOffer(
    String peerId,
    String callId, {
    bool withVideo = false,
  }) async {
    _log('[HOLLOW-VOICE] Creating offer for $peerId call=$callId withVideo=$withVideo');
    _activePeerId = peerId;
    _activeCallId = callId;

    await _initPeerConnection(peerId, callId);
    await _startLocalAudio();
    if (withVideo) await _startCamera(_pc!);

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    _log('[HOLLOW-VOICE] Offer created, SDP length=${offer.sdp?.length}');
    _dumpSdp('OFFER-OUT', offer.sdp!);
    return offer.sdp!;
  }

  /// Handle an incoming SDP offer (answerer side). Creates PC, starts mic,
  /// sets remote description, creates answer. Returns the SDP answer string.
  Future<String> handleOffer(
    String peerId,
    String callId,
    String sdp, {
    bool withVideo = false,
  }) async {
    _log('[HOLLOW-VOICE] Handling offer from $peerId call=$callId');
    _activePeerId = peerId;
    _activeCallId = callId;

    _dumpSdp('OFFER-IN', sdp);

    await _initPeerConnection(peerId, callId);
    await _startLocalAudio();
    if (withVideo) await _startCamera(_pc!);

    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    await _flushPendingCandidates();

    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    _log('[HOLLOW-VOICE] Answer created, SDP length=${answer.sdp?.length}');
    _dumpSdp('ANSWER-OUT', answer.sdp!);
    return answer.sdp!;
  }

  /// Handle incoming SDP answer (offerer side).
  Future<void> handleAnswer(String sdp) async {
    if (_pc == null) {
      _log('[HOLLOW-VOICE] handleAnswer: no PC, ignoring');
      return;
    }
    _dumpSdp('ANSWER-IN', sdp);
    _log('[HOLLOW-VOICE] Setting remote description (answer)');
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    await _flushPendingCandidates();
  }

  /// Handle incoming ICE candidate.
  Future<void> handleIceCandidate(
      String candidate, String? sdpMid, int? sdpMLineIndex) async {
    final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);

    if (_pc == null) {
      _pendingCandidates.add(iceCandidate);
      return;
    }

    try {
      await _pc!.addCandidate(iceCandidate);
    } catch (e) {
      _log('[HOLLOW-VOICE] Failed to add ICE candidate: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Media controls
  // ---------------------------------------------------------------------------

  /// Toggle microphone mute.
  void toggleMute() {
    if (_localStream == null) return;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return;
    _isMuted = !_isMuted;
    audioTracks.first.enabled = !_isMuted;
    _log('[HOLLOW-VOICE] Mute toggled: $_isMuted');
  }

  /// Toggle camera on/off. Returns the new state.
  Future<bool> toggleVideo() async {
    if (_pc == null) return _isVideoEnabled;
    if (_isVideoEnabled) {
      await _stopCamera(_pc!);
    } else {
      await _startCamera(_pc!);
    }
    return _isVideoEnabled;
  }

  /// Switch front/back camera (mobile).
  Future<void> switchCamera() async {
    if (!_isVideoEnabled || _localVideoStream == null) return;
    final videoTracks = _localVideoStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;
    await Helper.switchCamera(videoTracks.first);
    _useFrontCamera = !_useFrontCamera;
    _log('[HOLLOW-VOICE] Camera switched, front=$_useFrontCamera');
  }

  /// End the current call — close PC, stop streams, dispose renderers.
  Future<void> endCall() async {
    _log('[HOLLOW-VOICE] Ending call with $_activePeerId');

    // Stop local audio.
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    // Stop local video.
    if (_localVideoStream != null) {
      for (final track in _localVideoStream!.getTracks()) {
        await track.stop();
      }
      await _localVideoStream!.dispose();
      _localVideoStream = null;
    }

    // Dispose renderers.
    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      await _localRenderer!.dispose();
      _localRenderer = null;
    }
    if (_remoteRenderer != null) {
      _remoteRenderer!.srcObject = null;
      await _remoteRenderer!.dispose();
      _remoteRenderer = null;
    }
    _remoteStream = null;

    // Close the dedicated voice peer connection.
    if (_pc != null) {
      await _pc!.close();
      await _pc!.dispose();
      _pc = null;
    }

    _pendingCandidates.clear();
    _activePeerId = null;
    _activeCallId = null;
    _isMuted = false;
    _isVideoEnabled = false;
    _useFrontCamera = true;
  }

  Future<void> dispose() async => endCall();

  // ---------------------------------------------------------------------------
  // Private — Peer connection
  // ---------------------------------------------------------------------------

  Future<void> _initPeerConnection(String peerId, String callId) async {
    if (_pc != null) {
      await _pc!.close();
      await _pc!.dispose();
      _pc = null;
    }
    _pendingCandidates.clear();

    final pc = await createPeerConnection(iceServers);
    _pc = pc;

    // ICE candidate handler — send to peer via call signaling.
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
      final payload = jsonEncode({
        'call_id': callId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
      network_api.callSendSignal(
        peerId: peerId,
        signalType: 'ice',
        payload: payload,
      );
    };

    // Remote track handler — audio auto-plays, video needs renderer.
    pc.onTrack = (event) {
      _log('[HOLLOW-VOICE] Remote track: ${event.track.kind} '
          'id=${event.track.id} streams=${event.streams.length}');

      if (event.track.kind == 'video') {
        _handleRemoteVideoTrack(peerId, event);
      }
      // Audio tracks are played automatically by libwebrtc — no renderer needed.
    };

    // Connection state handler.
    pc.onConnectionState = (state) {
      _log('[HOLLOW-VOICE] Connection state: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          onConnected?.call(peerId);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          onDisconnected?.call(peerId);
        default:
          break;
      }
    };
  }

  // ---------------------------------------------------------------------------
  // Private — Audio
  // ---------------------------------------------------------------------------

  Future<void> _startLocalAudio() async {
    final audioConstraints = <String, dynamic>{
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    };
    // flutter_webrtc on Windows uses 'sourceId' for input device selection
    // (not 'deviceId' — that selects output devices in GetUserAudio).
    if (preferredAudioInputDeviceId != null) {
      audioConstraints['optional'] = [
        {'sourceId': preferredAudioInputDeviceId}
      ];
      _log('[HOLLOW-VOICE] Requesting input device: $preferredAudioInputDeviceId');
    }

    final constraints = {
      'audio': audioConstraints,
      'video': false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      final audioTracks = _localStream!.getAudioTracks();
      _log('[HOLLOW-VOICE] Got local audio, '
          'tracks: ${audioTracks.length}'
          '${audioTracks.isNotEmpty ? ", label=${audioTracks.first.label}" : ""}');

      for (final track in audioTracks) {
        await _pc!.addTrack(track, _localStream!);
      }

      // Apply preferred output device if set.
      if (preferredAudioOutputDeviceId != null) {
        try {
          await Helper.selectAudioOutput(preferredAudioOutputDeviceId!);
          _log('[HOLLOW-VOICE] Audio output set to $preferredAudioOutputDeviceId');
        } catch (e) {
          _log('[HOLLOW-VOICE] Failed to set audio output: $e');
        }
      }
    } catch (e) {
      _log('[HOLLOW-VOICE] Failed to get microphone: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Private — Video
  // ---------------------------------------------------------------------------

  Future<void> _startCamera(RTCPeerConnection pc) async {
    _log('[HOLLOW-VOICE] Starting camera (front=$_useFrontCamera)');
    final constraints = {
      'audio': false,
      'video': {
        'facingMode': _useFrontCamera ? 'user' : 'environment',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
        'frameRate': {'ideal': 30},
      },
    };

    try {
      _localVideoStream = await navigator.mediaDevices.getUserMedia(constraints);
      final videoTrack = _localVideoStream!.getVideoTracks().first;
      _log('[HOLLOW-VOICE] Got camera track: ${videoTrack.id}');

      // Try to reuse an existing stopped video transceiver.
      bool reused = false;
      final transceivers = await pc.getTransceivers();
      for (final t in transceivers) {
        if (t.receiver.track?.kind == 'video' && t.sender.track == null) {
          await t.sender.replaceTrack(videoTrack);
          await t.setDirection(TransceiverDirection.SendRecv);
          _log('[HOLLOW-VOICE] Reused video transceiver mid=${t.mid}');
          reused = true;
          break;
        }
      }

      if (!reused) {
        await pc.addTrack(videoTrack, _localVideoStream!);
        _log('[HOLLOW-VOICE] Added new video track via addTrack');
      }

      _isVideoEnabled = true;
      await _initLocalRenderer();
    } catch (e) {
      _log('[HOLLOW-VOICE] Failed to start camera: $e');
      rethrow;
    }
  }

  Future<void> _stopCamera(RTCPeerConnection pc) async {
    _log('[HOLLOW-VOICE] Stopping camera');

    final transceivers = await pc.getTransceivers();
    for (final t in transceivers) {
      if (t.sender.track?.kind == 'video') {
        await t.sender.replaceTrack(null);
        await t.setDirection(TransceiverDirection.RecvOnly);
        _log('[HOLLOW-VOICE] Cleared video transceiver mid=${t.mid}');
        break;
      }
    }

    if (_localVideoStream != null) {
      for (final track in _localVideoStream!.getTracks()) {
        await track.stop();
      }
      await _localVideoStream!.dispose();
      _localVideoStream = null;
    }

    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      await _localRenderer!.dispose();
      _localRenderer = null;
    }

    _isVideoEnabled = false;
  }

  Future<void> _handleRemoteVideoTrack(
      String peerId, RTCTrackEvent event) async {
    if (event.streams.isNotEmpty) {
      _remoteStream = event.streams.first;
    } else {
      // Windows/libwebrtc may fire onTrack with streams=0.
      _remoteStream?.dispose();
      _remoteStream = await createLocalMediaStream(
        'remote-video-${event.track.id}',
      );
      _remoteStream!.addTrack(event.track);
      _log('[HOLLOW-VOICE] Created stream from onTrack video track');
    }
    await _initRemoteRenderer();
    onRemoteVideoTrack?.call(peerId);
  }

  Future<void> _initLocalRenderer() async {
    _localRenderer?.dispose();
    _localRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    _localRenderer!.srcObject = _localVideoStream;
    _log('[HOLLOW-VOICE] Local video renderer initialized');
  }

  Future<void> _initRemoteRenderer() async {
    _remoteRenderer?.dispose();
    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer!.initialize();
    _remoteRenderer!.srcObject = _remoteStream;
    _log('[HOLLOW-VOICE] Remote video renderer initialized');
  }

  // ---------------------------------------------------------------------------
  // Private — Helpers
  // ---------------------------------------------------------------------------

  Future<void> _flushPendingCandidates() async {
    if (_pendingCandidates.isEmpty || _pc == null) return;
    _log('[HOLLOW-VOICE] Flushing ${_pendingCandidates.length} pending ICE candidates');
    for (final candidate in _pendingCandidates) {
      try {
        await _pc!.addCandidate(candidate);
      } catch (e) {
        _log('[HOLLOW-VOICE] Failed to add queued ICE candidate: $e');
      }
    }
    _pendingCandidates.clear();
  }

  /// Dump key SDP lines for debugging.
  void _dumpSdp(String label, String sdp) {
    _log('[HOLLOW-SDP-DUMP] === $label (${sdp.length} bytes) ===');
    for (final line in sdp.split('\r\n')) {
      if (line.startsWith('m=') ||
          line.startsWith('a=sendrecv') ||
          line.startsWith('a=recvonly') ||
          line.startsWith('a=sendonly') ||
          line.startsWith('a=inactive') ||
          line.startsWith('a=ssrc:') ||
          line.startsWith('a=mid:') ||
          line.startsWith('a=msid:')) {
        _log('[HOLLOW-SDP-DUMP] $label: $line');
      }
    }
    _log('[HOLLOW-SDP-DUMP] === END $label ===');
  }
}

/// Default ICE servers (STUN only — used if no config injected).
final _defaultIceServers = {
  'iceServers': [
    {'urls': 'stun:relay.anonlisten.com:3478'},
    {'urls': 'stun:stun.cloudflare.com:3478'},
    {'urls': 'stun:stun.l.google.com:19302'},
  ],
};
