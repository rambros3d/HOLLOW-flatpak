import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/models/channel_info.dart';
import 'package:hollow/src/core/models/chat_message.dart';
import 'package:hollow/src/core/models/node_status.dart';
import 'package:hollow/src/core/models/server_info.dart';
import 'package:hollow/src/core/providers/channel_chat_provider.dart';
import 'package:hollow/src/core/providers/channel_provider.dart';
import 'package:hollow/src/core/providers/chat_provider.dart';
import 'package:hollow/src/core/providers/identity_provider.dart';
import 'package:hollow/src/core/providers/member_panel_provider.dart';
import 'package:hollow/src/core/providers/node_provider.dart';
import 'package:hollow/src/core/providers/peers_provider.dart';
import 'package:hollow/src/core/providers/friends_provider.dart';
import 'package:hollow/src/core/providers/profile_provider.dart';
import 'package:hollow/src/core/providers/selected_peer_provider.dart';
import 'package:hollow/src/core/providers/server_provider.dart';
import 'package:hollow/src/core/providers/system_notification_provider.dart';
import 'package:hollow/src/core/providers/unread_provider.dart';
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:hollow/src/ui/animations/hollow_curves.dart';
import 'package:hollow/src/ui/animations/ambient_background.dart';
import 'package:hollow/src/ui/animations/startup_reveal.dart';
import 'package:hollow/src/ui/chat/channel_chat_pane.dart';
import 'package:hollow/src/ui/chat/chat_pane.dart';
import 'package:hollow/src/ui/components/hollow_pressable.dart';
import 'package:hollow/src/ui/components/hollow_tooltip.dart';
import 'package:hollow/src/ui/components/notification_overlay.dart';
import 'package:hollow/src/ui/dialogs/create_channel_dialog.dart';
import 'package:hollow/src/ui/dialogs/mnemonic_dialog.dart';
import 'package:hollow/src/ui/dialogs/user_settings_dialog.dart';
import 'package:hollow/src/ui/settings/server_settings_panel.dart';
import 'package:hollow/src/ui/shell/channel_sidebar.dart';
import 'package:hollow/src/ui/shell/member_panel.dart';
import 'package:hollow/src/ui/shell/mobile_nav.dart';
import 'package:hollow/src/ui/shell/server_strip.dart';
import 'package:hollow/src/ui/shell/window_title_bar.dart';
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
class HollowShell extends ConsumerStatefulWidget {
  const HollowShell({super.key});

  @override
  ConsumerState<HollowShell> createState() => _HollowShellState();
}

class _HollowShellState extends ConsumerState<HollowShell>
    with TickerProviderStateMixin {
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

    // Register global keyboard shortcut handler.
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);

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

    // Load friends list from local DB.
    await ref.read(friendsProvider.notifier).loadAll();

    // Initialize native notifications (for tray mode).
    await ref.read(systemNotificationProvider.notifier).init();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _revealController.dispose();
    super.dispose();
  }

  /// Global keyboard shortcut handler — registered on HardwareKeyboard
  /// so it works regardless of which widget currently has focus.
  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    // Ctrl+, → Open settings dialog.
    if (isCtrl &&
        !isShift &&
        event.logicalKey == LogicalKeyboardKey.comma) {
      showUserSettingsDialog(context, ref);
      return true;
    }

    // Ctrl+Shift+M → Toggle member panel.
    if (isCtrl &&
        isShift &&
        event.logicalKey == LogicalKeyboardKey.keyM) {
      final current = ref.read(memberPanelProvider);
      ref.read(memberPanelProvider.notifier).state = !current;
      return true;
    }

    // Ctrl+K → Toggle channel search.
    if (isCtrl &&
        !isShift &&
        event.logicalKey == LogicalKeyboardKey.keyK) {
      final current = ref.read(channelSearchOpenProvider);
      ref.read(channelSearchOpenProvider.notifier).state = !current;
      return true;
    }

    return false;
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
    required ServerInfo? selectedServer,
    required Map<String, ChannelInfo> channels,
    required String? selectedChannelId,
    required String channelLayoutJson,
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
        // Mark DM as read.
        final msgs = chatHistory[peerId];
        final latestId = msgs != null && msgs.isNotEmpty
            ? msgs.last.messageId
            : null;
        ref.read(unreadProvider.notifier).markDmSeen(peerId, latestId);
        // On mobile, switch to chat tab when peer is selected.
        ref.read(mobileTabProvider.notifier).state = 1;
      },
      lastMessage: (peerId) => _lastMessage(peerId, chatHistory),
      formatTime: _formatTime,
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
          // Mark channel as read.
          final chState = ref.read(channelChatProvider);
          final msgs = chState['$serverId:$channelId'];
          final latestId = msgs != null && msgs.isNotEmpty
              ? msgs.last.messageId
              : null;
          ref.read(unreadProvider.notifier)
              .markChannelSeen(serverId, channelId, latestId);
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
      canManageChannels: selectedServer != null &&
          (ref.watch(myPermissionsProvider(selectedServer.serverId)).whenOrNull(
              data: (perms) => (perms & Permission.manageChannels) != 0) ?? false),
      channelLayoutJson: channelLayoutJson,
    );
  }

  Widget _buildEmptyChat(HollowTheme hollow) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.messageSquare,
            size: 64,
            color: hollow.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: HollowSpacing.lg),
          Text(
            'Select a peer to start chatting',
            style: HollowTypography.body.copyWith(
              color: hollow.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelPlaceholder(HollowTheme hollow, ChannelInfo? channel) {
    return Column(
      children: [
        // Channel header
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: HollowSpacing.lg),
          decoration: BoxDecoration(
            color: hollow.surface,
            border: Border(bottom: BorderSide(color: hollow.border)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.hash, size: 20, color: hollow.textSecondary),
              const SizedBox(width: HollowSpacing.sm),
              Text(
                channel?.name ?? 'Unknown Channel',
                style: HollowTypography.subheading.copyWith(
                  color: hollow.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              HollowTooltip(
                message: 'Toggle member panel',
                child: HollowPressable(
                  onTap: () => ref
                      .read(memberPanelProvider.notifier)
                      .state = !ref.read(memberPanelProvider),
                  borderRadius: BorderRadius.circular(hollow.radiusSm),
                  padding: const EdgeInsets.all(HollowSpacing.xs),
                  child: Icon(LucideIcons.users,
                      size: 20, color: hollow.textSecondary),
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
                    color: hollow.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: HollowSpacing.lg),
                Text(
                  'Welcome to #${channel?.name ?? "general"}',
                  style: HollowTypography.heading
                      .copyWith(color: hollow.textPrimary),
                ),
                const SizedBox(height: HollowSpacing.sm),
                Text(
                  'Channel messages coming soon.',
                  style: HollowTypography.body
                      .copyWith(color: hollow.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatOrEmpty({
    required HollowTheme hollow,
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
      return _buildChannelPlaceholder(hollow, channel);
    }
    // DM chat view
    if (selectedPeerId == null) return _buildEmptyChat(hollow);
    return ChatPane(
      key: ValueKey(selectedPeerId),
      peerId: selectedPeerId,
    );
  }

  Widget _buildSettingsPlaceholder(HollowTheme hollow) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.settings,
            size: 64,
            color: hollow.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: HollowSpacing.lg),
          Text(
            'Settings coming soon',
            style: HollowTypography.body.copyWith(
              color: hollow.textSecondary,
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
    final hollow = HollowTheme.of(context);

    final nodeState = ref.watch(nodeProvider);
    final peers = ref.watch(peersProvider);
    final selectedPeerId = ref.watch(selectedPeerProvider);
    final chatHistory = ref.watch(chatProvider);

    final memberPanelOpen = ref.watch(memberPanelProvider);

    // Server/channel state
    final servers = ref.watch(serverListProvider);
    final selectedServerId = ref.watch(selectedServerProvider);
    final channels = ref.watch(channelListProvider);
    final selectedChannelId = ref.watch(selectedChannelProvider);
    final selectedServer =
        selectedServerId != null ? servers[selectedServerId] : null;
    final channelLayout = ref.watch(channelLayoutProvider);
    final settingsOpen = ref.watch(serverSettingsOpenProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= _kDesktopBreakpoint;
        final isMobile = width < _kTabletBreakpoint;

        if (isMobile) {
          return _buildMobileLayout(
            hollow: hollow,
            peers: peers,
            chatHistory: chatHistory,
            selectedPeerId: selectedPeerId,
            nodeStatus: nodeState.status,

            selectedServer: selectedServer,
            channels: channels,
            selectedChannelId: selectedChannelId,
            channelLayoutJson: channelLayout,
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
          
                      selectedServer: selectedServer,
                      channels: channels,
                      selectedChannelId: selectedChannelId,
                      channelLayoutJson: channelLayout,
                    ),

                    // Chat pane with crossfade
                    Expanded(
                      child: _chatRevealWrap(
                        RepaintBoundary(
                          child: AmbientBackground(
                            color1: hollow.accent,
                            color2: const Color(0xFF6366F1), // indigo/purple
                            child: AnimatedSwitcher(
                              duration: HollowDurations.normal,
                              switchInCurve: HollowCurves.enter,
                              switchOutCurve: HollowCurves.exit,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              child: Container(
                                key: ValueKey(
                                    settingsOpen && selectedServer != null
                                        ? 'settings-${selectedServer.serverId}'
                                        : selectedChannelId ?? selectedPeerId ?? 'empty'),
                                color: hollow.background,
                                child: settingsOpen && selectedServer != null
                                    ? ServerSettingsPanel(server: selectedServer)
                                    : _buildChatOrEmpty(
                                        hollow: hollow,
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
          backgroundColor: hollow.background,
          body: Stack(
            children: [
              body,
              const NotificationOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout({
    required HollowTheme hollow,
    required Map<String, dynamic> peers,
    required Map<String, List<ChatMessage>> chatHistory,
    required String? selectedPeerId,
    required NodeStatus nodeStatus,

    required ServerInfo? selectedServer,
    required Map<String, ChannelInfo> channels,
    required String? selectedChannelId,
    required String channelLayoutJson,
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

          selectedServer: selectedServer,
          channels: channels,
          selectedChannelId: selectedChannelId,
          channelLayoutJson: channelLayoutJson,
          width: null,
        );
      case 1: // Chat
        body = AmbientBackground(
          color1: hollow.accent,
          color2: const Color(0xFF6366F1),
          child: AnimatedSwitcher(
            duration: HollowDurations.normal,
            switchInCurve: HollowCurves.enter,
            switchOutCurve: HollowCurves.exit,
            child: Container(
              key: ValueKey(
                  selectedChannelId ?? selectedPeerId ?? 'empty'),
              color: hollow.background,
              child: _buildChatOrEmpty(
                hollow: hollow,
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
        body = _buildSettingsPlaceholder(hollow);
      default:
        body = const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: hollow.background,
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
      duration: HollowDurations.normal,
      value: widget.visible ? 1.0 : 0.0,
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: HollowCurves.enter,
      reverseCurve: HollowCurves.exit,
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
