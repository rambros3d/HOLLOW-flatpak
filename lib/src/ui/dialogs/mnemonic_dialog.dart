import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';

/// Shows the 24-word recovery phrase dialog.
void showMnemonicDialog(BuildContext context, String mnemonic) {
  final haven = HavenTheme.of(context);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: haven.elevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(haven.radiusLg),
      ),
      title: Text(
        'Your Recovery Phrase',
        style: HavenTypography.heading.copyWith(color: haven.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This is your 24-word recovery phrase. Write it down and keep '
            'it safe. You will need it to restore your identity if you lose '
            'access to this device.',
            style: HavenTypography.body.copyWith(color: haven.textSecondary),
          ),
          const SizedBox(height: HavenSpacing.lg),
          Container(
            padding: const EdgeInsets.all(HavenSpacing.md),
            decoration: BoxDecoration(
              color: haven.background,
              borderRadius: BorderRadius.circular(haven.radiusMd),
              border: Border.all(color: haven.warning.withValues(alpha: 0.4)),
            ),
            child: SelectableText(
              mnemonic,
              style: HavenTypography.mono.copyWith(
                color: haven.textPrimary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: HavenSpacing.md),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: mnemonic));
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Copied to clipboard',
                        style: HavenTypography.body
                            .copyWith(color: haven.textPrimary),
                      ),
                      backgroundColor: haven.elevated,
                    ),
                  );
                },
                icon: Icon(Icons.copy, size: 16, color: haven.accent),
                label: Text(
                  'Copy',
                  style:
                      HavenTypography.label.copyWith(color: haven.accent),
                ),
              ),
            ],
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
            'I\'ve saved it',
            style: HavenTypography.label
                .copyWith(color: haven.textOnAccent),
          ),
        ),
      ],
    ),
  );
}
