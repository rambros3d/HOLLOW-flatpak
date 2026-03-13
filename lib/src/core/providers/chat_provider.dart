import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/chat_message.dart';
import 'package:haven/src/core/providers/service_providers.dart';
import 'package:haven/src/rust/api/network.dart' as network_api;

/// Generate a 32-char hex message ID (same format as Rust's 16-byte random).
String generateMessageId() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class ChatNotifier extends Notifier<Map<String, List<ChatMessage>>> {
  @override
  Map<String, List<ChatMessage>> build() => {};

  /// Send a message to a peer (FFI + update state).
  /// DB persistence happens in Rust (SendMessage handler) with Rust-generated timestamp.
  Future<void> sendMessage(String peerId, String text) async {
    final networkService = ref.read(networkServiceProvider);
    final messageId = generateMessageId();

    await networkService.sendMessage(
      peerId: peerId,
      text: text,
      messageId: messageId,
    );

    final now = DateTime.now();
    final msg = ChatMessage(
      text: text,
      isMe: true,
      timestamp: now,
      messageId: messageId,
    );

    _addMessage(peerId, msg);
  }

  /// Receive a message from a peer (from network events).
  /// DB persistence happens in Rust (DirectMessage handler) with sender's timestamp.
  void receiveMessage(
      String fromPeer, String text, int timestamp, String messageId) {
    final ts = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final msg = ChatMessage(
      text: text,
      isMe: false,
      timestamp: ts,
      messageId: messageId.isNotEmpty ? messageId : null,
    );
    _addMessage(fromPeer, msg);
  }

  /// Edit a message we sent.
  Future<void> editMessage(
      String peerId, String messageId, String newText) async {
    await network_api.editDmMessage(
      peerId: peerId,
      messageId: messageId,
      newText: newText,
    );
    // UI update happens via the DmMessageEdited event.
  }

  /// Apply an edit to an in-memory message (from network event or own edit).
  void applyEdit(
      String peerId, String messageId, String newText, int editedAtMs) {
    final current = state[peerId];
    if (current == null) return;

    final editedAt = DateTime.fromMillisecondsSinceEpoch(editedAtMs);
    final idx = current.indexWhere((m) => m.messageId == messageId);
    if (idx == -1) return;

    final updatedList = List<ChatMessage>.from(current);
    updatedList[idx] =
        updatedList[idx].copyWith(text: newText, editedAt: editedAt);
    final updated = Map.of(state);
    updated[peerId] = updatedList;
    state = updated;
  }

  /// Delete (hide) a message we sent.
  Future<void> deleteMessage(String peerId, String messageId) async {
    await network_api.deleteDmMessage(
      peerId: peerId,
      messageId: messageId,
    );
    // UI update happens via the DmMessageDeleted event.
  }

  /// Remove a message from in-memory state (from network event or own deletion).
  void applyDelete(String peerId, String messageId, int deletedAtMs) {
    final current = state[peerId];
    if (current == null) return;

    final updatedList =
        current.where((m) => m.messageId != messageId).toList();
    if (updatedList.length == current.length) return; // Not found.

    final updated = Map.of(state);
    updated[peerId] = updatedList;
    state = updated;
  }

  /// Add a send-failure message (shown as a local system message).
  void addSendFailure(String toPeer, String error) {
    _addMessage(
      toPeer,
      ChatMessage(text: '[Failed to send: $error]', isMe: true),
    );
  }

  /// Load chat history from SQLCipher for a peer.
  Future<void> loadHistory(String peerId) async {
    final existing = state[peerId];
    if (existing != null && existing.isNotEmpty) return;

    try {
      final storageService = ref.read(storageServiceProvider);
      final stored = await storageService.loadMessages(
        peerId: peerId,
        limit: 200,
      );

      final messages = stored
          .map((m) => ChatMessage(
                text: m.text,
                isMe: m.isMine,
                timestamp:
                    DateTime.fromMillisecondsSinceEpoch(m.timestamp),
                signature: m.signature,
                publicKey: m.publicKey,
                messageId: m.messageId,
                editedAt: m.editedAt != null
                    ? DateTime.fromMillisecondsSinceEpoch(m.editedAt!)
                    : null,
              ))
          .toList();

      final updated = Map.of(state);
      updated[peerId] = messages;
      state = updated;
    } catch (e) {
      debugPrint('[HAVEN] Failed to load history for $peerId: $e');
    }
  }

  /// Clear cached messages for a peer (forces reload from DB on next view).
  void clearPeerCache(String peerId) {
    final updated = Map.of(state);
    updated.remove(peerId);
    state = updated;
  }

  void _addMessage(String peerId, ChatMessage message) {
    final current = state[peerId] ?? [];
    final updated = Map.of(state);
    updated[peerId] = [...current, message];
    state = updated;
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, Map<String, List<ChatMessage>>>(
        ChatNotifier.new);
