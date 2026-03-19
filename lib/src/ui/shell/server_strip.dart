import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/providers/channel_provider.dart';
import 'package:hollow/src/core/providers/selected_peer_provider.dart';
import 'package:hollow/src/core/providers/server_provider.dart';
import 'package:hollow/src/core/providers/notification_provider.dart';
import 'package:hollow/src/core/providers/unread_provider.dart';
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/ui/animations/hollow_curves.dart';
import 'package:hollow/src/ui/components/hollow_tooltip.dart';
import 'package:hollow/src/ui/dialogs/create_server_dialog.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Vertical server icon strip (72px wide) — like Discord's left column.
///
/// Shows the Hollow home icon, server icons from [serverListProvider],
/// and an "add server" button at the bottom.
class ServerStrip extends ConsumerStatefulWidget {
  const ServerStrip({super.key});

  @override
  ConsumerState<ServerStrip> createState() => _ServerStripState();
}

class _ServerStripState extends ConsumerState<ServerStrip> {
  /// Tracks server IDs that existed on first build — these skip the
  /// entrance animation so the strip doesn't bounce on app startup.
  Set<String>? _initialServerIds;

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final servers = ref.watch(serverListProvider);
    final selectedServerId = ref.watch(selectedServerProvider);

    // Capture initial server IDs on first build.
    _initialServerIds ??= servers.keys.toSet();

    final serverEntries = servers.values.toList();

    final unreadState = ref.watch(unreadProvider);

    // Home button — show unread count if any unmuted DM has unreads.
    final notifSettings = ref.watch(notificationSettingsProvider.notifier);
    int dmUnreadTotal = 0;
    for (final entry in unreadState.dmUnreadCounts.entries) {
      if (notifSettings.isDmEnabled(entry.key)) {
        dmUnreadTotal += entry.value;
      }
    }
    Widget homeIcon = _ServerIconWithIndicator(
      isSelected: selectedServerId == null,
      unreadCount: selectedServerId != null ? dmUnreadTotal : 0,
      child: _ServerIcon(
        isSelected: selectedServerId == null,
        backgroundColor: hollow.accent,
        onTap: () {
          ref.read(selectedServerProvider.notifier).state = null;
          ref.read(channelListProvider.notifier).clear();
          ref.read(selectedChannelProvider.notifier).state = null;
          ref.read(serverSettingsOpenProvider.notifier).state = false;
        },
        child: Text(
          'H',
          style: TextStyle(
            color: hollow.textOnAccent,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    // Short divider
    Widget divider = Container(
      width: 32,
      height: 2,
      decoration: BoxDecoration(
        color: hollow.border,
        borderRadius: BorderRadius.circular(1),
      ),
    );

    // Add server button
    Widget addButton = Padding(
      padding: const EdgeInsets.only(bottom: HollowSpacing.md),
      child: _ServerIcon(
        backgroundColor: hollow.elevated,
        tooltip: 'Create a server',
        onTap: () => showCreateServerDialog(context),
        child: Icon(
          LucideIcons.plus,
          color: hollow.accent,
          size: 24,
        ),
      ),
    );

    return Container(
      width: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            hollow.background,
            Color.lerp(hollow.background, hollow.accent, 0.08)!,
          ],
        ),
        border: Border(
          right: BorderSide(color: hollow.border),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: HollowSpacing.md),
          homeIcon,
          const SizedBox(height: HollowSpacing.sm),
          divider,
          const SizedBox(height: HollowSpacing.sm),

          // Server icon list
          Expanded(
            child: ListView.builder(
              itemCount: serverEntries.length,
              padding: const EdgeInsets.symmetric(vertical: HollowSpacing.xs),
              itemBuilder: (context, index) {
                final server = serverEntries[index];
                final isSelected = server.serverId == selectedServerId;
                final isNew =
                    !_initialServerIds!.contains(server.serverId);

                final isServerMuted = ref.watch(notificationSettingsProvider.notifier)
                    .isServerMuted(server.serverId);
                final serverUnreads = isServerMuted
                    ? 0
                    : ref.watch(unreadProvider.notifier)
                        .serverUnreadCount(server.serverId);
                Widget icon = _ServerIconWithIndicator(
                  isSelected: isSelected,
                  unreadCount: isSelected ? 0 : serverUnreads,
                  child: _ServerIcon(
                    isSelected: isSelected,
                    backgroundColor: _colorFromId(server.serverId),
                    tooltip: server.name,
                    onTap: () async {
                      ref.read(selectedServerProvider.notifier).state =
                          server.serverId;
                      ref.read(selectedPeerProvider.notifier).state = null;
                      ref.read(serverSettingsOpenProvider.notifier).state =
                          false;

                      // Restore last viewed channel, or auto-select first.
                      final lastChannels =
                          ref.read(lastChannelPerServerProvider);
                      final lastChannel = lastChannels[server.serverId];

                      await ref
                          .read(channelListProvider.notifier)
                          .loadForServer(server.serverId);
                      ref
                          .read(channelLayoutProvider.notifier)
                          .loadForServer(server.serverId);

                      final channels = ref.read(channelListProvider);
                      String? channelToSelect;
                      if (lastChannel != null &&
                          channels.containsKey(lastChannel)) {
                        channelToSelect = lastChannel;
                      } else if (channels.isNotEmpty) {
                        channelToSelect = channels.keys.first;
                      }
                      ref.read(selectedChannelProvider.notifier).state =
                          channelToSelect;
                      // Save auto-selected channel as last viewed.
                      if (channelToSelect != null) {
                        final map = Map<String, String>.from(
                            ref.read(lastChannelPerServerProvider));
                        map[server.serverId] = channelToSelect;
                        ref.read(lastChannelPerServerProvider.notifier)
                            .state = map;
                      }
                    },
                    child: Text(
                      _initialsFromName(server.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );

                // Animate newly created servers (after app startup).
                if (isNew) {
                  icon = _ScaleBounceEntry(
                    key: ValueKey('bounce-${server.serverId}'),
                    child: icon,
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: HollowSpacing.sm),
                  child: icon,
                );
              },
            ),
          ),

          addButton,
        ],
      ),
    );
  }
}

/// Deterministic color from an ID string (same logic as HollowAvatar).
Color _colorFromId(String id) {
  final hash = id.hashCode;
  final hue = (hash % 360).abs().toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.5, 0.45).toColor();
}

/// Extract 1–2 letter initials from a server name.
String _initialsFromName(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.length >= 2) {
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
  return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
}

/// Wraps a server icon with a Discord-style left-edge selection indicator
/// and an optional unread count badge (bottom-right).
class _ServerIconWithIndicator extends StatefulWidget {
  final bool isSelected;
  final int unreadCount;
  final Widget child;

  const _ServerIconWithIndicator({
    required this.isSelected,
    required this.child,
    this.unreadCount = 0,
  });

  @override
  State<_ServerIconWithIndicator> createState() =>
      _ServerIconWithIndicatorState();
}

class _ServerIconWithIndicatorState
    extends State<_ServerIconWithIndicator> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);

    // Indicator height: selected=36, hovering=20, default=0.
    final indicatorHeight =
        widget.isSelected ? 36.0 : (_hovering ? 20.0 : 0.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: SizedBox(
        width: 72,
        height: 48,
        child: Row(
          children: [
            // Left-edge pill indicator
            AnimatedContainer(
              duration: HollowDurations.fast,
              curve: HollowCurves.enter,
              width: 3,
              height: indicatorHeight,
              decoration: BoxDecoration(
                color: hollow.textPrimary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
            const Spacer(),
            // Stack for unread badge overlay.
            Stack(
              clipBehavior: Clip.none,
              children: [
                widget.child,
                if (widget.unreadCount > 0)
                  Positioned(
                    right: -6,
                    bottom: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: hollow.error,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hollow.background,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.unreadCount > 99
                            ? '99+'
                            : '${widget.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// A single icon in the server strip.
/// Rounded square by default, animates to pill shape on hover or when selected.
class _ServerIcon extends StatefulWidget {
  final Widget child;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool isSelected;

  const _ServerIcon({
    required this.child,
    required this.backgroundColor,
    this.onTap,
    this.tooltip,
    this.isSelected = false,
  });

  @override
  State<_ServerIcon> createState() => _ServerIconState();
}

class _ServerIconState extends State<_ServerIcon> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);

    // Stay pill-shaped when selected or hovering.
    final radius =
        (_hovering || widget.isSelected) ? 16.0 : hollow.radiusLg;

    // Hover brightens the background slightly.
    final effectiveBg = _hovering && !widget.isSelected
        ? Color.lerp(widget.backgroundColor, hollow.accent, 0.15)!
        : widget.backgroundColor;

    Widget icon = MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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
            color: effectiveBg,
            borderRadius: BorderRadius.circular(radius),
            border: widget.isSelected
                ? Border.all(
                    color: hollow.accent.withValues(alpha: 0.6),
                    width: 2,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );

    if (widget.tooltip != null) {
      icon = HollowTooltip(message: widget.tooltip!, child: icon);
    }

    return icon;
  }
}

/// Plays a scale-bounce animation when first built.
/// Used for newly created server icons.
class _ScaleBounceEntry extends StatefulWidget {
  final Widget child;

  const _ScaleBounceEntry({super.key, required this.child});

  @override
  State<_ScaleBounceEntry> createState() => _ScaleBounceEntryState();
}

class _ScaleBounceEntryState extends State<_ScaleBounceEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.1), weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.1, end: 0.95), weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 0.95, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
