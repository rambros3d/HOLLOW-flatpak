import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/models/server_info.dart';
import 'package:hollow/src/core/providers/channel_provider.dart';
import 'package:hollow/src/core/providers/server_provider.dart';
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:hollow/src/ui/components/hollow_button.dart';
import 'package:hollow/src/ui/components/hollow_dialog.dart';
import 'package:hollow/src/ui/components/hollow_toast.dart';
import 'package:hollow/src/rust/api/crdt.dart' as crdt_api;
import 'package:lucide_icons/lucide_icons.dart';

/// Danger Zone tab — delete server.
class DangerZoneTab extends ConsumerWidget {
  final ServerInfo server;

  const DangerZoneTab({super.key, required this.server});

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showHollowDialog(
      context: context,
      builder: (dialogContext) => HollowDialog(
        title: 'Delete Server',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${server.name}"?',
              style: HollowTypography.body,
            ),
            const SizedBox(height: HollowSpacing.sm),
            Text(
              'This action cannot be undone. All channels and messages will be permanently deleted.',
              style: HollowTypography.bodySmall,
            ),
          ],
        ),
        actions: [
          HollowButton.ghost(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          HollowButton.danger(
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
        HollowToast.show(
          context,
          'Server "${server.name}" deleted',
          type: HollowToastType.info,
        );
      }
    } catch (e) {
      if (context.mounted) {
        HollowToast.show(
          context,
          'Failed to delete server: $e',
          type: HollowToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hollow = HollowTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(HollowSpacing.xl),
      children: [
        // Danger zone header
        Container(
          padding: const EdgeInsets.all(HollowSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: hollow.error.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(hollow.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.alertTriangle,
                      size: 18, color: hollow.error),
                  const SizedBox(width: HollowSpacing.sm),
                  Text(
                    'Danger Zone',
                    style: HollowTypography.subheading
                        .copyWith(color: hollow.error),
                  ),
                ],
              ),
              const SizedBox(height: HollowSpacing.lg),

              // Delete server
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete this server',
                          style: HollowTypography.body
                              .copyWith(color: hollow.textPrimary),
                        ),
                        const SizedBox(height: HollowSpacing.xxs),
                        Text(
                          'Once deleted, all data is permanently removed.',
                          style: HollowTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  HollowButton.danger(
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
