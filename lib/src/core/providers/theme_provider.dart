import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls the app theme mode. Defaults to dark (primary theme).
// TODO: Persist to local settings in Phase 3 (SQLCipher).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
