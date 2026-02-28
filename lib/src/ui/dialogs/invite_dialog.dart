import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';

/// Shows the invite link dialog after creating a room.
void showInviteDialog(
    BuildContext context, String link, String roomCode) {
  final haven = HavenTheme.of(context);

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: haven.elevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(haven.radiusLg),
      ),
      title: Text(
        'Invite Link Created',
        style: HavenTypography.heading.copyWith(color: haven.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share this link to invite someone to your room:',
            style: HavenTypography.body.copyWith(color: haven.textSecondary),
          ),
          const SizedBox(height: HavenSpacing.lg),
          Container(
            padding: const EdgeInsets.all(HavenSpacing.md),
            decoration: BoxDecoration(
              color: haven.background,
              borderRadius: BorderRadius.circular(haven.radiusMd),
              border: Border.all(
                color: haven.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    link,
                    style: HavenTypography.mono.copyWith(
                      color: haven.accent,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 18, color: haven.accent),
                  tooltip: 'Copy link',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Invite link copied to clipboard',
                          style: HavenTypography.body
                              .copyWith(color: haven.textPrimary),
                        ),
                        backgroundColor: haven.elevated,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: HavenSpacing.md),
          Text(
            'Room code: $roomCode',
            style: HavenTypography.caption.copyWith(
              color: haven.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: haven.accent,
            foregroundColor: haven.textOnAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(haven.radiusMd),
            ),
          ),
          child: Text(
            'Done',
            style: HavenTypography.label
                .copyWith(color: haven.textOnAccent),
          ),
        ),
      ],
    ),
  );
}
