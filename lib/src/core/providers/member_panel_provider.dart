import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the right-side member panel is visible.
/// Defaults to true (desktop shows it open).
final memberPanelProvider = StateProvider<bool>((ref) => true);

/// Whether the channel search bar is open.
/// Toggled by Ctrl+K globally or the search icon in the channel header.
final channelSearchOpenProvider = StateProvider<bool>((ref) => false);
