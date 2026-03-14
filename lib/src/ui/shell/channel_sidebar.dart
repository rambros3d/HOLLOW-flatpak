import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:haven/src/core/models/channel_info.dart';
import 'package:haven/src/core/models/chat_message.dart';
import 'package:haven/src/core/models/node_status.dart';
import 'package:haven/src/core/models/peer_info.dart';
import 'package:haven/src/core/models/server_info.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/animations/haven_curves.dart';
import 'package:haven/src/ui/animations/reveal_widgets.dart';
import 'package:haven/src/ui/animations/selection_shimmer.dart';
import 'package:haven/src/ui/animations/startup_reveal.dart';
import 'package:haven/src/ui/components/haven_button.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';
import 'package:haven/src/ui/components/haven_text_field.dart';
import 'package:haven/src/ui/components/haven_toast.dart';
import 'package:haven/src/ui/components/haven_tooltip.dart';
import 'package:haven/src/ui/dialogs/invite_dialog.dart';
import 'package:haven/src/ui/shell/user_bar.dart';
import 'package:haven/src/ui/sidebar/empty_peer_list.dart';
import 'package:haven/src/ui/sidebar/peer_card.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Channel / DM sidebar (240px). Supports two modes:
///
/// **Home mode** (`selectedServer == null`): room controls + peer list.
/// **Server mode** (`selectedServer != null`): server name header + channel list.
class ChannelSidebar extends StatelessWidget {
  // -- Home mode props --
  final Map<String, PeerInfo> peers;
  final Map<String, List<ChatMessage>> chatHistory;
  final String? selectedPeerId;
  final NodeStatus nodeStatus;
  final ValueChanged<String> onPeerSelected;
  final ChatMessage? Function(String) lastMessage;
  final String Function(DateTime) formatTime;
  final String? activeRoom;
  final TextEditingController roomController;
  final Future<void> Function(String) onJoinRoom;
  final VoidCallback onCreateInvite;

  // -- Server mode props --
  final ServerInfo? selectedServer;
  final Map<String, ChannelInfo> channels;
  final String? selectedChannelId;
  final ValueChanged<String> onChannelSelected;
  final VoidCallback onCreateChannel;
  final VoidCallback onOpenSettings;
  final bool canManageChannels;
  final String channelLayoutJson;

  /// Fixed width for desktop/tablet. Pass null on mobile to fill available space.
  final double? width;

  const ChannelSidebar({
    super.key,
    required this.peers,
    required this.chatHistory,
    required this.selectedPeerId,
    required this.nodeStatus,
    required this.onPeerSelected,
    required this.lastMessage,
    required this.formatTime,
    required this.activeRoom,
    required this.roomController,
    required this.onJoinRoom,
    required this.onCreateInvite,
    this.selectedServer,
    this.channels = const {},
    this.selectedChannelId,
    this.onChannelSelected = _noop,
    this.onCreateChannel = _noopVoid,
    this.onOpenSettings = _noopVoid,
    this.canManageChannels = false,
    this.channelLayoutJson = '[]',
    this.width = 240,
  });

  static void _noop(String _) {}
  static void _noopVoid() {}

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final sidebarReveal =
        StartupRevealScope.interval(context, 0.12, 0.30);
    final userBarReveal =
        StartupRevealScope.interval(context, 0.50, 0.60);

    Widget userBar = const UserBar();
    if (userBarReveal != null) {
      userBar = FadeTransition(
        opacity: userBarReveal,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(userBarReveal),
          child: userBar,
        ),
      );
    }

    Widget sidebar = Container(
      width: width,
      decoration: BoxDecoration(
        color: haven.surface,
        border: Border(
          right: BorderSide(color: haven.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — crossfade between server name and "Direct Messages"
          AnimatedSwitcher(
            duration: HavenDurations.fast,
            child: _buildHeader(context, haven),
          ),

          // Content — crossfade between server channels and home/DM view
          Expanded(
            child: AnimatedSwitcher(
              duration: HavenDurations.normal,
              switchInCurve: HavenCurves.enter,
              switchOutCurve: HavenCurves.exit,
              child: selectedServer != null
                  ? _ServerContent(
                      key: ValueKey('server-${selectedServer!.serverId}'),
                      haven: haven,
                      channels: channels,
                      selectedChannelId: selectedChannelId,
                      onChannelSelected: onChannelSelected,
                      onCreateChannel: onCreateChannel,
                      canManageChannels: canManageChannels,
                      channelLayoutJson: channelLayoutJson,
                    )
                  : _HomeContent(
                      key: const ValueKey('home'),
                      haven: haven,
                      context: context,
                      peers: peers,
                      selectedPeerId: selectedPeerId,
                      nodeStatus: nodeStatus,
                      onPeerSelected: onPeerSelected,
                      lastMessage: lastMessage,
                      formatTime: formatTime,
                      activeRoom: activeRoom,
                      roomController: roomController,
                      onJoinRoom: onJoinRoom,
                      onCreateInvite: onCreateInvite,
                    ),
            ),
          ),

          // User bar at bottom
          userBar,
        ],
      ),
    );

    return RevealClip(
      animation: sidebarReveal,
      axis: Axis.horizontal,
      alignment: Alignment.centerLeft,
      child: sidebar,
    );
  }

  Widget _buildHeader(BuildContext context, HavenTheme haven) {
    final label = selectedServer?.name ?? 'Direct Messages';
    final headerTextReveal =
        StartupRevealScope.interval(context, 0.25, 0.40);

    return Container(
      key: ValueKey('header-$label'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: HavenSpacing.lg),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: haven.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TypewriterText(
              text: label,
              animation: headerTextReveal,
              style: HavenTypography.subheading.copyWith(
                color: haven.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selectedServer != null) ...[
            HavenTooltip(
              message: 'Invite people',
              child: HavenPressable(
                onTap: () {
                  final link =
                      'haven://join?server=${selectedServer!.serverId}';
                  showInviteDialog(
                      context, link, selectedServer!.serverId);
                },
                borderRadius: BorderRadius.circular(haven.radiusSm),
                padding: const EdgeInsets.all(HavenSpacing.xs),
                child: Icon(
                  LucideIcons.userPlus,
                  size: 16,
                  color: haven.textSecondary,
                ),
              ),
            ),
            HavenPressable(
              onTap: onOpenSettings,
              borderRadius: BorderRadius.circular(haven.radiusSm),
              padding: const EdgeInsets.all(HavenSpacing.xs),
              child: Icon(
                LucideIcons.settings,
                size: 16,
                color: haven.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Server mode content — channel list with create button.
class _ServerContent extends StatefulWidget {
  final HavenTheme haven;
  final Map<String, ChannelInfo> channels;
  final String? selectedChannelId;
  final ValueChanged<String> onChannelSelected;
  final VoidCallback onCreateChannel;
  final bool canManageChannels;
  final String channelLayoutJson;

  const _ServerContent({
    super.key,
    required this.haven,
    required this.channels,
    required this.selectedChannelId,
    required this.onChannelSelected,
    required this.onCreateChannel,
    this.canManageChannels = false,
    this.channelLayoutJson = '[]',
  });

  @override
  State<_ServerContent> createState() => _ServerContentState();
}

class _ServerContentState extends State<_ServerContent> {
  List<Widget> _buildLayoutItems() {
    final w = widget;
    final widgets = <Widget>[];
    final placedChannels = <String>{};

    try {
      final List<dynamic> layout = jsonDecode(w.channelLayoutJson);
      String? currentCategory;
      for (final item in layout) {
        if (item['type'] == 'category') {
          currentCategory = item['name'] as String;
          widgets.add(_CategoryHeader(
            haven: w.haven,
            name: currentCategory,
            onToggle: () => setState(() {}),
          ));
        } else if (item['type'] == 'separator') {
          currentCategory = null;
          // Add a small visual divider in the sidebar.
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HavenSpacing.lg,
              vertical: HavenSpacing.sm,
            ),
            child: Divider(height: 1, color: w.haven.border),
          ));
        } else if (item['type'] == 'channel') {
          final channelId = item['channel_id'] as String;
          final channel = w.channels[channelId];
          if (channel != null) {
            placedChannels.add(channelId);
            final collapsed = currentCategory != null &&
                (_categoryCollapsedState[currentCategory] ?? false);
            widgets.add(_AnimatedChannelTile(
              key: ValueKey('ach-$channelId'),
              visible: !collapsed,
              child: _ChannelTile(
                channel: channel,
                isSelected: channel.channelId == w.selectedChannelId,
                onTap: () => w.onChannelSelected(channel.channelId),
              ),
            ));
          }
        }
      }
    } catch (_) {}

    // Only show unplaced channels if no layout has been saved yet
    // (empty layout = no admin organization). Once a layout exists,
    // new channels only appear after the admin saves the layout.
    final hasLayout = placedChannels.isNotEmpty;
    if (!hasLayout) {
      final unplaced = w.channels.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final channel in unplaced) {
        widgets.add(_ChannelTile(
          channel: channel,
          isSelected: channel.channelId == w.selectedChannelId,
          onTap: () => w.onChannelSelected(channel.channelId),
        ));
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final items = _buildLayoutItems();
    final hasCategories = items.any((i) => i is _CategoryHeader);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasCategories)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HavenSpacing.lg, HavenSpacing.sm, HavenSpacing.sm, HavenSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'TEXT CHANNELS',
                    style: HavenTypography.caption.copyWith(
                      color: w.haven.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (w.canManageChannels)
                  HavenPressable(
                    onTap: w.onCreateChannel,
                    borderRadius: BorderRadius.circular(w.haven.radiusSm),
                    padding: const EdgeInsets.all(HavenSpacing.xs),
                    child: Icon(LucideIcons.plus,
                        size: 14, color: w.haven.textSecondary),
                  ),
              ],
            ),
          ),
        if (!hasCategories) Divider(height: 1, color: w.haven.border),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text('No channels',
                      style: HavenTypography.bodySmall
                          .copyWith(color: w.haven.textSecondary)),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: HavenSpacing.xs),
                  children: items,
                ),
        ),
      ],
    );
  }
}

/// Animates a channel tile in/out when its category is collapsed/expanded.
class _AnimatedChannelTile extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _AnimatedChannelTile({
    super.key,
    required this.visible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: visible ? null : 0,
        child: visible
            ? child
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Tracks collapsed state of categories in the sidebar (persists across rebuilds).
final Map<String, bool> _categoryCollapsedState = {};

/// Category header in the sidebar — collapsible folder label.
class _CategoryHeader extends StatefulWidget {
  final HavenTheme haven;
  final String name;
  final VoidCallback? onToggle;

  const _CategoryHeader({
    required this.haven,
    required this.name,
    this.onToggle,
  });

  @override
  State<_CategoryHeader> createState() => _CategoryHeaderState();
}

class _CategoryHeaderState extends State<_CategoryHeader> {
  bool get _collapsed => _categoryCollapsedState[widget.name] ?? false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HavenSpacing.sm + 2,
        HavenSpacing.md,
        HavenSpacing.sm,
        HavenSpacing.xs,
      ),
      child: HavenPressable(
        subtle: true,
        onTap: () {
          setState(() =>
              _categoryCollapsedState[widget.name] = !_collapsed);
          widget.onToggle?.call();
        },
        child: Row(
          children: [
            AnimatedRotation(
              turns: _collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(LucideIcons.chevronDown,
                  size: 10, color: widget.haven.textSecondary),
            ),
            const SizedBox(width: HavenSpacing.xs),
            Expanded(
              child: Text(
                widget.name.toUpperCase(),
                style: HavenTypography.caption.copyWith(
                  color: widget.haven.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home / DM mode content — room controls + peer list.
class _HomeContent extends StatelessWidget {
  final HavenTheme haven;
  final BuildContext context;
  final Map<String, PeerInfo> peers;
  final String? selectedPeerId;
  final NodeStatus nodeStatus;
  final ValueChanged<String> onPeerSelected;
  final ChatMessage? Function(String) lastMessage;
  final String Function(DateTime) formatTime;
  final String? activeRoom;
  final TextEditingController roomController;
  final Future<void> Function(String) onJoinRoom;
  final VoidCallback onCreateInvite;

  const _HomeContent({
    super.key,
    required this.haven,
    required this.context,
    required this.peers,
    required this.selectedPeerId,
    required this.nodeStatus,
    required this.onPeerSelected,
    required this.lastMessage,
    required this.formatTime,
    required this.activeRoom,
    required this.roomController,
    required this.onJoinRoom,
    required this.onCreateInvite,
  });

  @override
  Widget build(BuildContext innerContext) {
    final divider1Reveal =
        StartupRevealScope.interval(innerContext, 0.35, 0.45);
    final onlineLabelReveal =
        StartupRevealScope.interval(innerContext, 0.38, 0.50);
    final onlineLineReveal =
        StartupRevealScope.interval(innerContext, 0.42, 0.55);
    final peerListReveal =
        StartupRevealScope.interval(innerContext, 0.45, 0.60);

    final dividerTextStyle = HavenTypography.caption.copyWith(
      color: haven.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      fontSize: 11,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room controls
        _buildRoomSection(innerContext),

        LineDrawDivider(
          animation: divider1Reveal,
          height: 1,
          color: haven.border,
        ),

        // Peer count — ASOT-style divider with reveal animations
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HavenSpacing.sm + 2,
            vertical: HavenSpacing.sm,
          ),
          child: Row(
            children: [
              TypewriterText(
                text: 'Online',
                animation: onlineLabelReveal,
                style: dividerTextStyle,
              ),
              const SizedBox(width: HavenSpacing.sm),
              Expanded(
                child: LineDrawDivider(
                  animation: onlineLineReveal,
                  height: 1,
                  color: haven.border,
                ),
              ),
              const SizedBox(width: HavenSpacing.sm),
              onlineLabelReveal != null
                  ? FadeTransition(
                      opacity: onlineLabelReveal,
                      child: Text('${peers.length}', style: dividerTextStyle),
                    )
                  : Text('${peers.length}', style: dividerTextStyle),
            ],
          ),
        ),

        // Peer list
        Expanded(
          child: peers.isEmpty
              ? EmptyPeerList(nodeStatus: nodeStatus)
              : ListView.builder(
                  itemCount: peers.length,
                  padding: const EdgeInsets.symmetric(
                      vertical: HavenSpacing.xs),
                  itemBuilder: (context, index) {
                    final peerId = peers.keys.elementAt(index);
                    final peer = peers[peerId];
                    final isSelected = peerId == selectedPeerId;
                    final last = lastMessage(peerId);

                    Widget card = PeerCard(
                      peerId: peerId,
                      isSelected: isSelected,
                      isEncrypted: peer?.isEncrypted ?? false,
                      lastMessage: last,
                      formatTime: formatTime,
                      onTap: () => onPeerSelected(peerId),
                    );

                    return StaggeredListItem(
                      parentAnimation: peerListReveal,
                      index: index,
                      totalItems: peers.length,
                      slideFrom: const Offset(-0.3, 0),
                      child: card,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoomSection(BuildContext ctx) {
    final roomReveal =
        StartupRevealScope.interval(ctx, 0.30, 0.42);
    final inviteBtnReveal =
        StartupRevealScope.interval(ctx, 0.40, 0.50);

    if (activeRoom != null) {
      Widget badge = Padding(
        padding: const EdgeInsets.all(HavenSpacing.sm + 2),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HavenSpacing.sm + 2,
            vertical: HavenSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: haven.accentMuted,
            borderRadius: BorderRadius.circular(haven.radiusMd),
            border: Border.all(
              color: haven.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.cloud, size: 16, color: haven.accent),
              const SizedBox(width: HavenSpacing.sm),
              Expanded(
                child: Text(
                  'Room: $activeRoom',
                  style: HavenTypography.bodySmall.copyWith(
                    color: haven.accent,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              HavenPressable(
                onTap: () {
                  final link = 'haven://join?room=$activeRoom';
                  Clipboard.setData(ClipboardData(text: link));
                  HavenToast.show(
                    ctx,
                    'Invite link copied',
                    type: HavenToastType.success,
                  );
                },
                borderRadius: BorderRadius.circular(haven.radiusSm),
                padding: const EdgeInsets.all(HavenSpacing.xs),
                child: Icon(LucideIcons.copy,
                    size: 14, color: haven.accent),
              ),
            ],
          ),
        ),
      );

      if (roomReveal != null) {
        badge = FadeTransition(
          opacity: roomReveal,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.3, 0),
              end: Offset.zero,
            ).animate(roomReveal),
            child: badge,
          ),
        );
      }

      return badge;
    }

    // Room input + Join button
    Widget textFieldRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: HavenTextField(
            controller: roomController,
            hintText: 'Room code or invite...',
            isDense: true,
            style: HavenTypography.bodySmall.copyWith(
              color: haven.textPrimary,
            ),
            onSubmitted: (v) => onJoinRoom(v.trim()),
          ),
        ),
        const SizedBox(width: HavenSpacing.xs + 2),
        HavenButton.filled(
          onPressed: () =>
              onJoinRoom(roomController.text.trim()),
          compact: true,
          child: const Text('Join'),
        ),
      ],
    );

    if (roomReveal != null) {
      textFieldRow = FadeTransition(
        opacity: roomReveal,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-0.3, 0),
            end: Offset.zero,
          ).animate(roomReveal),
          child: textFieldRow,
        ),
      );
    }

    // Create Invite button
    Widget inviteBtn = HavenButton.outline(
      onPressed: onCreateInvite,
      expand: true,
      icon: Icon(LucideIcons.link, size: 14),
      child: const Text('Create Invite'),
    );

    if (inviteBtnReveal != null) {
      inviteBtn = FadeTransition(
        opacity: inviteBtnReveal,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(inviteBtnReveal),
          child: inviteBtn,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(HavenSpacing.sm + 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          textFieldRow,
          const SizedBox(height: HavenSpacing.sm - 2),
          inviteBtn,
        ],
      ),
    );
  }
}

/// A single channel tile in the channel list.
class _ChannelTile extends StatelessWidget {
  final ChannelInfo channel;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final radius = BorderRadius.circular(haven.radiusMd);

    Widget tile = HavenPressable(
      onTap: onTap,
      subtle: true,
      borderRadius: radius,
      backgroundColor:
          isSelected ? haven.accentMuted : Colors.transparent,
      hoverColor: haven.elevated,
      padding: const EdgeInsets.symmetric(
        horizontal: HavenSpacing.sm + 2,
        vertical: HavenSpacing.sm,
      ),
      child: AnimatedDefaultTextStyle(
        duration: HavenDurations.fast,
        curve: HavenCurves.subtle,
        style: HavenTypography.body.copyWith(
          color: isSelected
              ? haven.textPrimary
              : haven.textSecondary,
          fontWeight:
              isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.hash,
              size: 18,
              color: isSelected
                  ? haven.textPrimary
                  : haven.textSecondary,
            ),
            const SizedBox(width: HavenSpacing.sm),
            Expanded(
              child: Text(
                channel.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (isSelected) {
      tile = SelectionShimmer(
        highlightColor: haven.accent.withValues(alpha: 0.12),
        borderRadius: radius,
        child: tile,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HavenSpacing.sm,
        vertical: HavenSpacing.xxs,
      ),
      child: tile,
    );
  }
}
