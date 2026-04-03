import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hollow/src/core/providers/ice_config_provider.dart';
import 'package:hollow/src/core/providers/identity_provider.dart';
import 'package:hollow/src/core/providers/settings_provider.dart';
import 'package:hollow/src/core/services/screen_share_service.dart';
import 'package:hollow/src/core/services/voice_service.dart';

import '../../rust/api/network.dart' as network_api;

/// Log to hollow_debug.log (visible in release builds).
void _callLog(String msg) {
  network_api.logFromDart(message: msg);
}

/// Status of the current call.
enum CallStatus { idle, ringing, connecting, active }

/// Direction of the call.
enum CallDirection { outgoing, incoming }

/// Immutable state for the current call.
class CallState {
  final CallStatus status;
  final String? peerId;
  final String? callId;
  final CallDirection? direction;
  final bool isMuted;
  final DateTime? startedAt;
  final bool isVideoEnabled;
  final bool remoteVideoEnabled;
  final bool isVideoCall;
  final bool isScreenSharing;
  final bool remoteScreenSharing;
  final String sframeKey; // hex-encoded 32-byte SFrame key for E2EE

  const CallState({
    this.status = CallStatus.idle,
    this.peerId,
    this.callId,
    this.direction,
    this.isMuted = false,
    this.startedAt,
    this.isVideoEnabled = false,
    this.remoteVideoEnabled = false,
    this.isVideoCall = false,
    this.isScreenSharing = false,
    this.remoteScreenSharing = false,
    this.sframeKey = '',
  });

  CallState copyWith({
    CallStatus? status,
    String? peerId,
    String? callId,
    CallDirection? direction,
    bool? isMuted,
    DateTime? startedAt,
    bool? isVideoEnabled,
    bool? remoteVideoEnabled,
    bool? isVideoCall,
    bool? isScreenSharing,
    bool? remoteScreenSharing,
    String? sframeKey,
  }) =>
      CallState(
        status: status ?? this.status,
        peerId: peerId ?? this.peerId,
        callId: callId ?? this.callId,
        direction: direction ?? this.direction,
        isMuted: isMuted ?? this.isMuted,
        startedAt: startedAt ?? this.startedAt,
        isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
        remoteVideoEnabled: remoteVideoEnabled ?? this.remoteVideoEnabled,
        isVideoCall: isVideoCall ?? this.isVideoCall,
        isScreenSharing: isScreenSharing ?? this.isScreenSharing,
        remoteScreenSharing: remoteScreenSharing ?? this.remoteScreenSharing,
        sframeKey: sframeKey ?? this.sframeKey,
      );

  static const idle = CallState();
}

class CallNotifier extends Notifier<CallState> {
  VoiceService? _voiceService;
  Timer? _ringTimer;
  Timer? _statsTimer;

  /// Separate PCs for screen sharing (one per direction).
  ScreenShareService? _outgoingScreenShare; // We share our screen to them
  ScreenShareService? _incomingScreenShare; // They share their screen to us

  /// Renderer for the incoming remote screen share. Used by UI.
  RTCVideoRenderer? get screenShareRenderer =>
      _incomingScreenShare?.remoteRenderer;

  VoiceService get _service {
    if (_voiceService == null) {
      final localPeerId = ref.read(identityProvider).peerId ?? '';
      final iceConfig = ref.read(iceConfigProvider);
      _voiceService = VoiceService(
          localPeerId: localPeerId, iceServers: iceConfig);
      _wireCallbacks();
    } else {
      // Keep ICE config up to date (TURN credentials refresh).
      _voiceService!.iceServers = ref.read(iceConfigProvider);
    }
    // Keep device preferences up to date.
    // Use .valueOrNull — async providers may still be loading on first access.
    // _ensureDevicePreferences() awaits them before the first call.
    _voiceService!.preferredAudioInputDeviceId =
        ref.read(audioInputDeviceProvider).valueOrNull;
    _voiceService!.preferredAudioOutputDeviceId =
        ref.read(audioOutputDeviceProvider).valueOrNull;
    return _voiceService!;
  }

  /// Expose the VoiceService so UI can access video renderers.
  VoiceService? get voiceService => _voiceService;

  @override
  CallState build() => const CallState();

  void _wireCallbacks() {
    _voiceService!.onConnected = (peerId) {
      debugPrint('[HOLLOW-CALL] Voice connected with $peerId');
      if (state.status == CallStatus.connecting) {
        state = state.copyWith(
          status: CallStatus.active,
          startedAt: DateTime.now(),
        );
        _scheduleStatsDump(peerId);
      }
    };

    _voiceService!.onDisconnected = (peerId) {
      debugPrint('[HOLLOW-CALL] Voice disconnected from $peerId');
      if (state.status == CallStatus.active ||
          state.status == CallStatus.connecting) {
        _sendSignal(peerId, 'end', state.callId ?? '');
        _cleanup();
      }
    };

    _voiceService!.onRemoteVideoTrack = (peerId) {
      debugPrint('[HOLLOW-CALL] Remote video track/renderer ready for $peerId');
      // Don't set remoteVideoEnabled here — that's controlled by the
      // video_state signal. The track always arrives (it's in the initial SDP)
      // but the remote user's camera may be disabled.
      if (state.remoteVideoEnabled) {
        state = state.copyWith(); // Force UI rebuild if already enabled
      }
    };
  }

  /// Ensure audio device preferences are loaded from SQLCipher before starting
  /// a call. On first access after app launch, the async providers may not have
  /// completed yet, causing the call to use system defaults (wrong device).
  Future<void> _ensureDevicePreferences() async {
    try {
      final input = await ref.read(audioInputDeviceProvider.future);
      final output = await ref.read(audioOutputDeviceProvider.future);
      _voiceService?.preferredAudioInputDeviceId = input;
      _voiceService?.preferredAudioOutputDeviceId = output;

      // Apply audio quality preset.
      final quality = await ref.read(audioQualityProvider.future);
      _voiceService?.opusBitrate = quality.bitrate;
      _voiceService?.opusStereo = quality.stereo;

    } catch (_) {}
  }

  /// Set the remote peer's audio volume (how loud you hear them).
  Future<void> setRemoteVolume(double volume) async {
    await _service.setRemoteAudioVolume(volume);
  }

  // ---------------------------------------------------------------------------
  // Call actions
  // ---------------------------------------------------------------------------

  /// Start an outgoing call to a peer.
  void startCall(String peerId, {bool withVideo = false}) {
    if (state.status != CallStatus.idle) return;

    final callId = _generateCallId();
    final sframeKey = _generateSframeKey();
    state = CallState(
      status: CallStatus.ringing,
      peerId: peerId,
      callId: callId,
      direction: CallDirection.outgoing,
      isVideoCall: withVideo,
      isVideoEnabled: withVideo,
      sframeKey: sframeKey,
    );

    final payload = jsonEncode({
      'call_id': callId,
      'video': withVideo,
      'sframe_key': sframeKey,
    });
    _sendSignal(peerId, 'invite', payload);

    // 30-second ring timeout.
    _ringTimer?.cancel();
    _ringTimer = Timer(const Duration(seconds: 30), () {
      if (state.status == CallStatus.ringing &&
          state.direction == CallDirection.outgoing) {
        debugPrint('[HOLLOW-CALL] Ring timeout, ending call');
        _sendSignal(peerId, 'end', callId);
        _cleanup();
      }
    });
  }

  /// Accept an incoming call.
  Future<void> acceptCall() async {
    if (state.status != CallStatus.ringing ||
        state.direction != CallDirection.incoming) {
      return;
    }

    final peerId = state.peerId!;
    final callId = state.callId!;

    _ringTimer?.cancel();
    state = state.copyWith(status: CallStatus.connecting);

    // Tell caller we accepted — they will send SDP offer.
    final acceptPayload = jsonEncode({
      'call_id': callId,
      'sframe_key': state.sframeKey,
    });
    _sendSignal(peerId, 'accept', acceptPayload);
  }

  /// Reject an incoming call.
  void rejectCall() {
    if (state.status != CallStatus.ringing ||
        state.direction != CallDirection.incoming) {
      return;
    }

    _sendSignal(state.peerId!, 'reject', state.callId!);
    _cleanup();
  }

  /// End the current call (active or ringing).
  Future<void> endCall() async {
    if (state.status == CallStatus.idle) return;

    final peerId = state.peerId;
    final callId = state.callId;
    if (peerId != null && callId != null) {
      _sendSignal(peerId, 'end', callId);
    }

    // Tear down screen share PCs.
    await _outgoingScreenShare?.close();
    _outgoingScreenShare = null;
    await _incomingScreenShare?.close();
    _incomingScreenShare = null;

    await _service.endCall();
    _cleanup();
  }

  /// Toggle microphone mute.
  void toggleMute() {
    if (state.status != CallStatus.active) return;
    _service.toggleMute();
    state = state.copyWith(isMuted: _service.isMuted);
  }

  /// Toggle camera on/off.
  Future<void> toggleVideo() async {
    if (state.status != CallStatus.active) return;

    final enabled = await _service.toggleVideo();
    state = state.copyWith(isVideoEnabled: enabled);

    final peerId = state.peerId;
    final callId = state.callId;
    if (peerId == null || callId == null) return;

    // Send video_state notification so remote UI knows.
    // No SDP renegotiation needed — video track was in the initial SDP.
    final videoStatePayload = jsonEncode({
      'call_id': callId,
      'enabled': enabled,
    });
    _sendSignal(peerId, 'video_state', videoStatePayload);
  }

  /// Switch between front and back camera.
  Future<void> switchCamera() async {
    if (state.status != CallStatus.active || !state.isVideoEnabled) return;
    await _service.switchCamera();
  }

  /// Start screen sharing via a dedicated RTCPeerConnection.
  Future<void> startScreenShare({
    required String sourceId,
    required int width,
    required int height,
    required int fps,
    bool shareAudio = false,
  }) async {
    if (state.status != CallStatus.active) return;

    final peerId = state.peerId!;
    final callId = state.callId!;
    final iceConfig = ref.read(iceConfigProvider);

    // Create outgoing screen share service (separate PC).
    _outgoingScreenShare = ScreenShareService(
      localPeerId: localPeerId,
      iceServers: iceConfig,
    );

    // Wire ICE callback to send screen_ice signals.
    _outgoingScreenShare!.onIceCandidate = (candidate) {
      _sendSignal(peerId, 'screen_ice', jsonEncode({
        'call_id': callId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'role': 'offerer',
      }));
    };

    _outgoingScreenShare!.onScreenShareEnded = () {
      if (state.isScreenSharing) {
        stopScreenShare();
      }
    };

    try {
      final offerSdp = await _outgoingScreenShare!.createOffer(
        sourceId, width, height, fps,
        shareAudio: shareAudio,
      );

      state = state.copyWith(isScreenSharing: true);

      _sendSignal(peerId, 'screen_offer',
          jsonEncode({'call_id': callId, 'sdp': offerSdp}));
      _sendSignal(peerId, 'screen_state',
          jsonEncode({'call_id': callId, 'enabled': true}));
    } catch (e) {
      debugPrint('[HOLLOW-CALL] Failed to start screen share: $e');
      await _outgoingScreenShare?.close();
      _outgoingScreenShare = null;
    }
  }

  /// Stop screen sharing.
  Future<void> stopScreenShare() async {
    await _outgoingScreenShare?.close();
    _outgoingScreenShare = null;
    state = state.copyWith(isScreenSharing: false);

    final peerId = state.peerId;
    final callId = state.callId;
    if (peerId != null && callId != null) {
      _sendSignal(peerId, 'screen_state',
          jsonEncode({'call_id': callId, 'enabled': false}));
    }
  }

  /// Master dispatcher for incoming call signals from Rust events.
  Future<void> handleCallSignal(
      String peerId, String signalType, String payload) async {
    try {
      switch (signalType) {
        case 'invite':
          _handleInvite(peerId, payload);
        case 'accept':
          await _handleAccept(peerId, payload);
        case 'reject':
          _handleReject(peerId, payload);
        case 'end':
          await _handleEnd(peerId, payload);
        case 'busy':
          _handleBusy(peerId, payload);
        case 'sdp_offer':
          await _handleSdpOffer(peerId, payload);
        case 'sdp_answer':
          await _handleSdpAnswer(peerId, payload);
        case 'ice':
          await _handleIce(peerId, payload);
        case 'video_state':
          _handleVideoState(peerId, payload);
        case 'screen_state':
          _handleScreenState(peerId, payload);
        case 'screen_offer':
          await _handleScreenOffer(peerId, payload);
        case 'screen_answer':
          await _handleScreenAnswer(peerId, payload);
        case 'screen_ice':
          await _handleScreenIce(peerId, payload);
      }
    } catch (e) {
      debugPrint('[HOLLOW-CALL] Signal error ($signalType from $peerId): $e');
    }
  }

  /// Handle peer going offline — auto-end any call with them.
  void handlePeerDisconnected(String peerId) {
    if (state.peerId == peerId && state.status != CallStatus.idle) {
      debugPrint('[HOLLOW-CALL] Peer $peerId disconnected, ending call');
      _service.endCall();
      _cleanup();
    }
  }

  /// Dispose (app shutdown).
  Future<void> disposeAll() async {
    _ringTimer?.cancel();
    _statsTimer?.cancel();
    await _voiceService?.dispose();
    state = const CallState();
  }

  // ---------------------------------------------------------------------------
  // Stats diagnostic
  // ---------------------------------------------------------------------------

  /// Schedule a getStats() dump 5 seconds after call goes active.
  void _scheduleStatsDump(String peerId) {
    _statsTimer?.cancel();
    _statsTimer = Timer(const Duration(seconds: 5), () async {
      final pc = _voiceService?.peerConnection;
      if (pc == null) {
        _callLog('[HOLLOW-STATS] No voice PC — cannot get stats');
        return;
      }

      _callLog('[HOLLOW-STATS] === AUDIO STATS 5s after call active ===');

      try {
        final stats = await pc.getStats();
        for (final report in stats) {
          final type = report.type;
          final values = report.values;

          if (type == 'outbound-rtp' && values['kind'] == 'audio') {
            _callLog('[HOLLOW-STATS] OUTBOUND-AUDIO: '
                'bytesSent=${values['bytesSent']}, '
                'packetsSent=${values['packetsSent']}, '
                'codec=${values['codecId']}');
          }

          if (type == 'inbound-rtp' && values['kind'] == 'audio') {
            _callLog('[HOLLOW-STATS] INBOUND-AUDIO: '
                'bytesReceived=${values['bytesReceived']}, '
                'packetsReceived=${values['packetsReceived']}, '
                'packetsLost=${values['packetsLost']}, '
                'codec=${values['codecId']}');
          }

          if (type == 'candidate-pair' && values['state'] == 'succeeded') {
            _callLog('[HOLLOW-STATS] ICE-PAIR: '
                'localCandidateId=${values['localCandidateId']}, '
                'remoteCandidateId=${values['remoteCandidateId']}, '
                'bytesSent=${values['bytesSent']}, '
                'bytesReceived=${values['bytesReceived']}');
          }
        }
      } catch (e) {
        _callLog('[HOLLOW-STATS] getStats failed: $e');
      }

      _callLog('[HOLLOW-STATS] === END STATS ===');
    });
  }

  // ---------------------------------------------------------------------------
  // Signal handlers
  // ---------------------------------------------------------------------------

  void _handleInvite(String peerId, String payload) {
    // Parse JSON payload {call_id, video, sframe_key}.
    String callId;
    bool withVideo = false;
    String sframeKey = '';
    if (payload.startsWith('{')) {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      callId = json['call_id'] as String;
      withVideo = json['video'] as bool? ?? false;
      sframeKey = json['sframe_key'] as String? ?? '';
    } else {
      callId = payload;
    }

    if (state.status != CallStatus.idle) {
      debugPrint('[HOLLOW-CALL] Busy, rejecting invite from $peerId');
      _sendSignal(peerId, 'busy', callId);
      return;
    }

    // Glare: if we sent an outgoing invite at the same time.
    if (state.status == CallStatus.ringing &&
        state.direction == CallDirection.outgoing &&
        state.peerId == peerId) {
      if (localPeerId.compareTo(peerId) < 0) {
        debugPrint('[HOLLOW-CALL] Glare: we are polite, accepting theirs');
        _ringTimer?.cancel();
        state = CallState(
          status: CallStatus.ringing,
          peerId: peerId,
          callId: callId,
          direction: CallDirection.incoming,
          isVideoCall: withVideo,
          sframeKey: sframeKey,
        );
        return;
      } else {
        debugPrint('[HOLLOW-CALL] Glare: we are impolite, ignoring theirs');
        return;
      }
    }

    state = CallState(
      status: CallStatus.ringing,
      peerId: peerId,
      callId: callId,
      direction: CallDirection.incoming,
      isVideoCall: withVideo,
      sframeKey: sframeKey,
    );

    // 30-second auto-reject timeout.
    _ringTimer?.cancel();
    _ringTimer = Timer(const Duration(seconds: 30), () {
      if (state.status == CallStatus.ringing &&
          state.direction == CallDirection.incoming &&
          state.callId == callId) {
        debugPrint('[HOLLOW-CALL] Incoming ring timeout, auto-rejecting');
        rejectCall();
      }
    });
  }

  Future<void> _handleAccept(String peerId, String payload) async {
    // Parse JSON payload to extract call_id.
    String callId;
    try {
      final v = jsonDecode(payload);
      callId = v['call_id'] as String? ?? payload;
    } catch (_) {
      callId = payload;
    }

    if (state.status != CallStatus.ringing ||
        state.direction != CallDirection.outgoing ||
        state.callId != callId) {
      return;
    }

    _ringTimer?.cancel();
    state = state.copyWith(status: CallStatus.connecting);

    // Ensure device preferences are loaded before starting media.
    await _ensureDevicePreferences();

    // We are the caller — create a dedicated voice PC, capture audio, create offer.
    final sdp = await _service.createOffer(
      peerId,
      callId,
      withVideo: state.isVideoCall,
    );

    // Enable SFrame E2EE using the key we generated in startCall.
    final keyHex = state.sframeKey;
    if (keyHex.isNotEmpty) {
      final keyBytes = _hexToBytes(keyHex);
      await _service.setSframeKey(peerId, keyBytes);
    }

    final sdpPayload = jsonEncode({'call_id': callId, 'sdp': sdp});
    _sendSignal(peerId, 'sdp_offer', sdpPayload);
  }

  void _handleReject(String peerId, String callId) {
    if (state.callId != callId) return;
    debugPrint('[HOLLOW-CALL] Call rejected by $peerId');
    _cleanup();
  }

  Future<void> _handleEnd(String peerId, String callId) async {
    if (state.callId != callId) return;
    debugPrint('[HOLLOW-CALL] Call ended by $peerId');
    await _outgoingScreenShare?.close();
    _outgoingScreenShare = null;
    await _incomingScreenShare?.close();
    _incomingScreenShare = null;
    await _service.endCall();
    _cleanup();
  }

  void _handleBusy(String peerId, String callId) {
    if (state.callId != callId) return;
    debugPrint('[HOLLOW-CALL] Peer $peerId is busy');
    _cleanup();
  }

  Future<void> _handleSdpOffer(String peerId, String payload) async {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final callId = json['call_id'] as String;
    final sdp = json['sdp'] as String;

    if (state.callId != callId) return;

    if (state.status == CallStatus.active && _service.hasActiveCall) {
      // Renegotiation on existing voice PC (e.g., remote toggled video).
      final answerSdp = await _service.handleRenegotiationOffer(sdp);
      if (answerSdp != null) {
        final answerPayload = jsonEncode({'call_id': callId, 'sdp': answerSdp});
        _sendSignal(peerId, 'sdp_answer', answerPayload);
      }
    } else {
      // Ensure device preferences are loaded before starting media.
      await _ensureDevicePreferences();
      // Initial call setup — create a dedicated voice PC, capture audio, answer.
      final answerSdp = await _service.handleOffer(
        peerId,
        callId,
        sdp,
        withVideo: state.isVideoCall,
      );

      // Enable SFrame E2EE using the key from the invite.
      final keyHex = state.sframeKey;
      if (keyHex.isNotEmpty) {
        final keyBytes = _hexToBytes(keyHex);
        await _service.setSframeKey(peerId, keyBytes);
      }

      final answerPayload = jsonEncode({'call_id': callId, 'sdp': answerSdp});
      _sendSignal(peerId, 'sdp_answer', answerPayload);
    }
  }

  Future<void> _handleSdpAnswer(String peerId, String payload) async {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final callId = json['call_id'] as String;
    final sdp = json['sdp'] as String;

    if (state.callId != callId) return;

    await _service.handleAnswer(sdp);
  }

  Future<void> _handleIce(String peerId, String payload) async {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final callId = json['call_id'] as String;

    if (state.callId != callId) return;

    await _service.handleIceCandidate(
      json['candidate'] as String,
      json['sdpMid'] as String?,
      (json['sdpMLineIndex'] as num?)?.toInt(),
    );
  }

  void _handleVideoState(String peerId, String payload) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final callId = json['call_id'] as String;
    final enabled = json['enabled'] as bool;

    if (state.callId != callId) return;

    debugPrint(
        '[HOLLOW-CALL] Remote video state: enabled=$enabled from $peerId');
    state = state.copyWith(remoteVideoEnabled: enabled);
  }

  void _handleScreenState(String peerId, String payload) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final callId = json['call_id'] as String;
    final enabled = json['enabled'] as bool;

    if (state.callId != callId) return;

    debugPrint(
        '[HOLLOW-CALL] Remote screen share: enabled=$enabled from $peerId');

    if (!enabled) {
      // Remote stopped sharing — tear down the incoming screen share PC.
      _incomingScreenShare?.close();
      _incomingScreenShare = null;
    }

    state = state.copyWith(remoteScreenSharing: enabled);
  }

  Future<void> _handleScreenOffer(String peerId, String payload) async {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final callId = json['call_id'] as String;
    final sdp = json['sdp'] as String;

    if (state.callId != callId) return;

    debugPrint('[HOLLOW-CALL] Screen offer from $peerId');

    final iceConfig = ref.read(iceConfigProvider);

    // Create incoming screen share service (separate PC to receive their screen).
    _incomingScreenShare = ScreenShareService(
      localPeerId: localPeerId,
      iceServers: iceConfig,
    );

    // Wire ICE callback.
    _incomingScreenShare!.onIceCandidate = (candidate) {
      _sendSignal(peerId, 'screen_ice', jsonEncode({
        'call_id': callId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'role': 'answerer',
      }));
    };

    _incomingScreenShare!.onRemoteTrackReady = () {
      // Force UI rebuild so RTCVideoView picks up the renderer.
      debugPrint('[HOLLOW-CALL] Screen share remote track ready');
      state = state.copyWith();
    };

    // Set preferred audio output so screen share audio plays to the right speaker.
    try {
      final output = await ref.read(audioOutputDeviceProvider.future);
      _incomingScreenShare!.preferredAudioOutputDeviceId = output;
    } catch (_) {}

    // Handle the offer and send answer.
    final answerSdp = await _incomingScreenShare!.handleOffer(sdp);
    _sendSignal(peerId, 'screen_answer',
        jsonEncode({'call_id': callId, 'sdp': answerSdp}));
  }

  Future<void> _handleScreenAnswer(String peerId, String payload) async {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final callId = json['call_id'] as String;
    final sdp = json['sdp'] as String;

    if (state.callId != callId || _outgoingScreenShare == null) return;

    debugPrint('[HOLLOW-CALL] Screen answer from $peerId');
    await _outgoingScreenShare!.handleAnswer(sdp);
  }

  Future<void> _handleScreenIce(String peerId, String payload) async {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final callId = json['call_id'] as String;

    if (state.callId != callId) return;

    final candidate = json['candidate'] as String;
    final sdpMid = json['sdpMid'] as String?;
    final sdpMLineIndex = (json['sdpMLineIndex'] as num?)?.toInt();
    final role = json['role'] as String;

    // Route to the opposite PC: offerer's candidates go to our incoming PC,
    // answerer's candidates go to our outgoing PC.
    if (role == 'offerer') {
      await _incomingScreenShare?.handleIceCandidate(
          candidate, sdpMid, sdpMLineIndex);
    } else {
      await _outgoingScreenShare?.handleIceCandidate(
          candidate, sdpMid, sdpMLineIndex);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String get localPeerId => ref.read(identityProvider).peerId ?? '';

  void _sendSignal(String peerId, String signalType, String payload) {
    network_api.callSendSignal(
      peerId: peerId,
      signalType: signalType,
      payload: payload,
    );
  }

  void _cleanup() {
    _ringTimer?.cancel();
    _ringTimer = null;
    _statsTimer?.cancel();
    _statsTimer = null;
    state = const CallState();
  }

  String _generateCallId() {
    final r = Random();
    return List.generate(
            16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Generate a random 32-byte SFrame key (hex-encoded).
  String _generateSframeKey() {
    final r = Random.secure();
    return List.generate(
            32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Convert hex string to Uint8List.
  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

final callProvider =
    NotifierProvider<CallNotifier, CallState>(CallNotifier.new);
