import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/chat_message.dart';
import 'package:haven/src/core/models/node_status.dart';
import 'package:haven/src/core/providers/chat_provider.dart';
import 'package:haven/src/core/providers/identity_provider.dart';
import 'package:haven/src/core/providers/node_provider.dart';
import 'package:haven/src/core/providers/peers_provider.dart';
import 'package:haven/src/core/providers/room_provider.dart';
import 'package:haven/src/core/providers/selected_peer_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/chat/chat_pane.dart';
import 'package:haven/src/ui/components/status_dot.dart';
import 'package:haven/src/ui/dialogs/invite_dialog.dart';
import 'package:haven/src/ui/dialogs/mnemonic_dialog.dart';
import 'package:haven/src/ui/sidebar/sidebar.dart';

/// Breakpoints for adaptive layout.
const _kDesktopBreakpoint = 1024.0;
const _kTabletBreakpoint = 600.0;

class HavenShell extends ConsumerStatefulWidget {
  const HavenShell({super.key});

  @override
  ConsumerState<HavenShell> createState() => _HavenShellState();
}

class _HavenShellState extends ConsumerState<HavenShell> {
  final _roomController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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

  Color _statusColor(HavenTheme haven, NodeStatus status) {
    return switch (status) {
      NodeStatus.connected => haven.success,
      NodeStatus.starting => haven.warning,
      NodeStatus.loading => haven.textSecondary,
      NodeStatus.error => haven.error,
    };
  }

  String _statusText(NodeStatus status) {
    return switch (status) {
      NodeStatus.connected => 'Connected',
      NodeStatus.starting => 'Starting...',
      NodeStatus.loading => 'Loading...',
      NodeStatus.error => 'Error',
    };
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

  Widget _buildSidebar({
    required Map<String, dynamic> peers,
    required Map<String, List<ChatMessage>> chatHistory,
    required String? selectedPeerId,
    required NodeStatus nodeStatus,
    required String? activeRoom,
    bool closesDrawer = false,
  }) {
    return Sidebar(
      peers: Map.from(peers),
      chatHistory: chatHistory,
      selectedPeerId: selectedPeerId,
      nodeStatus: nodeStatus,
      onPeerSelected: (peerId) {
        ref.read(selectedPeerProvider.notifier).state = peerId;
        if (closesDrawer) {
          Navigator.of(context).pop();
        }
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
            Icons.chat_outlined,
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

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    final identity = ref.watch(identityProvider);
    final nodeState = ref.watch(nodeProvider);
    final peers = ref.watch(peersProvider);
    final selectedPeerId = ref.watch(selectedPeerProvider);
    final chatHistory = ref.watch(chatProvider);
    final activeRoom = ref.watch(roomProvider);

    final localPeerId = identity.peerId;
    final shortPeerId = localPeerId != null && localPeerId.length > 12
        ? '${localPeerId.substring(0, 12)}...'
        : localPeerId ?? '---';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= _kDesktopBreakpoint;
        final isTablet =
            width >= _kTabletBreakpoint && width < _kDesktopBreakpoint;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: haven.surface,
          drawer: isTablet
              ? Drawer(
                  width: 280,
                  backgroundColor: haven.background,
                  child: _buildSidebar(
                    peers: peers,
                    chatHistory: chatHistory,
                    selectedPeerId: selectedPeerId,
                    nodeStatus: nodeState.status,
                    activeRoom: activeRoom,
                    closesDrawer: true,
                  ),
                )
              : null,
          body: Column(
            children: [
              // -- Top bar --
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(
                    horizontal: HavenSpacing.lg),
                decoration: BoxDecoration(
                  color: haven.surface,
                  border: Border(
                    bottom: BorderSide(color: haven.border),
                  ),
                ),
                child: Row(
                  children: [
                    // Drawer button for tablet/mobile
                    if (!isDesktop)
                      Padding(
                        padding: const EdgeInsets.only(
                            right: HavenSpacing.sm),
                        child: IconButton(
                          icon: Icon(Icons.menu,
                              size: 20, color: haven.textSecondary),
                          onPressed: () {
                            if (isTablet) {
                              Scaffold.of(context).openDrawer();
                            } else {
                              ref
                                  .read(selectedPeerProvider.notifier)
                                  .state = null;
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ),
                    Text(
                      'Haven',
                      style: HavenTypography.subheading.copyWith(
                        color: haven.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Error tooltip
                    if (nodeState.error != null)
                      Tooltip(
                        message: nodeState.error!,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              right: HavenSpacing.md),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: haven.error,
                          ),
                        ),
                      ),
                    // Status dot
                    StatusDot(
                      color: _statusColor(haven, nodeState.status),
                      size: 8,
                    ),
                    const SizedBox(width: HavenSpacing.sm - 2),
                    Text(
                      _statusText(nodeState.status),
                      style: HavenTypography.bodySmall.copyWith(
                        color: haven.textSecondary,
                      ),
                    ),
                    const SizedBox(width: HavenSpacing.lg),
                    // Peer ID (tap to copy)
                    Tooltip(
                      message: localPeerId ?? 'Loading...',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                            haven.radiusSm),
                        onTap: () {
                          if (localPeerId != null) {
                            Clipboard.setData(
                                ClipboardData(text: localPeerId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Peer ID copied to clipboard',
                                  style: HavenTypography.body.copyWith(
                                    color: haven.textPrimary,
                                  ),
                                ),
                                backgroundColor: haven.elevated,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HavenSpacing.sm,
                            vertical: HavenSpacing.xs,
                          ),
                          child: Text(
                            shortPeerId,
                            style: HavenTypography.mono.copyWith(
                              color: haven.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Recovery phrase button
                    if (identity.mnemonic != null)
                      IconButton(
                        icon: Icon(Icons.key,
                            size: 18, color: haven.textSecondary),
                        tooltip: 'Recovery phrase',
                        onPressed: () => showMnemonicDialog(
                            context, identity.mnemonic!),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                  ],
                ),
              ),

              // -- Main content (adaptive) --
              Expanded(
                child: isDesktop
                    ? Row(
                        children: [
                          _buildSidebar(
                            peers: peers,
                            chatHistory: chatHistory,
                            selectedPeerId: selectedPeerId,
                            nodeStatus: nodeState.status,
                            activeRoom: activeRoom,
                          ),
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
                        ],
                      )
                    : isTablet
                        ? Container(
                            color: haven.background,
                            child: _buildChatOrEmpty(
                              haven: haven,
                              selectedPeerId: selectedPeerId,
                              peers: peers,
                            ),
                          )
                        : selectedPeerId != null
                            ? Container(
                                color: haven.background,
                                child: _buildChatOrEmpty(
                                  haven: haven,
                                  selectedPeerId: selectedPeerId,
                                  peers: peers,
                                ),
                              )
                            : _buildSidebar(
                                peers: peers,
                                chatHistory: chatHistory,
                                selectedPeerId: selectedPeerId,
                                nodeStatus: nodeState.status,
                                activeRoom: activeRoom,
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
