import 'package:flutter/material.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/animations/startup_reveal.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

/// Custom 32px title bar replacing the native Windows chrome.
///
/// Layout: [Haven branding] [drag area ────────] [─] [□] [✕]
class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final brandReveal = StartupRevealScope.interval(context, 0.0, 0.15);
    final buttonsReveal = StartupRevealScope.interval(context, 0.08, 0.20);

    Widget branding = Padding(
      padding: const EdgeInsets.only(left: HavenSpacing.lg),
      child: Text(
        'Haven',
        style: HavenTypography.label.copyWith(
          color: haven.accent,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );

    if (brandReveal != null) {
      branding = AnimatedBuilder(
        animation: brandReveal,
        builder: (context, child) {
          return Opacity(opacity: brandReveal.value, child: child);
        },
        child: branding,
      );
    }

    Widget buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _MinimizeButton(),
        _MaximizeButton(),
        _CloseButton(),
      ],
    );

    if (buttonsReveal != null) {
      buttons = AnimatedBuilder(
        animation: buttonsReveal,
        builder: (context, child) {
          return Opacity(opacity: buttonsReveal.value, child: child);
        },
        child: buttons,
      );
    }

    return Container(
      height: 32,
      color: haven.background,
      child: Row(
        children: [
          branding,
          const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
          buttons,
        ],
      ),
    );
  }
}

/// Base for window control buttons — no Material ripple, just instant color.
class _WindowButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color? hoverColor;
  final Widget child;

  const _WindowButton({
    required this.onTap,
    required this.child,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final bgColor = _hovering
        ? (widget.hoverColor ?? haven.elevated)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 46,
          height: 32,
          color: bgColor,
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

class _MinimizeButton extends StatelessWidget {
  const _MinimizeButton();

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return _WindowButton(
      onTap: () => windowManager.minimize(),
      child: Icon(
        LucideIcons.minus,
        size: 16,
        color: haven.textSecondary,
      ),
    );
  }
}

class _MaximizeButton extends StatefulWidget {
  const _MaximizeButton();

  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return _WindowButton(
      onTap: () async {
        if (_isMaximized) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Icon(
        _isMaximized ? LucideIcons.columns : LucideIcons.square,
        size: 14,
        color: haven.textSecondary,
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return _WindowButton(
      onTap: () => windowManager.close(),
      hoverColor: const Color(0xFFE81123), // Standard red close hover
      child: Icon(
        LucideIcons.x,
        size: 16,
        color: haven.textSecondary,
      ),
    );
  }
}
