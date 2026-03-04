import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/channel_info.dart';
import 'package:haven/src/core/providers/channel_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_button.dart';
import 'package:haven/src/ui/components/haven_dialog.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';
import 'package:haven/src/ui/components/haven_text_field.dart';
import 'package:haven/src/ui/components/haven_toast.dart';
import 'package:haven/src/ui/dialogs/create_channel_dialog.dart';
import 'package:haven/src/rust/api/crdt.dart' as crdt_api;
import 'package:lucide_icons/lucide_icons.dart';

/// Channels tab — list channels with rename/delete actions.
class ChannelsTab extends ConsumerWidget {
  final String serverId;

  const ChannelsTab({super.key, required this.serverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haven = HavenTheme.of(context);
    final channels = ref.watch(channelListProvider);
    final sorted = channels.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        Expanded(
          child: sorted.isEmpty
              ? Center(
                  child: Text(
                    'No channels yet',
                    style: HavenTypography.body
                        .copyWith(color: haven.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(HavenSpacing.lg),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final channel = sorted[index];
                    return _ChannelRow(
                      channel: channel,
                      serverId: serverId,
                    );
                  },
                ),
        ),

        // Create channel button
        Padding(
          padding: const EdgeInsets.all(HavenSpacing.lg),
          child: HavenButton.outline(
            onPressed: () =>
                showCreateChannelDialog(context, serverId),
            expand: true,
            icon: const Icon(LucideIcons.plus),
            child: const Text('Create Channel'),
          ),
        ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final ChannelInfo channel;
  final String serverId;

  const _ChannelRow({required this.channel, required this.serverId});

  void _rename(BuildContext context) {
    final controller = TextEditingController(text: channel.name);
    showHavenDialog(
      context: context,
      builder: (dialogContext) => HavenDialog(
        title: 'Rename Channel',
        content: HavenTextField(
          controller: controller,
          hintText: 'Channel name',
          autofocus: true,
          onSubmitted: (_) {
            final newName = controller.text.trim();
            if (newName.isNotEmpty && newName != channel.name) {
              crdt_api.renameChannel(
                serverId: serverId,
                channelId: channel.channelId,
                newName: newName,
              );
            }
            Navigator.of(dialogContext).pop();
          },
        ),
        actions: [
          HavenButton.ghost(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          HavenButton.filled(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != channel.name) {
                crdt_api.renameChannel(
                  serverId: serverId,
                  channelId: channel.channelId,
                  newName: newName,
                );
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _delete(BuildContext context) {
    showHavenDialog(
      context: context,
      builder: (dialogContext) => HavenDialog(
        title: 'Delete Channel',
        content: Text(
          'Are you sure you want to delete #${channel.name}? This cannot be undone.',
          style: HavenTypography.body,
        ),
        actions: [
          HavenButton.ghost(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          HavenButton.danger(
            onPressed: () {
              crdt_api.removeChannel(
                serverId: serverId,
                channelId: channel.channelId,
              );
              Navigator.of(dialogContext).pop();
              HavenToast.show(
                context,
                'Channel #${channel.name} deleted',
                type: HavenToastType.info,
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: HavenSpacing.xs),
      child: HavenPressable(
        subtle: true,
        onTap: () => _rename(context),
        borderRadius: BorderRadius.circular(haven.radiusMd),
        hoverColor: haven.elevated,
        padding: const EdgeInsets.symmetric(
          horizontal: HavenSpacing.md,
          vertical: HavenSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.hash, size: 16, color: haven.textSecondary),
            const SizedBox(width: HavenSpacing.sm),
            Expanded(
              child: Text(
                channel.name,
                style: HavenTypography.body.copyWith(color: haven.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            HavenPressable(
              onTap: () => _rename(context),
              borderRadius: BorderRadius.circular(haven.radiusSm),
              padding: const EdgeInsets.all(HavenSpacing.xs),
              child: Icon(LucideIcons.pencil, size: 14, color: haven.textSecondary),
            ),
            const SizedBox(width: HavenSpacing.xs),
            HavenPressable(
              onTap: () => _delete(context),
              borderRadius: BorderRadius.circular(haven.radiusSm),
              padding: const EdgeInsets.all(HavenSpacing.xs),
              child: Icon(LucideIcons.trash2, size: 14, color: haven.error),
            ),
          ],
        ),
      ),
    );
  }
}
