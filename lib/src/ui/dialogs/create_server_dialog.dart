import 'package:flutter/material.dart';
import 'package:haven/src/rust/api/crdt.dart' as crdt_api;
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_button.dart';
import 'package:haven/src/ui/components/haven_dialog.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';
import 'package:haven/src/ui/components/haven_text_field.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shows a dialog to join or create a server.
void showCreateServerDialog(BuildContext context) {
  final joinController = TextEditingController();
  final nameController = TextEditingController();

  showHavenDialog(
    context: context,
    builder: (dialogContext) {
      final haven = HavenTheme.of(dialogContext);

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HavenSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, minWidth: 400),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(HavenSpacing.lg),
                decoration: BoxDecoration(
                  color: haven.elevated.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(haven.radiusLg),
                  border: Border.all(
                    color: haven.accent.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button row
                    Align(
                      alignment: Alignment.centerRight,
                      child: HavenPressable(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        borderRadius: BorderRadius.circular(haven.radiusSm),
                        padding: const EdgeInsets.all(HavenSpacing.xs),
                        child: Icon(LucideIcons.x, size: 18, color: haven.textSecondary),
                      ),
                    ),
                    Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side — Join a server
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.logIn, size: 18,
                                  color: haven.accent),
                              const SizedBox(width: HavenSpacing.sm),
                              Text(
                                'Join a Server',
                                style: HavenTypography.subheading.copyWith(
                                  color: haven.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: HavenSpacing.sm),
                          Text(
                            'Paste an invite link or server ID.',
                            style: HavenTypography.caption.copyWith(
                              color: haven.textSecondary,
                            ),
                          ),
                          const SizedBox(height: HavenSpacing.lg),
                          HavenTextField(
                            controller: joinController,
                            hintText: 'haven://join?server=... or ID',
                            autofocus: true,
                            style: HavenTypography.mono.copyWith(
                              color: haven.textPrimary,
                              fontSize: 12,
                            ),
                            onSubmitted: (_) {
                              _handleJoin(dialogContext, joinController);
                            },
                          ),
                          const SizedBox(height: HavenSpacing.md),
                          HavenButton.filled(
                            onPressed: () => _handleJoin(
                                dialogContext, joinController),
                            expand: true,
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                    ),

                    // Vertical divider
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: HavenSpacing.lg),
                      child: SizedBox(
                        height: 180,
                        child: VerticalDivider(
                          color: haven.border,
                          width: 1,
                        ),
                      ),
                    ),

                    // Right side — Create a server
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.plus, size: 18,
                                  color: haven.accent),
                              const SizedBox(width: HavenSpacing.sm),
                              Text(
                                'Create a Server',
                                style: HavenTypography.subheading.copyWith(
                                  color: haven.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: HavenSpacing.sm),
                          Text(
                            'Start your own server. You can invite others later.',
                            style: HavenTypography.caption.copyWith(
                              color: haven.textSecondary,
                            ),
                          ),
                          const SizedBox(height: HavenSpacing.lg),
                          HavenTextField(
                            controller: nameController,
                            hintText: 'My Awesome Server',
                            onSubmitted: (_) {
                              _handleCreate(dialogContext, nameController);
                            },
                          ),
                          const SizedBox(height: HavenSpacing.md),
                          HavenButton.outline(
                            onPressed: () => _handleCreate(
                                dialogContext, nameController),
                            expand: true,
                            child: const Text('Create'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _handleJoin(BuildContext context, TextEditingController controller) {
  final input = controller.text.trim();
  if (input.isEmpty) return;

  // Parse invite link or raw server ID.
  String serverId;
  final uri = Uri.tryParse(input);
  if (uri != null &&
      uri.scheme == 'haven' &&
      uri.queryParameters.containsKey('server')) {
    serverId = uri.queryParameters['server']!;
  } else {
    serverId = input;
  }

  Navigator.of(context).pop();
  crdt_api.joinServer(serverId: serverId);
}

void _handleCreate(
    BuildContext context, TextEditingController controller) async {
  final name = controller.text.trim();
  if (name.isEmpty) return;
  Navigator.of(context).pop();
  await crdt_api.createServer(name: name);
}
