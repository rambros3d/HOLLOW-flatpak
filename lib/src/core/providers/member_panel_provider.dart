import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the right-side member panel is visible.
/// Defaults to true (desktop shows it open).
final memberPanelProvider = StateProvider<bool>((ref) => true);
