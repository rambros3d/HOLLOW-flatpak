/// Information about a discovered peer.
class PeerInfo {
  final String peerId;
  final List<String> addresses;
  final bool isEncrypted;

  const PeerInfo({
    required this.peerId,
    this.addresses = const [],
    this.isEncrypted = false,
  });

  PeerInfo copyWith({
    String? peerId,
    List<String>? addresses,
    bool? isEncrypted,
  }) {
    return PeerInfo(
      peerId: peerId ?? this.peerId,
      addresses: addresses ?? this.addresses,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }
}
