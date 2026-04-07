import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The messageId of the video that is currently playing inline, or null.
///
/// Only one video plays at a time. When a `VideoMessageBubble` enters the
/// playing state it sets this to its own messageId; when another bubble takes
/// over (or the user scrolls away), the previously-playing bubble watches this
/// provider, sees the value change, and tears down its player.
///
/// Phase 6.75 video preview in chats. See HOLLOW_PLAN.md.
final currentlyPlayingVideoProvider = StateProvider<String?>((ref) => null);
