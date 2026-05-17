import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hollow/src/ui/app.dart' show hollowNavigatorKey;

import 'annotation_canvas.dart';
import 'annotation_controller.dart';
import 'annotation_toolbar.dart';

/// Self-contained transparent overlay that lets the user draw freehand
/// strokes, straight lines and arrows on top of the Hollow window. Toggled
/// via [AnnotationOverlay.toggle].
///
/// Drawing surface fills the entire window. The toolbar floats at the top
/// center. Keyboard: Esc to close, ⌘Z / Ctrl+Z to undo, ⇧⌘Z / Ctrl+⇧Z redo.
///
/// Independent of any other Hollow widget — only depends on Flutter SDK.
class AnnotationOverlay {
  AnnotationOverlay._();

  static OverlayEntry? _entry;
  static AnnotationController? _controller;

  /// Whether the overlay is currently shown.
  static bool get isShown => _entry != null;

  /// Toggle the overlay open/closed using the nearest [Overlay].
  static void toggle(BuildContext context) {
    if (isShown) {
      hide();
    } else {
      show(context);
    }
  }

  /// Show the overlay. Tries the local context first, then falls back to
  /// the global [hollowNavigatorKey] — needed when the caller (e.g. the
  /// title-bar button) sits above the [Navigator] and has no Overlay in
  /// its tree.
  static void show(BuildContext context) {
    if (isShown) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true) ??
        hollowNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _controller = AnnotationController();
    _entry = OverlayEntry(
      builder: (_) => _AnnotationOverlayLayer(
        controller: _controller!,
        onClose: hide,
      ),
    );
    overlay.insert(_entry!);
  }

  /// Hide the overlay and dispose the controller.
  static void hide() {
    _entry?.remove();
    _entry = null;
    _controller?.dispose();
    _controller = null;
  }
}

class _AnnotationOverlayLayer extends StatefulWidget {
  final AnnotationController controller;
  final VoidCallback onClose;

  const _AnnotationOverlayLayer({
    required this.controller,
    required this.onClose,
  });

  @override
  State<_AnnotationOverlayLayer> createState() =>
      _AnnotationOverlayLayerState();
}

class _AnnotationOverlayLayerState extends State<_AnnotationOverlayLayer> {
  final FocusNode _focus = FocusNode(skipTraversal: true);

  @override
  void initState() {
    super.initState();
    // Grab focus so keyboard shortcuts (Esc, Undo) reach us.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ && (isMeta || isCtrl)) {
      if (isShift) {
        widget.controller.redo();
      } else {
        widget.controller.undo();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Drawing surface. Opaque hit-test so input doesn't leak through
            // to the app, but visually transparent.
            AnnotationCanvas(controller: widget.controller),
            // Toolbar pinned to top-center. IgnorePointer is off so taps on
            // the toolbar work; Listener inside AnnotationCanvas covers the
            // rest of the surface.
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: AnnotationToolbar(
                  controller: widget.controller,
                  onClose: widget.onClose,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
