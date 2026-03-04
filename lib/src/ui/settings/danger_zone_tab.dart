import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/server_info.dart';
import 'package:haven/src/core/providers/channel_provider.dart';
import 'package:haven/src/core/providers/server_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_button.dart';
import 'package:haven/src/ui/components/haven_dialog.dart';
import 'package:haven/src/ui/components/haven_toast.dart';
import 'package:haven/src/rust/api/crdt.dart' as crdt_api;
import 'package:lucide_icons/lucide_icons.dart';

/// Danger Zone tab — delete server.
class DangerZoneTab extends ConsumerWidget {
  final ServerInfo server;

  const DangerZoneTab({super.key, required this.server});

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showHavenDialog(
      context: context,
      builder: (dialogContext) => HavenDialog(
        title: 'Delete Server',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${server.name}"?',
              style: HavenTypography.body,
            ),
            const SizedBox(height: HavenSpacing.sm),
            Text(
              'This action cannot be undone. All channels and messages will be permanently deleted.',
              style: HavenTypography.bodySmall,
            ),
          ],
        ),
        actions: [
          HavenButton.ghost(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          HavenButton.danger(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteServer(context, ref);
            },
            child: const Text('Delete Server'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteServer(BuildContext context, WidgetRef ref) async {
    try {
      await crdt_api.deleteServer(serverId: server.serverId);
      // Navigate away from settings
      ref.read(serverSettingsOpenProvider.notifier).state = false;
      ref.read(selectedServerProvider.notifier).state = null;
      ref.read(selectedChannelProvider.notifier).state = null;
      ref.read(channelListProvider.notifier).clear();
      if (context.mounted) {
        HavenToast.show(
          context,
          'Server "${server.name}" deleted',
          type: HavenToastType.info,
        );
      }
    } catch (e) {
      if (context.mounted) {
        HavenToast.show(
          context,
          'Failed to delete server: $e',
          type: HavenToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haven = HavenTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(HavenSpacing.xl),
      children: [
        // Danger zone header
        Container(
          padding: const EdgeInsets.all(HavenSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: haven.error.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(haven.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.alertTriangle,
                      size: 18, color: haven.error),
                  const SizedBox(width: HavenSpacing.sm),
                  Text(
                    'Danger Zone',
                    style: HavenTypography.subheading
                        .copyWith(color: haven.error),
                  ),
                ],
              ),
              const SizedBox(height: HavenSpacing.lg),

              // Delete server
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete this server',
                          style: HavenTypography.body
                              .copyWith(color: haven.textPrimary),
                        ),
                        const SizedBox(height: HavenSpacing.xxs),
                        Text(
                          'Once deleted, all data is permanently removed.',
                          style: HavenTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  HavenButton.danger(
                    onPressed: () => _confirmDelete(context, ref),
                    icon: const Icon(LucideIcons.trash2),
                    child: const Text('Delete Server'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
