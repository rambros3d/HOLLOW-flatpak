import 'package:flutter/material.dart';
import 'package:haven/src/core/models/node_status.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';

class EmptyPeerList extends StatelessWidget {
  final NodeStatus nodeStatus;

  const EmptyPeerList({super.key, required this.nodeStatus});

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final String text;
    final IconData icon;

    switch (nodeStatus) {
      case NodeStatus.connected:
        text = 'Searching for peers\non your local network...';
        icon = Icons.radar;
      case NodeStatus.starting:
        text = 'Starting node...';
        icon = Icons.hourglass_top;
      case NodeStatus.loading:
        text = 'Loading identity...';
        icon = Icons.person_outline;
      case NodeStatus.error:
        text = 'Failed to start node.\nCheck the error above.';
        icon = Icons.error_outline;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HavenSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: haven.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: HavenSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: HavenTypography.bodySmall.copyWith(
                color: haven.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
