import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haven/src/core/models/chat_message.dart';
import 'package:haven/src/core/models/node_status.dart';
import 'package:haven/src/core/models/peer_info.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/sidebar/empty_peer_list.dart';
import 'package:haven/src/ui/sidebar/peer_card.dart';

class Sidebar extends StatelessWidget {
  final Map<String, PeerInfo> peers;
  final Map<String, List<ChatMessage>> chatHistory;
  final String? selectedPeerId;
  final NodeStatus nodeStatus;
  final ValueChanged<String> onPeerSelected;
  final ChatMessage? Function(String) lastMessage;
  final String Function(DateTime) formatTime;
  final String? activeRoom;
  final TextEditingController roomController;
  final Future<void> Function(String) onJoinRoom;
  final VoidCallback onCreateInvite;

  const Sidebar({
    super.key,
    required this.peers,
    required this.chatHistory,
    required this.selectedPeerId,
    required this.nodeStatus,
    required this.onPeerSelected,
    required this.lastMessage,
    required this.formatTime,
    required this.activeRoom,
    required this.roomController,
    required this.onJoinRoom,
    required this.onCreateInvite,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: haven.background,
        border: Border(
          right: BorderSide(color: haven.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room code section
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HavenSpacing.md,
              HavenSpacing.md,
              HavenSpacing.md,
              HavenSpacing.sm,
            ),
            child: activeRoom != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HavenSpacing.sm + 2,
                      vertical: HavenSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: haven.accentMuted,
                      borderRadius:
                          BorderRadius.circular(haven.radiusMd),
                      border: Border.all(
                        color: haven.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_done,
                          size: 16,
                          color: haven.accent,
                        ),
                        const SizedBox(width: HavenSpacing.sm),
                        Expanded(
                          child: Text(
                            'Room: $activeRoom',
                            style: HavenTypography.bodySmall.copyWith(
                              color: haven.accent,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          borderRadius:
                              BorderRadius.circular(haven.radiusSm),
                          onTap: () {
                            final link =
                                'haven://join?room=$activeRoom';
                            Clipboard.setData(
                                ClipboardData(text: link));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Invite link copied',
                                  style: HavenTypography.body.copyWith(
                                    color: haven.textPrimary,
                                  ),
                                ),
                                backgroundColor: haven.elevated,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.all(HavenSpacing.xs),
                            child: Icon(
                              Icons.copy,
                              size: 14,
                              color: haven.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: TextField(
                                controller: roomController,
                                style: HavenTypography.bodySmall.copyWith(
                                  color: haven.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Room code or invite link...',
                                  hintStyle:
                                      HavenTypography.bodySmall.copyWith(
                                    color: haven.textSecondary,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: HavenSpacing.sm + 2,
                                    vertical: 0,
                                  ),
                                  filled: true,
                                  fillColor: haven.elevated,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        haven.radiusMd),
                                    borderSide:
                                        BorderSide(color: haven.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        haven.radiusMd),
                                    borderSide:
                                        BorderSide(color: haven.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        haven.radiusMd),
                                    borderSide: BorderSide(
                                        color: haven.accent, width: 1.5),
                                  ),
                                  isDense: true,
                                ),
                                onSubmitted: (v) =>
                                    onJoinRoom(v.trim()),
                              ),
                            ),
                          ),
                          const SizedBox(width: HavenSpacing.sm - 2),
                          SizedBox(
                            height: 36,
                            child: FilledButton(
                              onPressed: () => onJoinRoom(
                                  roomController.text.trim()),
                              style: FilledButton.styleFrom(
                                backgroundColor: haven.accent,
                                foregroundColor: haven.textOnAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: HavenSpacing.md),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      haven.radiusMd),
                                ),
                              ),
                              child: Text(
                                'Join',
                                style: HavenTypography.label.copyWith(
                                  color: haven.textOnAccent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: HavenSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: onCreateInvite,
                          icon: Icon(Icons.add_link,
                              size: 16, color: haven.accent),
                          label: Text(
                            'Create Invite',
                            style: HavenTypography.label.copyWith(
                              color: haven.accent,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: haven.accent.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  haven.radiusMd),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: HavenSpacing.md),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Divider(height: 1, color: haven.border),

          // Sidebar header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HavenSpacing.lg,
              HavenSpacing.sm,
              HavenSpacing.lg,
              HavenSpacing.sm,
            ),
            child: Text(
              'PEERS (${peers.length})',
              style: HavenTypography.caption.copyWith(
                color: haven.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Divider(height: 1, color: haven.border),

          // Peer list
          Expanded(
            child: peers.isEmpty
                ? EmptyPeerList(nodeStatus: nodeStatus)
                : ListView.builder(
                    itemCount: peers.length,
                    padding: const EdgeInsets.symmetric(
                        vertical: HavenSpacing.xs),
                    itemBuilder: (context, index) {
                      final peerId = peers.keys.elementAt(index);
                      final peer = peers[peerId];
                      final isSelected = peerId == selectedPeerId;
                      final last = lastMessage(peerId);

                      return PeerCard(
                        peerId: peerId,
                        isSelected: isSelected,
                        isEncrypted: peer?.isEncrypted ?? false,
                        lastMessage: last,
                        formatTime: formatTime,
                        onTap: () => onPeerSelected(peerId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
