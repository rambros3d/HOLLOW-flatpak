import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/chat_message.dart';
import 'package:haven/src/core/models/node_status.dart';
import 'package:haven/src/core/providers/chat_provider.dart';
import 'package:haven/src/core/providers/identity_provider.dart';
import 'package:haven/src/core/providers/member_panel_provider.dart';
import 'package:haven/src/core/providers/node_provider.dart';
import 'package:haven/src/core/providers/peers_provider.dart';
import 'package:haven/src/core/providers/room_provider.dart';
import 'package:haven/src/core/providers/selected_peer_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/chat/chat_pane.dart';
import 'package:haven/src/ui/dialogs/invite_dialog.dart';
import 'package:haven/src/ui/dialogs/mnemonic_dialog.dart';
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

class _HavenShellState extends ConsumerState<HavenShell> {
  final _roomController = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
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
      onJoinRoom: (input) => ref.read(roomProvider.notifier).join(input),
      onCreateInvite: _createInvite,
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

  Widget _buildChatOrEmpty({
    required HavenTheme haven,
    required String? selectedPeerId,
    required Map<String, dynamic> peers,
  }) {
    if (selectedPeerId == null) return _buildEmptyChat(haven);
    final peer = (peers as Map)[selectedPeerId];
    return ChatPane(
      key: ValueKey(selectedPeerId),
      peerId: selectedPeerId,
      isEncrypted: peer?.isEncrypted ?? false,
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

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    final nodeState = ref.watch(nodeProvider);
    final peers = ref.watch(peersProvider);
    final selectedPeerId = ref.watch(selectedPeerProvider);
    final chatHistory = ref.watch(chatProvider);
    final activeRoom = ref.watch(roomProvider);
    final memberPanelOpen = ref.watch(memberPanelProvider);

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
          );
        }

        final isDesktopPlatform =
            Platform.isWindows || Platform.isLinux || Platform.isMacOS;

        // Desktop and tablet — same layout, tablet just hides member panel.
        Widget body = Column(
          children: [
            // Custom window title bar (desktop platforms only)
            if (isDesktopPlatform) const WindowTitleBar(),

            // Main content area
            Expanded(
              child: Row(
                children: [
                  // Server strip (far left)
                  const ServerStrip(),

                  // Channel sidebar
                  _buildChannelSidebar(
                    peers: peers,
                    chatHistory: chatHistory,
                    selectedPeerId: selectedPeerId,
                    nodeStatus: nodeState.status,
                    activeRoom: activeRoom,
                  ),

                  // Chat pane (expanded)
                  Expanded(
                    child: Container(
                      color: haven.background,
                      child: _buildChatOrEmpty(
                        haven: haven,
                        selectedPeerId: selectedPeerId,
                        peers: peers,
                      ),
                    ),
                  ),

                  // Member panel (desktop: shown by default, tablet: toggleable)
                  if (memberPanelOpen && (isDesktop || !isMobile))
                    const MemberPanel(),
                ],
              ),
            ),
          ],
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
          width: null,
        );
      case 1: // Chat
        body = Container(
          color: haven.background,
          child: _buildChatOrEmpty(
            haven: haven,
            selectedPeerId: selectedPeerId,
            peers: peers,
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
