import 'package:flutter/material.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';

/// Displays emoji reaction pills below a message.
/// Tapping a pill toggles the current user's reaction.
/// Sorted by count descending, then by earliest addition (chronological).
class ReactionBar extends StatelessWidget {
  /// Emoji -> list of peer IDs who reacted.
  final Map<String, List<String>> reactions;

  /// The current user's peer ID, to highlight their reactions.
  final String localPeerId;

  /// Called when the user taps a reaction pill to toggle it.
  final void Function(String emoji) onToggleReaction;

  const ReactionBar({
    super.key,
    required this.reactions,
    required this.localPeerId,
    required this.onToggleReaction,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final haven = HavenTheme.of(context);

    // Sort by count descending. Entries maintain insertion order for tie-breaking.
    final sorted = reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: sorted.map((entry) {
          final emoji = entry.key;
          final reactors = entry.value;
          final isMine = reactors.contains(localPeerId);

          return HavenPressable(
            onTap: () => onToggleReaction(emoji),
            borderRadius: BorderRadius.circular(12),
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMine
                    ? haven.accent.withValues(alpha: 0.15)
                    : haven.elevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMine
                      ? haven.accent.withValues(alpha: 0.4)
                      : haven.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text(
                    reactors.length.toString(),
                    style: HavenTypography.caption.copyWith(
                      color: isMine ? haven.accent : haven.textSecondary,
                      fontSize: 11,
                      fontWeight: isMine ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
