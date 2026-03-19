import 'package:flutter/material.dart';
import 'package:hollow/src/rust/api/crdt.dart' as crdt_api;
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:hollow/src/ui/components/hollow_button.dart';
import 'package:hollow/src/ui/components/hollow_dialog.dart';
import 'package:hollow/src/ui/components/hollow_text_field.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shows a dialog to create a new channel in a server.
void showCreateChannelDialog(BuildContext context, String serverId) {
  final nameController = TextEditingController();

  showHollowDialog(
    context: context,
    builder: (dialogContext) {
      return HollowDialog(
        title: 'Create Channel',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a name for your new channel.',
              style: HollowTypography.body.copyWith(
                color: HollowTheme.of(dialogContext).textSecondary,
              ),
            ),
            const SizedBox(height: HollowSpacing.lg),
            HollowTextField(
              controller: nameController,
              hintText: 'general',
              autofocus: true,
              prefixIcon: const Icon(LucideIcons.hash),
              onSubmitted: (_) async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(dialogContext).pop();
                await crdt_api.createChannel(
                  serverId: serverId,
                  name: name,
                  category: null,
                );
              },
            ),
          ],
        ),
        actions: [
          HollowButton.ghost(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          HollowButton.filled(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop();
              await crdt_api.createChannel(
                serverId: serverId,
                name: name,
                category: null,
              );
            },
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
}
