import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/node_status.dart';
import 'package:haven/src/core/providers/identity_provider.dart';
import 'package:haven/src/core/providers/node_provider.dart';
import 'package:haven/src/core/providers/peers_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_avatar.dart';
import 'package:haven/src/ui/components/status_dot.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Right-side member panel (240px) showing online peers and connection info.
class MemberPanel extends ConsumerWidget {
  /// Fixed width for desktop/tablet. Pass null on mobile to fill available space.
  final double? width;

  const MemberPanel({super.key, this.width = 240});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haven = HavenTheme.of(context);
    final peers = ref.watch(peersProvider);
    final nodeState = ref.watch(nodeProvider);
    final identity = ref.watch(identityProvider);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: haven.surface,
        border: Border(
          left: BorderSide(color: haven.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: HavenSpacing.lg),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: haven.border),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              'Members — ${peers.length}',
              style: HavenTypography.caption.copyWith(
                color: haven.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Member list
          Expanded(
            child: peers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(HavenSpacing.xl),
                      child: Text(
                        'No peers online',
                        style: HavenTypography.bodySmall.copyWith(
                          color: haven.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: peers.length,
                    padding: const EdgeInsets.symmetric(
                        vertical: HavenSpacing.sm),
                    itemBuilder: (context, index) {
                      final peerId = peers.keys.elementAt(index);
                      final peer = peers[peerId];

                      return _MemberTile(
                        peerId: peerId,
                        isEncrypted: peer?.isEncrypted ?? false,
                      );
                    },
                  ),
          ),

          // Connection info section
          Container(
            padding: const EdgeInsets.all(HavenSpacing.md),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: haven.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection status
                Row(
                  children: [
                    StatusDot(
                      color: _statusColor(haven, nodeState.status),
                      size: 7,
                    ),
                    const SizedBox(width: HavenSpacing.xs),
                    Text(
                      _statusText(nodeState.status),
                      style: HavenTypography.caption.copyWith(
                        color: haven.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (identity.peerId != null) ...[
                  const SizedBox(height: HavenSpacing.xs),
                  Tooltip(
                    message: 'Tap to copy full Peer ID',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(haven.radiusSm),
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: identity.peerId!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Peer ID copied',
                              style: HavenTypography.body.copyWith(
                                color: haven.textPrimary,
                              ),
                            ),
                            backgroundColor: haven.elevated,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Text(
                        identity.peerId!.length > 20
                            ? '${identity.peerId!.substring(0, 20)}...'
                            : identity.peerId!,
                        style: HavenTypography.mono.copyWith(
                          color: haven.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(HavenTheme haven, NodeStatus status) {
    return switch (status) {
      NodeStatus.connected => haven.success,
      NodeStatus.starting => haven.warning,
      NodeStatus.loading => haven.textSecondary,
      NodeStatus.error => haven.error,
    };
  }

  String _statusText(NodeStatus status) {
    return switch (status) {
      NodeStatus.connected => 'Connected',
      NodeStatus.starting => 'Connecting...',
      NodeStatus.loading => 'Loading...',
      NodeStatus.error => 'Connection error',
    };
  }
}

/// A compact member row in the member panel.
class _MemberTile extends StatelessWidget {
  final String peerId;
  final bool isEncrypted;

  const _MemberTile({
    required this.peerId,
    required this.isEncrypted,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HavenSpacing.sm + 2,
        vertical: HavenSpacing.xxs + 1,
      ),
      child: Row(
        children: [
          // Avatar with online dot
          Stack(
            children: [
              HavenAvatar(peerId: peerId, size: 28),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  decoration: BoxDecoration(
                    color: haven.surface,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(1.5),
                  child: StatusDot(color: haven.success, size: 7),
                ),
              ),
            ],
          ),

          const SizedBox(width: HavenSpacing.sm),

          // Peer ID
          Expanded(
            child: Text(
              peerId.length > 12
                  ? '${peerId.substring(0, 12)}...'
                  : peerId,
              style: HavenTypography.bodySmall.copyWith(
                color: haven.textSecondary,
                fontFamily: 'Consolas',
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Encryption badge
          if (isEncrypted)
            Icon(
              LucideIcons.lock,
              size: 12,
              color: haven.success,
            ),
        ],
      ),
    );
  }
}
