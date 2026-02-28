import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/providers/chat_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/chat/message_bubble.dart';
import 'package:haven/src/ui/components/haven_avatar.dart';
import 'package:haven/src/ui/components/status_dot.dart';

class ChatPane extends ConsumerStatefulWidget {
  final String peerId;
  final bool isEncrypted;

  const ChatPane({
    super.key,
    required this.peerId,
    required this.isEncrypted,
  });

  @override
  ConsumerState<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends ConsumerState<ChatPane> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_historyLoaded) return;
    _historyLoaded = true;
    await ref.read(chatProvider.notifier).loadHistory(widget.peerId);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(chatProvider.notifier).sendMessage(widget.peerId, text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final chatHistory = ref.watch(chatProvider);
    final messages = chatHistory[widget.peerId] ?? [];

    return Column(
      children: [
        // Peer ID header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HavenSpacing.lg,
            vertical: HavenSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: haven.surface,
            border: Border(
              bottom: BorderSide(color: haven.border),
            ),
          ),
          child: Row(
            children: [
              HavenAvatar(peerId: widget.peerId, size: 28),
              const SizedBox(width: HavenSpacing.sm),
              StatusDot(color: haven.success, size: 8),
              const SizedBox(width: HavenSpacing.sm),
              Expanded(
                child: SelectableText(
                  widget.peerId,
                  style: HavenTypography.mono.copyWith(
                    color: haven.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              if (widget.isEncrypted) ...[
                Icon(
                  Icons.lock,
                  size: 14,
                  color: haven.success,
                ),
                const SizedBox(width: HavenSpacing.xs),
                Text(
                  'Encrypted',
                  style: HavenTypography.caption.copyWith(
                    color: haven.success,
                  ),
                ),
                const SizedBox(width: HavenSpacing.sm),
              ],
              IconButton(
                icon: Icon(Icons.copy, size: 16, color: haven.textSecondary),
                tooltip: 'Copy peer ID',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.peerId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Peer ID copied',
                        style: HavenTypography.body.copyWith(
                          color: haven.textPrimary,
                        ),
                      ),
                      backgroundColor: haven.elevated,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: Container(
            color: haven.background,
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: haven.textSecondary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: HavenSpacing.md),
                        Text(
                          'No messages yet. Say hello!',
                          style: HavenTypography.body.copyWith(
                            color: haven.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(HavenSpacing.md),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(message: messages[index]);
                    },
                  ),
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HavenSpacing.md,
            vertical: HavenSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: haven.surface,
            border: Border(
              top: BorderSide(color: haven.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: HavenTypography.body.copyWith(
                    color: haven.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: HavenTypography.body.copyWith(
                      color: haven.textSecondary,
                    ),
                    filled: true,
                    fillColor: haven.elevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(haven.radiusLg),
                      borderSide: BorderSide(color: haven.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(haven.radiusLg),
                      borderSide: BorderSide(color: haven.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(haven.radiusLg),
                      borderSide: BorderSide(color: haven.accent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: HavenSpacing.lg,
                      vertical: HavenSpacing.sm + 2,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: HavenSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: haven.accent,
                  borderRadius: BorderRadius.circular(haven.radiusMd),
                ),
                child: IconButton(
                  onPressed: _handleSend,
                  icon: Icon(
                    Icons.send,
                    color: haven.textOnAccent,
                    size: 20,
                  ),
                  padding: const EdgeInsets.all(HavenSpacing.sm),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
