import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'annotation_overlay.dart';

/// Wraps [child] with a global keyboard shortcut (⌘⇧A on macOS,
/// Ctrl+Shift+A elsewhere) that toggles the [AnnotationOverlay].
///
/// Drop this directly under [MaterialApp.builder] so the shortcut works
/// everywhere in the app without depending on focus.
class AnnotationOverlayShortcut extends StatelessWidget {
  final Widget child;
  const AnnotationOverlayShortcut({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true, shift: true):
            const _ToggleAnnotationIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true, shift: true):
            const _ToggleAnnotationIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ToggleAnnotationIntent:
              CallbackAction<_ToggleAnnotationIntent>(onInvoke: (_) {
            AnnotationOverlay.toggle(context);
            return null;
          }),
        },
        child: Focus(autofocus: false, child: child),
      ),
    );
  }
}

class _ToggleAnnotationIntent extends Intent {
  const _ToggleAnnotationIntent();
}
