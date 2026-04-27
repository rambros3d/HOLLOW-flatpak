final _hollowLinkRegex = RegExp(r'hollow://[^\s<>"' "'" r')\]}]+');

enum HollowLinkType { share, serverInvite, roomInvite }

class HollowLink {
  final HollowLinkType type;
  final String fullUrl;
  final String id;

  const HollowLink({
    required this.type,
    required this.fullUrl,
    required this.id,
  });
}

List<HollowLink> extractHollowLinks(String text) {
  final matches = _hollowLinkRegex.allMatches(text);
  final results = <HollowLink>[];
  final seen = <String>{};

  for (final match in matches) {
    final url = match.group(0)!;
    if (seen.contains(url)) continue;
    seen.add(url);

    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'hollow') continue;

    if (uri.host == 'share') {
      final payload = uri.path.length > 1 ? uri.path.substring(1) : '';
      if (payload.isNotEmpty) {
        results.add(HollowLink(
          type: HollowLinkType.share,
          fullUrl: url,
          id: payload,
        ));
      }
    } else if (uri.host == 'join') {
      final serverId = uri.queryParameters['server'];
      final roomCode = uri.queryParameters['room'];
      if (serverId != null && serverId.isNotEmpty) {
        results.add(HollowLink(
          type: HollowLinkType.serverInvite,
          fullUrl: url,
          id: serverId,
        ));
      } else if (roomCode != null && roomCode.isNotEmpty) {
        results.add(HollowLink(
          type: HollowLinkType.roomInvite,
          fullUrl: url,
          id: roomCode,
        ));
      }
    }
  }

  return results;
}
