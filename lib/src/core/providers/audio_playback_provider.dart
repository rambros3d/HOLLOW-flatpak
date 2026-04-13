import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The fileId of the audio that is currently playing inline, or null.
///
/// Only one audio plays at a time. When an `AudioMessageBubble` enters the
/// playing state it sets this to its own fileId; when another bubble takes
/// over, the previously-playing bubble watches this provider and tears down.
///
/// Cross-linked with [currentlyPlayingVideoProvider] — starting audio stops
/// any playing video, and vice versa.
final currentlyPlayingAudioProvider = StateProvider<String?>((ref) => null);
