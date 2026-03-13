import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/channel_info.dart';
import 'package:haven/src/core/models/chat_message.dart';
import 'package:haven/src/core/models/node_status.dart';
import 'package:haven/src/core/models/server_info.dart';
import 'package:haven/src/core/providers/channel_provider.dart';
import 'package:haven/src/core/providers/chat_provider.dart';
import 'package:haven/src/core/providers/identity_provider.dart';
import 'package:haven/src/core/providers/member_panel_provider.dart';
import 'package:haven/src/core/providers/node_provider.dart';
import 'package:haven/src/core/providers/peers_provider.dart';
import 'package:haven/src/core/providers/profile_provider.dart';
import 'package:haven/src/core/providers/room_provider.dart';
import 'package:haven/src/rust/api/crdt.dart' as crdt_api;
import 'package:haven/src/core/providers/selected_peer_provider.dart';
import 'package:haven/src/core/providers/server_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/animations/haven_curves.dart';
import 'package:haven/src/ui/animations/ambient_background.dart';
import 'package:haven/src/ui/animations/startup_reveal.dart';
import 'package:haven/src/ui/chat/channel_chat_pane.dart';
import 'package:haven/src/ui/chat/chat_pane.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';
import 'package:haven/src/ui/components/haven_tooltip.dart';
import 'package:haven/src/ui/dialogs/create_channel_dialog.dart';
import 'package:haven/src/ui/dialogs/invite_dialog.dart';
import 'package:haven/src/ui/dialogs/mnemonic_dialog.dart';
import 'package:haven/src/ui/settings/server_settings_panel.dart';
import 'package:haven/src/ui/shell/channel_sidebar.dart';
import 'package:haven/src/ui/shell/member_panel.dart';
import 'package:haven/src/ui/shell/mobile_nav.dart';
import 'package:haven/src/ui/shell/server_strip.dart';
import 'package:haven/src/ui/shell/window_title_bar.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

/// Breakpoints for adaptive layout.
const _kDesktopBreakpoint = 1024.0;
const _kTabletBreakpoint = 600.0;

/// Main application shell — Discord-like multi-panel layout.
///
/// Desktop: ServerStrip | ChannelSidebar | ChatPane | MemberPanel
/// Tablet:  ServerStrip | ChannelSidebar | ChatPane (member panel toggleable)
/// Mobile:  Active tab view + bottom navigation bar
class HavenShell extends ConsumerStatefulWidget {
  const HavenShell({super.key});

  @override
  ConsumerState<HavenShell> createState() => _HavenShellState();
}

class _HavenShellState extends ConsumerState<HavenShell>
    with TickerProviderStateMixin {
  final _roomController = TextEditingController();
  bool _initialized = false;

  // Startup reveal animation — master controller shared via InheritedWidget.
  late final AnimationController _revealController;
  bool _revealComplete = false;

  // Chat pane reveal sub-animation.
  late final Animation<double> _chatReveal;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _chatReveal = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic),
    );

    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _revealComplete = true);
      }
    });

    // Delay reveal until after the first frame so the window is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealController.forward();
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_initialized) return;
    _initialized = true;

    await ref.read(identityProvider.notifier).load();

    final identity = ref.read(identityProvider);
    if (identity.error != null) return;

    if (identity.mnemonic != null && mounted) {
      showMnemonicDialog(context, identity.mnemonic!);
    }

    await ref.read(nodeProvider.notifier).start();

    // Load servers from local DB after node starts.
    await ref.read(serverListProvider.notifier).loadFromDb();

    // Load cached user profiles into memory.
    await ref.read(profileProvider.notifier).loadAll();
  }

  Future<void> _createInvite() async {
    final link = await ref.read(roomProvider.notifier).createInvite();
    if (link != null && mounted) {
      final roomCode = ref.read(roomProvider);
      showInviteDialog(context, link, roomCode!);
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  ChatMessage? _lastMessage(
      String peerId, Map<String, List<ChatMessage>> chatHistory) {
    final msgs = chatHistory[peerId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }

  Widget _buildChannelSidebar({
    required Map<String, dynamic> peers,
    required Map<String, List<ChatMessage>> chatHistory,
    required String? selectedPeerId,
    required NodeStatus nodeStatus,
    required String? activeRoom,
    required ServerInfo? selectedServer,
    required Map<String, ChannelInfo> channels,
    required String? selectedChannelId,
    double? width = 240,
  }) {
    return ChannelSidebar(
      peers: Map.from(peers),
      chatHistory: chatHistory,
      selectedPeerId: selectedPeerId,
      nodeStatus: nodeStatus,
      width: width,
      onPeerSelected: (peerId) {
        ref.read(selectedPeerProvider.notifier).state = peerId;
        // On mobile, switch to chat tab when peer is selected.
        ref.read(mobileTabProvider.notifier).state = 1;
      },
      lastMessage: (peerId) => _lastMessage(peerId, chatHistory),
      formatTime: _formatTime,
      activeRoom: activeRoom,
      roomController: _roomController,
      onJoinRoom: (input) async {
        final uri = Uri.tryParse(input.trim());
        if (uri != null &&
            uri.scheme == 'haven' &&
            uri.queryParameters.containsKey('server')) {
          final serverId = uri.queryParameters['server']!;
          crdt_api.joinServer(serverId: serverId);
          _roomController.clear();
        } else {
          ref.read(roomProvider.notifier).join(input);
        }
      },
      onCreateInvite: _createInvite,
      // Server mode props
      selectedServer: selectedServer,
      channels: channels,
      selectedChannelId: selectedChannelId,
      onChannelSelected: (channelId) {
        ref.read(selectedChannelProvider.notifier).state = channelId;
        // Remember last channel for this server.
        final serverId = ref.read(selectedServerProvider);
        if (serverId != null) {
          final map = Map<String, String>.from(
              ref.read(lastChannelPerServerProvider));
          map[serverId] = channelId;
          ref.read(lastChannelPerServerProvider.notifier).state = map;
        }
        // On mobile, switch to chat tab when channel is selected.
        ref.read(mobileTabProvider.notifier).state = 1;
      },
      onCreateChannel: () {
        if (selectedServer != null) {
          showCreateChannelDialog(context, selectedServer.serverId);
        }
      },
      onOpenSettings: () {
        ref.read(serverSettingsOpenProvider.notifier).state =
            !ref.read(serverSettingsOpenProvider);
      },
    );
  }

  Widget _buildEmptyChat(HavenTheme haven) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.messageSquare,
            size: 64,
            color: haven.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: HavenSpacing.lg),
          Text(
            'Select a peer to start chatting',
            style: HavenTypography.body.copyWith(
              color: haven.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelPlaceholder(HavenTheme haven, ChannelInfo? channel) {
    return Column(
      children: [
        // Channel header
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: HavenSpacing.lg),
          decoration: BoxDecoration(
            color: haven.surface,
            border: Border(bottom: BorderSide(color: haven.border)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.hash, size: 20, color: haven.textSecondary),
              const SizedBox(width: HavenSpacing.sm),
              Text(
                channel?.name ?? 'Unknown Channel',
                style: HavenTypography.subheading.copyWith(
                  color: haven.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              HavenTooltip(
                message: 'Toggle member panel',
                child: HavenPressable(
                  onTap: () => ref
                      .read(memberPanelProvider.notifier)
                      .state = !ref.read(memberPanelProvider),
                  borderRadius: BorderRadius.circular(haven.radiusSm),
                  padding: const EdgeInsets.all(HavenSpacing.xs),
                  child: Icon(LucideIcons.users,
                      size: 20, color: haven.textSecondary),
                ),
              ),
            ],
          ),
        ),
        // Placeholder body
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.hash,
                    size: 64,
                    color: haven.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: HavenSpacing.lg),
                Text(
                  'Welcome to #${channel?.name ?? "general"}',
                  style: HavenTypography.heading
                      .copyWith(color: haven.textPrimary),
                ),
                const SizedBox(height: HavenSpacing.sm),
                Text(
                  'Channel messages coming soon.',
                  style: HavenTypography.body
                      .copyWith(color: haven.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatOrEmpty({
    required HavenTheme haven,
    required String? selectedPeerId,
    required Map<String, dynamic> peers,
    required String? selectedChannelId,
    required Map<String, ChannelInfo> channels,
  }) {
    // Server channel view
    if (selectedChannelId != null) {
      final channel = channels[selectedChannelId];
      final serverId = ref.read(selectedServerProvider);
      if (serverId != null && channel != null) {
        return ChannelChatPane(
          key: ValueKey('ch:$selectedChannelId'),
          serverId: serverId,
          channelId: selectedChannelId,
          channelName: channel.name,
        );
      }
      return _buildChannelPlaceholder(haven, channel);
    }
    // DM chat view
    if (selectedPeerId == null) return _buildEmptyChat(haven);
    return ChatPane(
      key: ValueKey(selectedPeerId),
      peerId: selectedPeerId,
    );
  }

  Widget _buildSettingsPlaceholder(HavenTheme haven) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.settings,
            size: 64,
            color: haven.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: HavenSpacing.lg),
          Text(
            'Settings coming soon',
            style: HavenTypography.body.copyWith(
              color: haven.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps the chat pane with a fade for the startup reveal.
  /// Always keeps the FadeTransition in the tree so the child's State
  /// (e.g. AmbientBackground's AnimationController) is preserved when
  /// the reveal completes — avoids resetting the ambient blob positions.
  Widget _chatRevealWrap(Widget child) {
    return FadeTransition(
      opacity: _revealComplete ? kAlwaysCompleteAnimation : _chatReveal,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    final nodeState = ref.watch(nodeProvider);
    final peers = ref.watch(peersProvider);
    final selectedPeerId = ref.watch(selectedPeerProvider);
    final chatHistory = ref.watch(chatProvider);
    final activeRoom = ref.watch(roomProvider);
    final memberPanelOpen = ref.watch(memberPanelProvider);

    // Server/channel state
    final servers = ref.watch(serverListProvider);
    final selectedServerId = ref.watch(selectedServerProvider);
    final channels = ref.watch(channelListProvider);
    final selectedChannelId = ref.watch(selectedChannelProvider);
    final selectedServer =
        selectedServerId != null ? servers[selectedServerId] : null;
    final settingsOpen = ref.watch(serverSettingsOpenProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= _kDesktopBreakpoint;
        final isMobile = width < _kTabletBreakpoint;

        if (isMobile) {
          return _buildMobileLayout(
            haven: haven,
            peers: peers,
            chatHistory: chatHistory,
            selectedPeerId: selectedPeerId,
            nodeStatus: nodeState.status,
            activeRoom: activeRoom,
            selectedServer: selectedServer,
            channels: channels,
            selectedChannelId: selectedChannelId,
          );
        }

        final isDesktopPlatform =
            Platform.isWindows || Platform.isLinux || Platform.isMacOS;

        // Desktop and tablet — same layout, tablet just hides member panel.
        Widget body = StartupRevealScope(
          controller: _revealController,
          isComplete: _revealComplete,
          child: Column(
            children: [
              // Custom window title bar (desktop platforms only)
              if (isDesktopPlatform) const WindowTitleBar(),

              // Main content area
              Expanded(
                child: Row(
                  children: [
                    // Server strip (far left)
                    const RepaintBoundary(child: ServerStrip()),

                    // Channel sidebar
                    _buildChannelSidebar(
                      peers: peers,
                      chatHistory: chatHistory,
                      selectedPeerId: selectedPeerId,
                      nodeStatus: nodeState.status,
                      activeRoom: activeRoom,
                      selectedServer: selectedServer,
                      channels: channels,
                      selectedChannelId: selectedChannelId,
                    ),

                    // Chat pane with crossfade
                    Expanded(
                      child: _chatRevealWrap(
                        RepaintBoundary(
                          child: AmbientBackground(
                            color1: haven.accent,
                            color2: const Color(0xFF6366F1), // indigo/purple
                            child: AnimatedSwitcher(
                              duration: HavenDurations.normal,
                              switchInCurve: HavenCurves.enter,
                              switchOutCurve: HavenCurves.exit,
                              child: Container(
                                key: ValueKey(
                                    settingsOpen && selectedServer != null
                                        ? 'settings-${selectedServer.serverId}'
                                        : selectedChannelId ?? selectedPeerId ?? 'empty'),
                                color: haven.background,
                                child: settingsOpen && selectedServer != null
                                    ? ServerSettingsPanel(server: selectedServer)
                                    : _buildChatOrEmpty(
                                        haven: haven,
                                        selectedPeerId: selectedPeerId,
                                        peers: peers,
                                        selectedChannelId: selectedChannelId,
                                        channels: channels,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Member panel — slide in/out from right
                    if (isDesktop || !isMobile)
                      _MemberPanelSlider(
                        visible: selectedServerId != null && memberPanelOpen,
                        serverId: selectedServerId,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

        // Wrap in DragToResizeArea to restore edge/corner resize handles
        // after setAsFrameless() removed them.
        if (isDesktopPlatform) {
          body = DragToResizeArea(child: body);
        }

        return Scaffold(
          backgroundColor: haven.background,
          body: body,
        );
      },
    );
  }

  Widget _buildMobileLayout({
    required HavenTheme haven,
    required Map<String, dynamic> peers,
    required Map<String, List<ChatMessage>> chatHistory,
    required String? selectedPeerId,
    required NodeStatus nodeStatus,
    required String? activeRoom,
    required ServerInfo? selectedServer,
    required Map<String, ChannelInfo> channels,
    required String? selectedChannelId,
  }) {
    final currentTab = ref.watch(mobileTabProvider);

    Widget body;
    switch (currentTab) {
      case 0: // Home — channel sidebar content (full width on mobile)
        body = _buildChannelSidebar(
          peers: peers,
          chatHistory: chatHistory,
          selectedPeerId: selectedPeerId,
          nodeStatus: nodeStatus,
          activeRoom: activeRoom,
          selectedServer: selectedServer,
          channels: channels,
          selectedChannelId: selectedChannelId,
          width: null,
        );
      case 1: // Chat
        body = AmbientBackground(
          color1: haven.accent,
          color2: const Color(0xFF6366F1),
          child: AnimatedSwitcher(
            duration: HavenDurations.normal,
            switchInCurve: HavenCurves.enter,
            switchOutCurve: HavenCurves.exit,
            child: Container(
              key: ValueKey(
                  selectedChannelId ?? selectedPeerId ?? 'empty'),
              color: haven.background,
              child: _buildChatOrEmpty(
                haven: haven,
                selectedPeerId: selectedPeerId,
                peers: peers,
                selectedChannelId: selectedChannelId,
                channels: channels,
              ),
            ),
          ),
        );
      case 2: // Members (full width on mobile)
        body = const MemberPanel(width: null);
      case 3: // Settings
        body = _buildSettingsPlaceholder(haven);
      default:
        body = const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: haven.background,
      body: Column(
        children: [
          Expanded(child: body),
          const MobileNav(),
        ],
      ),
    );
  }
}

/// Animates the member panel sliding in/out from the right edge.
/// Uses clip + width factor like the startup RevealClip.
///
/// Freezes the panel content during close animation by overriding
/// [selectedServerProvider] with the last known server ID, preventing
/// the "No peers online" flash.
class _MemberPanelSlider extends StatefulWidget {
  final bool visible;
  final String? serverId;

  const _MemberPanelSlider({
    required this.visible,
    this.serverId,
  });

  @override
  State<_MemberPanelSlider> createState() => _MemberPanelSliderState();
}

class _MemberPanelSliderState extends State<_MemberPanelSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;

  /// Cached server ID — kept while closing so panel doesn't flash.
  String? _frozenServerId;

  @override
  void initState() {
    super.initState();
    _frozenServerId = widget.serverId;
    _controller = AnimationController(
      vsync: this,
      duration: HavenDurations.normal,
      value: widget.visible ? 1.0 : 0.0,
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: HavenCurves.enter,
      reverseCurve: HavenCurves.exit,
    );
  }

  /// True while the panel is animating closed — freezes content.
  bool _isClosing = false;

  @override
  void didUpdateWidget(_MemberPanelSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        // Opening — unfreeze content, update server ID.
        _isClosing = false;
        _frozenServerId = widget.serverId;
        _controller.forward();
      } else {
        // Closing — freeze content so it doesn't flash "No peers online".
        _isClosing = true;
        _controller.reverse();
      }
    } else if (widget.visible && widget.serverId != oldWidget.serverId) {
      // Server changed while panel is open — update live.
      _frozenServerId = widget.serverId;
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) {
        // Hide completely when animation finishes closing.
        if (_curved.value == 0.0) return const SizedBox.shrink();

        return ClipRect(
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: _curved.value,
            child: FadeTransition(
              opacity: _curved,
              child: child,
            ),
          ),
        );
      },
      // Only override selectedServerProvider during close animation
      // to freeze content. Otherwise let it use the real provider.
      child: _isClosing && _frozenServerId != null
          ? ProviderScope(
              overrides: [
                selectedServerProvider.overrideWith(
                  (ref) => _frozenServerId,
                ),
              ],
              child: const RepaintBoundary(child: MemberPanel()),
            )
          : const RepaintBoundary(child: MemberPanel()),
    );
  }
}
