import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../rust/api/network.dart' as network_api;

/// Default ICE servers (STUN only — used if no config injected).
final _defaultIceServers = {
  'iceServers': [
    {'urls': 'stun:relay.anonlisten.com:3478'},
    {'urls': 'stun:stun.cloudflare.com:3478'},
    {'urls': 'stun:stun.l.google.com:19302'},
  ],
};

/// Log to hollow_debug.log (visible in release builds).
void _log(String msg) {
  network_api.logFromDart(message: msg);
}

/// Manages a single voice RTCPeerConnection for 1:1 calls.
///
/// Separate from [WebRtcService] which handles data channel file transfers.
/// Voice has a different lifecycle: no idle timeout, no keepalive, no chunked
/// binary protocol. Created when a call starts, destroyed when it ends.
class VoiceService {
  final String localPeerId;

  /// ICE configuration (STUN + TURN). Updated by IceConfigProvider.
  Map<String, dynamic> iceServers;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _activePeerId;
  String? _activeCallId;
  bool _isMuted = false;

  /// ICE candidates received before the peer connection is ready.
  final List<RTCIceCandidate> _pendingCandidates = [];

  // Callbacks
  void Function(String peerId)? onConnected;
  void Function(String peerId)? onDisconnected;

  VoiceService({required this.localPeerId, Map<String, dynamic>? iceServers})
      : iceServers = iceServers ?? _defaultIceServers;

  bool get isMuted => _isMuted;
  bool get hasActiveCall => _pc != null;
  String? get activePeerId => _activePeerId;
  String? get activeCallId => _activeCallId;

  /// Start mic capture, create RTCPeerConnection, and generate an SDP offer.
  /// Returns the SDP offer string.
  Future<String> createOffer(String peerId, String callId) async {
    _log('[HOLLOW-VOICE] Creating offer for $peerId call=$callId');
    _activePeerId = peerId;
    _activeCallId = callId;

    await _initPeerConnection(peerId, callId);
    await _startLocalAudio();

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    _log('[HOLLOW-VOICE] Offer created, SDP length=${offer.sdp?.length}');
    return offer.sdp!;
  }

  /// Handle an incoming SDP offer (answerer side). Creates PC, starts mic,
  /// sets remote description, creates answer. Returns the SDP answer string.
  Future<String> handleOffer(String peerId, String callId, String sdp) async {
    _log('[HOLLOW-VOICE] Handling offer from $peerId call=$callId');
    _activePeerId = peerId;
    _activeCallId = callId;

    await _initPeerConnection(peerId, callId);
    await _startLocalAudio();

    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

    // Flush any ICE candidates that arrived before the PC was ready.
    await _flushPendingCandidates();

    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    _log('[HOLLOW-VOICE] Answer created, SDP length=${answer.sdp?.length}');
    return answer.sdp!;
  }

  /// Handle incoming SDP answer (offerer side).
  Future<void> handleAnswer(String sdp) async {
    if (_pc == null) {
      _log('[HOLLOW-VOICE] handleAnswer: no PC, ignoring');
      return;
    }
    _log('[HOLLOW-VOICE] Setting remote description (answer)');
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    await _flushPendingCandidates();
  }

  /// Handle incoming ICE candidate.
  Future<void> handleIceCandidate(
      String candidate, String? sdpMid, int? sdpMLineIndex) async {
    final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);

    if (_pc == null) {
      // Queue until peer connection is created.
      _pendingCandidates.add(iceCandidate);
      return;
    }

    try {
      await _pc!.addCandidate(iceCandidate);
    } catch (e) {
      _log('[HOLLOW-VOICE] Failed to add ICE candidate: $e');
    }
  }

  /// Toggle microphone mute.
  void toggleMute() {
    if (_localStream == null) return;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return;
    _isMuted = !_isMuted;
    audioTracks.first.enabled = !_isMuted;
    _log('[HOLLOW-VOICE] Mute toggled: $_isMuted');
  }

  /// End the current call. Closes PC, stops local audio.
  Future<void> endCall() async {
    _log('[HOLLOW-VOICE] Ending call with $_activePeerId');

    // Stop local audio tracks.
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    // Close peer connection.
    if (_pc != null) {
      await _pc!.close();
      await _pc!.dispose();
      _pc = null;
    }

    _pendingCandidates.clear();
    _activePeerId = null;
    _activeCallId = null;
    _isMuted = false;
  }

  /// Dispose everything (app shutdown).
  Future<void> dispose() async {
    await endCall();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _initPeerConnection(String peerId, String callId) async {
    // Clean up any existing connection.
    if (_pc != null) {
      await _pc!.close();
      await _pc!.dispose();
      _pc = null;
    }
    _pendingCandidates.clear();

    final pc = await createPeerConnection(iceServers);
    _pc = pc;

    // ICE candidate handler — send to peer via Rust relay.
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

    // Remote audio track handler — audio plays automatically via libwebrtc.
    pc.onTrack = (event) {
      _log(
          '[HOLLOW-VOICE] Remote track received: ${event.track.kind} id=${event.track.id}');
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

  Future<void> _startLocalAudio() async {
    final constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _log(
          '[HOLLOW-VOICE] Got local audio stream, tracks: ${_localStream!.getAudioTracks().length}');

      // Add audio tracks to peer connection.
      for (final track in _localStream!.getAudioTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    } catch (e) {
      _log('[HOLLOW-VOICE] Failed to get microphone: $e');
      rethrow;
    }
  }

  Future<void> _flushPendingCandidates() async {
    if (_pendingCandidates.isEmpty || _pc == null) return;
    _log(
        '[HOLLOW-VOICE] Flushing ${_pendingCandidates.length} pending ICE candidates');
    for (final candidate in _pendingCandidates) {
      try {
        await _pc!.addCandidate(candidate);
      } catch (e) {
        _log('[HOLLOW-VOICE] Failed to add queued ICE candidate: $e');
      }
    }
    _pendingCandidates.clear();
  }
}
