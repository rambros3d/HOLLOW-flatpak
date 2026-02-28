import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The currently selected peer ID for the chat pane.
final selectedPeerProvider = StateProvider<String?>((_) => null);
