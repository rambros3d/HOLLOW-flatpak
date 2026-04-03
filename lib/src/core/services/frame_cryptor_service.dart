import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../rust/api/network.dart' as network_api;

void _fcLog(String msg) {
  network_api.logFromDart(message: msg);
}

/// Reusable service managing SFrame encryption for WebRTC audio/video.
///
/// Wraps flutter_webrtc's FrameCryptor + KeyProvider APIs.
/// One instance per call session (1:1 DM) or voice channel session (server).
class FrameCryptorService {
  KeyProvider? _keyProvider;

  /// Sender-side frame cryptors: peerId -> FrameCryptor.
  final Map<String, FrameCryptor> _senderCryptors = {};

  /// Receiver-side frame cryptors: peerId -> FrameCryptor.
  final Map<String, FrameCryptor> _receiverCryptors = {};

  /// Whether encryption is active.
  bool _enabled = false;

  /// Initialize the KeyProvider. Call once per session before enabling encryption.
  ///
  /// [sharedKey]: true = all participants use the same key (server voice channels).
  ///              false = per-participant keys (DM calls).
  Future<void> init({bool sharedKey = true}) async {
    final options = KeyProviderOptions(
      sharedKey: sharedKey,
      ratchetSalt: Uint8List.fromList('hollow-sframe-salt'.codeUnits),
      ratchetWindowSize: 16,
      failureTolerance: -1, // unlimited
      keyRingSize: 16,
      discardFrameWhenCryptorNotReady: false,
    );
    _keyProvider = await frameCryptorFactory.createDefaultKeyProvider(options);
    _fcLog('[HOLLOW-SFRAME] KeyProvider initialized (sharedKey=$sharedKey)');
  }

  /// Set the encryption key for a participant (or shared key if sharedKey mode).
  Future<void> setKey(String participantId, int index, Uint8List key) async {
    if (_keyProvider == null) return;
    await _keyProvider!.setKey(
      participantId: participantId,
      index: index,
      key: key,
    );
    _fcLog('[HOLLOW-SFRAME] Key set for $participantId at index $index (${key.length} bytes)');
  }

  /// Set a shared key (for server voice channels where all members share the MLS epoch key).
  Future<void> setSharedKey(int index, Uint8List key) async {
    if (_keyProvider == null) return;
    await _keyProvider!.setSharedKey(key: key, index: index);
    _fcLog('[HOLLOW-SFRAME] Shared key set at index $index (${key.length} bytes)');
  }

  /// Enable frame encryption for an RTP sender (our outgoing audio/video).
  Future<void> enableForSender(String peerId, RTCRtpSender sender) async {
    if (_keyProvider == null) return;
    if (_senderCryptors.containsKey(peerId)) return;

    try {
      final cryptor = await frameCryptorFactory.createFrameCryptorForRtpSender(
        participantId: peerId,
        sender: sender,
        algorithm: Algorithm.kAesGcm,
        keyProvider: _keyProvider!,
      );
      cryptor.onFrameCryptorStateChanged = (pid, state) {
        _fcLog('[HOLLOW-SFRAME] Sender $pid state: $state');
      };
      await cryptor.setEnabled(true);
      _senderCryptors[peerId] = cryptor;
      _enabled = true;
      _fcLog('[HOLLOW-SFRAME] Sender encryption enabled for $peerId');
    } catch (e) {
      _fcLog('[HOLLOW-SFRAME] Failed to enable sender encryption for $peerId: $e');
    }
  }

  /// Enable frame decryption for an RTP receiver (incoming audio/video from peer).
  Future<void> enableForReceiver(String peerId, RTCRtpReceiver receiver) async {
    if (_keyProvider == null) return;
    if (_receiverCryptors.containsKey(peerId)) return;

    try {
      final cryptor =
          await frameCryptorFactory.createFrameCryptorForRtpReceiver(
        participantId: peerId,
        receiver: receiver,
        algorithm: Algorithm.kAesGcm,
        keyProvider: _keyProvider!,
      );
      cryptor.onFrameCryptorStateChanged = (pid, state) {
        _fcLog('[HOLLOW-SFRAME] Receiver $pid state: $state');
      };
      await cryptor.setEnabled(true);
      _receiverCryptors[peerId] = cryptor;
      _fcLog('[HOLLOW-SFRAME] Receiver decryption enabled for $peerId');
    } catch (e) {
      _fcLog('[HOLLOW-SFRAME] Failed to enable receiver decryption for $peerId: $e');
    }
  }

  /// Rotate the encryption key (e.g., on MLS epoch change).
  Future<void> rotateKey(int newIndex, Uint8List newKey) async {
    if (_keyProvider == null) return;
    await _keyProvider!.setSharedKey(key: newKey, index: newIndex);
    // Update key index on all active cryptors.
    for (final cryptor in _senderCryptors.values) {
      await cryptor.setKeyIndex(newIndex);
    }
    for (final cryptor in _receiverCryptors.values) {
      await cryptor.setKeyIndex(newIndex);
    }
    _fcLog('[HOLLOW-SFRAME] Key rotated to index $newIndex');
  }

  /// Disable and clean up cryptors for a specific peer.
  Future<void> disableForPeer(String peerId) async {
    final sender = _senderCryptors.remove(peerId);
    if (sender != null) {
      await sender.setEnabled(false);
      await sender.dispose();
    }
    final receiver = _receiverCryptors.remove(peerId);
    if (receiver != null) {
      await receiver.setEnabled(false);
      await receiver.dispose();
    }
  }

  /// Whether frame encryption is currently active.
  bool get isEnabled => _enabled;

  /// Dispose all cryptors and the key provider.
  Future<void> dispose() async {
    for (final cryptor in _senderCryptors.values) {
      try { await cryptor.setEnabled(false); } catch (_) {}
      try { await cryptor.dispose(); } catch (_) {}
    }
    _senderCryptors.clear();
    for (final cryptor in _receiverCryptors.values) {
      try { await cryptor.setEnabled(false); } catch (_) {}
      try { await cryptor.dispose(); } catch (_) {}
    }
    _receiverCryptors.clear();
    try { await _keyProvider?.dispose(); } catch (_) {}
    _keyProvider = null;
    _enabled = false;
    _fcLog('[HOLLOW-SFRAME] Disposed');
  }
}
