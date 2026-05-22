import 'package:flutter_riverpod/flutter_riverpod.dart';

class GuestChannelEntry {
  final String channelId;
  final String name;
  final String? category;

  const GuestChannelEntry({
    required this.channelId,
    required this.name,
    this.category,
  });
}

class GuestChannelListNotifier extends StateNotifier<List<GuestChannelEntry>> {
  GuestChannelListNotifier() : super([]);

  void setChannels(List<GuestChannelEntry> channels) => state = channels;
  void clear() => state = [];
}

final guestServerIdProvider = StateProvider<String?>((ref) => null);

final guestServerNameProvider = StateProvider<String>((ref) => '');

final guestChannelListProvider =
    StateNotifierProvider<GuestChannelListNotifier, List<GuestChannelEntry>>(
        (ref) => GuestChannelListNotifier());

final guestSelectedChannelProvider = StateProvider<String?>((ref) => null);

final guestLoadingProvider = StateProvider<bool>((ref) => false);

final guestHasMoreProvider = StateProvider<bool>((ref) => false);
