import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/rust/api/storage.dart' as storage_api;

const _settingsKey = 'hidden_archive_dms';

/// Set of peer IDs the user has chosen to hide from the main DM list in the
/// Archive "My Data" tab. Hidden peers are collected in a collapsible
/// "Hidden" section at the bottom of the list. Local-only, never synced.
class HiddenArchiveDmsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  Future<void> load() async {
    try {
      final raw = await storage_api.loadSetting(key: _settingsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (json.decode(raw) as List).cast<String>();
        state = list.toSet();
      }
    } catch (e) {
      debugPrint('[HOLLOW] Failed to load hidden archive DMs: $e');
    }
  }

  Future<void> _persist() async {
    try {
      await storage_api.saveSetting(
        key: _settingsKey,
        value: json.encode(state.toList()),
      );
    } catch (e) {
      debugPrint('[HOLLOW] Failed to save hidden archive DMs: $e');
    }
  }

  Future<void> hide(String peerId) async {
    if (state.contains(peerId)) return;
    state = {...state, peerId};
    await _persist();
  }

  Future<void> unhide(String peerId) async {
    if (!state.contains(peerId)) return;
    state = state.where((id) => id != peerId).toSet();
    await _persist();
  }

  bool isHidden(String peerId) => state.contains(peerId);
}

final hiddenArchiveDmsProvider =
    NotifierProvider<HiddenArchiveDmsNotifier, Set<String>>(
        HiddenArchiveDmsNotifier.new);
