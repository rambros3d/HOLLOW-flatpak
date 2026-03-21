import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/rust/api/storage.dart' as storage_api;

/// Layout modes available in the app.
enum LayoutMode { classic, dock }

/// Persisted layout mode preference.
/// Default: dock (the new bottom-bar layout).
final layoutModeProvider =
    AsyncNotifierProvider<LayoutModeNotifier, LayoutMode>(
        LayoutModeNotifier.new);

class LayoutModeNotifier extends AsyncNotifier<LayoutMode> {
  @override
  Future<LayoutMode> build() async {
    final val = await storage_api.loadSetting(key: 'layout_mode');
    return val == 'classic' ? LayoutMode.classic : LayoutMode.dock;
  }

  Future<void> setMode(LayoutMode mode) async {
    await storage_api.saveSetting(
      key: 'layout_mode',
      value: mode == LayoutMode.classic ? 'classic' : 'dock',
    );
    state = AsyncData(mode);
  }
}
