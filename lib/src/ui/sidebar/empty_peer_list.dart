import 'package:flutter/material.dart';
import 'package:hollow/src/core/models/node_status.dart';
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EmptyPeerList extends StatelessWidget {
  final NodeStatus nodeStatus;

  const EmptyPeerList({super.key, required this.nodeStatus});

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final String text;
    final IconData icon;

    switch (nodeStatus) {
      case NodeStatus.connected:
        text = 'Searching for peers\non your local network...';
        icon = LucideIcons.radar;
      case NodeStatus.starting:
        text = 'Starting node...';
        icon = LucideIcons.hourglass;
      case NodeStatus.loading:
        text = 'Loading identity...';
        icon = LucideIcons.user;
      case NodeStatus.error:
        text = 'Failed to start node.\nCheck the error above.';
        icon = LucideIcons.alertCircle;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HollowSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: hollow.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: HollowSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: HollowTypography.bodySmall.copyWith(
                color: hollow.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
