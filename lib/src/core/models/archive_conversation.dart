/// A DM conversation entry for the archive sidebar.
class ArchiveDmEntry {
  final String peerId;
  final int messageCount;

  const ArchiveDmEntry({required this.peerId, required this.messageCount});
}

/// A server group containing channels with message history.
class ArchiveChannelGroup {
  final String serverId;
  final String serverName;
  final List<ArchiveChannelEntry> channels;

  const ArchiveChannelGroup({
    required this.serverId,
    required this.serverName,
    required this.channels,
  });
}

/// A channel conversation entry for the archive sidebar.
class ArchiveChannelEntry {
  final String serverId;
  final String serverName;
  final String channelId;
  final String channelName;
  final int messageCount;

  const ArchiveChannelEntry({
    required this.serverId,
    required this.serverName,
    required this.channelId,
    required this.channelName,
    required this.messageCount,
  });
}
