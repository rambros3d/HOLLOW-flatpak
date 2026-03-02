import 'package:flutter/material.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Vertical server icon strip (72px wide) — like Discord's left column.
///
/// Currently shows the Haven home icon and an "add server" placeholder.
/// Server icons will be added in Phase 3.
class ServerStrip extends StatelessWidget {
  const ServerStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: haven.background,
        border: Border(
          right: BorderSide(color: haven.border),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: HavenSpacing.md),

          // Haven home button
          _ServerIcon(
            isHome: true,
            backgroundColor: haven.accent,
            onTap: () {
              // Already on home/DMs — no-op for now.
            },
            child: Text(
              'H',
              style: TextStyle(
                color: haven.textOnAccent,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: HavenSpacing.sm),

          // Short divider
          Container(
            width: 32,
            height: 2,
            decoration: BoxDecoration(
              color: haven.border,
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          // Spacer — server icons go here in Phase 3
          const Spacer(),

          // Add server button
          Padding(
            padding: const EdgeInsets.only(bottom: HavenSpacing.md),
            child: _ServerIcon(
              backgroundColor: haven.elevated,
              tooltip: 'Create or join a server (coming soon)',
              onTap: () {
                // Phase 3 — create/join server flow.
              },
              child: Icon(
                LucideIcons.plus,
                color: haven.accent,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single icon in the server strip.
/// Rounded square by default, animates to pill shape on hover (like Discord).
class _ServerIcon extends StatefulWidget {
  final Widget child;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool isHome;

  const _ServerIcon({
    required this.child,
    required this.backgroundColor,
    this.onTap,
    this.tooltip,
    this.isHome = false,
  });

  @override
  State<_ServerIcon> createState() => _ServerIconState();
}

class _ServerIconState extends State<_ServerIcon> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    // Animate between rounded square and pill on hover.
    final radius = _hovering ? 16.0 : haven.radiusLg;

    Widget icon = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );

    if (widget.tooltip != null) {
      icon = Tooltip(message: widget.tooltip!, child: icon);
    }

    return icon;
  }
}
