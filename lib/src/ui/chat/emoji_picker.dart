import 'package:flutter/material.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';

/// Curated set of ~30 commonly used reaction emojis.
const kReactionEmojis = [
  '\u{1F44D}', // thumbs up
  '\u{2764}\u{FE0F}', // red heart
  '\u{1F602}', // face with tears of joy
  '\u{1F525}', // fire
  '\u{1F44F}', // clapping hands
  '\u{1F389}', // party popper
  '\u{1F60D}', // heart eyes
  '\u{1F914}', // thinking face
  '\u{1F60E}', // sunglasses
  '\u{1F622}', // crying face
  '\u{1F621}', // angry face
  '\u{1F631}', // screaming face
  '\u{1F4AF}', // hundred points
  '\u{1F440}', // eyes
  '\u{1F64F}', // folded hands (pray)
  '\u{2705}', // check mark
  '\u{274C}', // cross mark
  '\u{1F680}', // rocket
  '\u{1F31F}', // glowing star
  '\u{1F48E}', // gem stone
  '\u{1F49C}', // purple heart
  '\u{1F499}', // blue heart
  '\u{1F49A}', // green heart
  '\u{1F60A}', // smiling face with eyes
  '\u{1F642}', // slightly smiling face
  '\u{1F92F}', // exploding head
  '\u{1F973}', // partying face
  '\u{1F921}', // clown face
  '\u{1F480}', // skull
  '\u{1F4A9}', // pile of poo
];

/// Shows a small emoji picker overlay anchored to a given position.
/// Returns the selected emoji string or null if dismissed.
void showEmojiPicker({
  required BuildContext context,
  required Offset anchorPosition,
  required void Function(String emoji) onSelect,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _EmojiPickerOverlay(
      anchorPosition: anchorPosition,
      onSelect: (emoji) {
        entry.remove();
        entry.dispose();
        onSelect(emoji);
      },
      onDismiss: () {
        entry.remove();
        entry.dispose();
      },
    ),
  );

  overlay.insert(entry);
}

class _EmojiPickerOverlay extends StatelessWidget {
  final Offset anchorPosition;
  final void Function(String emoji) onSelect;
  final VoidCallback onDismiss;

  const _EmojiPickerOverlay({
    required this.anchorPosition,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final screenSize = MediaQuery.of(context).size;

    const pickerWidth = 280.0;
    const pickerHeight = 220.0;

    // Position: try above the anchor, left-aligned. Clamp to screen.
    double left = anchorPosition.dx - pickerWidth + 30;
    double top = anchorPosition.dy - pickerHeight - 8;

    if (left < 8) left = 8;
    if (left + pickerWidth > screenSize.width - 8) {
      left = screenSize.width - pickerWidth - 8;
    }
    if (top < 8) {
      top = anchorPosition.dy + 30;
    }

    return Stack(
      children: [
        // Dismiss barrier.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: pickerWidth,
              height: pickerHeight,
              decoration: BoxDecoration(
                color: haven.surface,
                borderRadius: BorderRadius.circular(haven.radiusMd),
                border: Border.all(color: haven.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(haven.radiusMd),
                child: GridView.builder(
                  padding: const EdgeInsets.all(HavenSpacing.sm),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: kReactionEmojis.length,
                  itemBuilder: (context, index) {
                    final emoji = kReactionEmojis[index];
                    return HavenPressable(
                      onTap: () => onSelect(emoji),
                      borderRadius: BorderRadius.circular(haven.radiusSm),
                      padding: const EdgeInsets.all(4),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
