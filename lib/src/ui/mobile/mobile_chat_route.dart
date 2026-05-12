import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/models/chat_message.dart';
import 'package:hollow/src/core/providers/banner_provider.dart';
import 'package:hollow/src/core/providers/chat_provider.dart';
import 'package:hollow/src/core/providers/channel_chat_provider.dart';
import 'package:hollow/src/core/providers/peers_provider.dart';
import 'package:hollow/src/core/providers/profile_provider.dart';
import 'package:hollow/src/core/providers/typing_provider.dart';
import 'package:hollow/src/core/providers/unread_provider.dart';
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:hollow/src/ui/chat/message_bubble.dart';
import 'package:hollow/src/ui/chat/channel_message_bubble.dart';
import 'package:hollow/src/ui/components/animated_gif_image.dart';
import 'package:hollow/src/ui/components/hollow_avatar.dart';
import 'package:hollow/src/ui/components/hollow_pressable.dart';
import 'package:hollow/src/ui/components/hollow_toast.dart';
import 'package:hollow/src/ui/components/status_dot.dart';
import 'package:hollow/src/rust/api/network.dart' as network_api;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class MobileChatRoute extends ConsumerStatefulWidget {
  final String? peerId;
  final String? serverId;
  final String? channelId;
  final String? channelName;

  const MobileChatRoute({
    super.key,
    this.peerId,
    this.serverId,
    this.channelId,
    this.channelName,
  });

  bool get isDm => peerId != null;

  @override
  ConsumerState<MobileChatRoute> createState() => _MobileChatRouteState();
}

class _MobileChatRouteState extends ConsumerState<MobileChatRoute> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ItemScrollController();
  final _positionsListener = ItemPositionsListener.create();

  String? _replyToMessageId;
  String? _replyToText;
  String? _replyToSenderName;
  DateTime? _lastTypingSent;
  bool _isInAutoScrollZone = true;

  @override
  void initState() {
    super.initState();
    _positionsListener.itemPositions.addListener(_checkAutoScroll);
    if (widget.isDm) {
      ref.read(chatProvider.notifier).loadHistory(widget.peerId!).then((_) {
        if (mounted) _scrollToBottom();
      });
      ref.read(unreadProvider.notifier).markDmSeen(
            widget.peerId!,
            null,
          );
    } else {
      ref.read(channelChatProvider.notifier).loadHistory(
            widget.serverId!,
            widget.channelId!,
          ).then((_) {
        if (mounted) _scrollToBottom();
      });
      ref.read(unreadProvider.notifier).markChannelSeen(
            widget.serverId!,
            widget.channelId!,
            null,
          );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _checkAutoScroll() {
    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final maxIndex = positions.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    final count = widget.isDm
        ? (ref.read(chatProvider)[widget.peerId!]?.length ?? 0)
        : (ref.read(channelChatProvider)[widget.channelId!]?.length ?? 0);
    _isInAutoScrollZone = maxIndex >= count - 2;
  }

  void _scrollToBottom() {
    final count = widget.isDm
        ? (ref.read(chatProvider)[widget.peerId!]?.length ?? 0)
        : (ref.read(channelChatProvider)[widget.channelId!]?.length ?? 0);
    if (count > 0) {
      _scrollController.scrollTo(
        index: count,
        duration: const Duration(milliseconds: 150),
      );
    }
  }

  void _onTextChanged(String text) {
    if (text.isEmpty || !widget.isDm) return;
    final now = DateTime.now();
    if (_lastTypingSent != null && now.difference(_lastTypingSent!).inSeconds < 3) return;
    _lastTypingSent = now;
    try {
      network_api.sendTypingIndicator(serverId: '', channelId: widget.peerId!);
    } catch (_) {}
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _lastTypingSent = null;
    _focusNode.requestFocus();
    final replyMid = _replyToMessageId;
    setState(() {
      _replyToMessageId = null;
      _replyToText = null;
      _replyToSenderName = null;
    });

    if (widget.isDm) {
      await ref.read(chatProvider.notifier).sendMessage(
            widget.peerId!,
            text,
            replyToMid: replyMid,
          );
    } else {
      await ref.read(channelChatProvider.notifier).sendMessage(
            widget.serverId!,
            widget.channelId!,
            text,
            replyToMid: replyMid,
          );
    }
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    const maxDmBytes = 34 * 1024 * 1024;
    if (widget.isDm && (file.size) > maxDmBytes) {
      if (mounted) {
        HollowToast.show(context, 'File too large. DM limit is 34 MB.',
            type: HollowToastType.error);
      }
      return;
    }

    try {
      final messageId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      await network_api.sendFile(
        peerId: widget.isDm ? widget.peerId : null,
        serverId: widget.isDm ? null : widget.serverId,
        channelId: widget.isDm ? null : widget.channelId,
        filePath: file.path!,
        messageId: messageId,
        messageText: '',
      );
    } catch (e) {
      if (mounted) {
        HollowToast.show(context, 'Failed to send file',
            type: HollowToastType.error);
      }
    }
  }

  void _setReply(String messageId, String senderName, String text) {
    setState(() {
      _replyToMessageId = messageId;
      _replyToSenderName = senderName;
      _replyToText = text;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);

    return Scaffold(
      backgroundColor: hollow.background,
      body: SafeArea(
        child: Column(
          children: [
            _MobileChatHeader(
              peerId: widget.peerId,
              channelName: widget.channelName,
            ),
            Expanded(
              child: widget.isDm ? _buildDmMessages() : _buildChannelMessages(),
            ),
            _TypingBar(
              contextKey: widget.isDm
                  ? widget.peerId!
                  : '${widget.serverId}:${widget.channelId}',
            ),
            if (_replyToMessageId != null)
              _ReplyPreview(
                senderName: _replyToSenderName ?? '',
                text: _replyToText ?? '',
                onCancel: () => setState(() {
                  _replyToMessageId = null;
                  _replyToText = null;
                  _replyToSenderName = null;
                }),
              ),
            _MobileInputBar(
              controller: _controller,
              focusNode: _focusNode,
              onSend: _handleSend,
              onPickFile: _pickFile,
              onChanged: _onTextChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDmMessages() {
    final chatHistory = ref.watch(chatProvider);
    final messages = chatHistory[widget.peerId!] ?? [];
    final profiles = ref.watch(profileProvider);

    ref.listen<Map<String, List<ChatMessage>>>(chatProvider, (prev, next) {
      final prevLen = (prev?[widget.peerId!] ?? const []).length;
      final nextLen = (next[widget.peerId!] ?? const []).length;
      if (nextLen > prevLen && _isInAutoScrollZone) _scrollToBottom();
    });

    if (messages.isEmpty) {
      return Center(
        child: Text('No messages yet', style: HollowTypography.body.copyWith(
          color: HollowTheme.of(context).textSecondary,
        )),
      );
    }

    return ScrollablePositionedList.builder(
      itemScrollController: _scrollController,
      itemPositionsListener: _positionsListener,
      itemCount: messages.length + 1,
      padding: const EdgeInsets.symmetric(
        horizontal: HollowSpacing.sm,
        vertical: HollowSpacing.sm,
      ),
      itemBuilder: (context, index) {
        if (index == messages.length) return const SizedBox(height: 8);
        final msg = messages[index];
        final prev = index > 0 ? messages[index - 1] : null;

        final showDate = prev == null || !_sameDay(prev.timestamp, msg.timestamp);
        final showHeader = prev == null ||
            prev.isMe != msg.isMe ||
            msg.timestamp.difference(prev.timestamp).inMinutes > 5;

        final bubble = GestureDetector(
          onLongPress: () {
            final name = msg.isMe
                ? 'You'
                : displayNameFor(profiles, widget.peerId!);
            _setReply(msg.messageId ?? '', name, msg.text);
          },
          child: MessageBubble(
            message: msg,
            peerId: widget.peerId!,
            showHeader: showHeader,
          ),
        );

        final messageWidget = showHeader
            ? Padding(
                padding: const EdgeInsets.only(top: HollowSpacing.sm + 2),
                child: bubble,
              )
            : bubble;

        if (showDate) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DateSeparator(date: msg.timestamp),
              messageWidget,
            ],
          );
        }
        return messageWidget;
      },
    );
  }

  Widget _buildChannelMessages() {
    final channelHistory = ref.watch(channelChatProvider);
    final messages = channelHistory[widget.channelId!] ?? [];
    final profiles = ref.watch(profileProvider);

    ref.listen(channelChatProvider, (prev, next) {
      final prevLen = (prev?[widget.channelId!] ?? const []).length;
      final nextLen = (next[widget.channelId!] ?? const []).length;
      if (nextLen > prevLen && _isInAutoScrollZone) _scrollToBottom();
    });

    if (messages.isEmpty) {
      return Center(
        child: Text('No messages yet', style: HollowTypography.body.copyWith(
          color: HollowTheme.of(context).textSecondary,
        )),
      );
    }

    return ScrollablePositionedList.builder(
      itemScrollController: _scrollController,
      itemPositionsListener: _positionsListener,
      itemCount: messages.length + 1,
      padding: const EdgeInsets.symmetric(
        horizontal: HollowSpacing.sm,
        vertical: HollowSpacing.sm,
      ),
      itemBuilder: (context, index) {
        if (index == messages.length) return const SizedBox(height: 8);
        final msg = messages[index];
        final prev = index > 0 ? messages[index - 1] : null;

        final showDate = prev == null || !_sameDay(prev.timestamp, msg.timestamp);
        final showHeader = prev == null ||
            prev.senderId != msg.senderId ||
            msg.timestamp.difference(prev.timestamp).inMinutes > 5;

        final bubble = GestureDetector(
          onLongPress: () {
            final name = displayNameFor(profiles, msg.senderId);
            _setReply(msg.messageId ?? '', name, msg.text);
          },
          child: ChannelMessageBubble(
            message: msg,
            serverId: widget.serverId!,
            showHeader: showHeader,
          ),
        );

        final messageWidget = showHeader
            ? Padding(
                padding: const EdgeInsets.only(top: HollowSpacing.sm + 2),
                child: bubble,
              )
            : bubble;

        if (showDate) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DateSeparator(date: msg.timestamp),
              messageWidget,
            ],
          );
        }
        return messageWidget;
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────
// Chat header with back button + name (tappable for profile sheet)
// ─────────────────────────────────────────────────

class _MobileChatHeader extends ConsumerWidget {
  final String? peerId;
  final String? channelName;

  const _MobileChatHeader({this.peerId, this.channelName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hollow = HollowTheme.of(context);
    final profiles = ref.watch(profileProvider);
    final isDm = peerId != null;

    String title;
    if (isDm) {
      title = displayNameFor(profiles, peerId!);
    } else {
      title = '# ${channelName ?? 'Channel'}';
    }

    final isOnline = isDm &&
        ref.watch(peersProvider.select((p) => p.containsKey(peerId)));

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: hollow.surface,
        border: Border(bottom: BorderSide(color: hollow.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: HollowSpacing.xs),
      child: Row(
        children: [
          HollowPressable(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(hollow.radiusSm),
            padding: const EdgeInsets.all(HollowSpacing.sm),
            child: Icon(LucideIcons.arrowLeft, size: 22, color: hollow.textPrimary),
          ),
          const SizedBox(width: HollowSpacing.xs),
          if (isDm) ...[
            SizedBox(
              width: 32, height: 32,
              child: Stack(
                children: [
                  HollowAvatar(peerId: peerId!, size: 32),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: hollow.surface, shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(1),
                      child: StatusDot(
                        color: isOnline ? hollow.success : hollow.textSecondary,
                        size: 8, pulse: isOnline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: HollowSpacing.sm),
          ],
          Expanded(
            child: HollowPressable(
              onTap: isDm ? () => _showProfileSheet(context, ref, peerId!) : null,
              borderRadius: BorderRadius.circular(hollow.radiusSm),
              padding: const EdgeInsets.symmetric(vertical: HollowSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: HollowTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hollow.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isDm)
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: HollowTypography.caption.copyWith(
                        color: isOnline ? hollow.success : hollow.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref, String peerId) {
    final hollow = HollowTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: hollow.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(hollow.radiusXl)),
      ),
      builder: (_) => _ProfileSheet(peerId: peerId),
    );
  }
}

// ─────────────────────────────────────────────────
// Input bar (attach + text field + send)
// ─────────────────────────────────────────────────

class _MobileInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onPickFile;
  final ValueChanged<String> onChanged;

  const _MobileInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onPickFile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HollowSpacing.sm,
        vertical: HollowSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: hollow.surface,
        border: Border(top: BorderSide(color: hollow.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          HollowPressable(
            onTap: onPickFile,
            borderRadius: BorderRadius.circular(hollow.radiusMd),
            padding: const EdgeInsets.all(HollowSpacing.sm),
            child: Icon(LucideIcons.paperclip, color: hollow.textSecondary, size: 22),
          ),
          const SizedBox(width: HollowSpacing.xs),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: HollowTypography.body.copyWith(color: hollow.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: HollowTypography.body.copyWith(color: hollow.textSecondary),
                  filled: true,
                  fillColor: hollow.background,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: HollowSpacing.md,
                    vertical: HollowSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(hollow.radiusXl),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: HollowSpacing.xs),
          HollowPressable(
            onTap: onSend,
            borderRadius: BorderRadius.circular(hollow.radiusMd),
            backgroundColor: hollow.accent,
            padding: const EdgeInsets.all(HollowSpacing.sm + 2),
            child: Icon(LucideIcons.send, color: hollow.textOnAccent, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Reply preview bar
// ─────────────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final String senderName;
  final String text;
  final VoidCallback onCancel;

  const _ReplyPreview({
    required this.senderName,
    required this.text,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HollowSpacing.lg,
        vertical: HollowSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: hollow.surface,
        border: Border(top: BorderSide(color: hollow.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 2, height: 28,
            decoration: BoxDecoration(
              color: hollow.accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: HollowSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(senderName, style: HollowTypography.caption.copyWith(
                  color: hollow.accent, fontWeight: FontWeight.w600,
                )),
                Text(text, style: HollowTypography.caption.copyWith(
                  color: hollow.textSecondary,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          HollowPressable(
            onTap: onCancel,
            borderRadius: BorderRadius.circular(hollow.radiusSm),
            padding: const EdgeInsets.all(HollowSpacing.xs),
            child: Icon(LucideIcons.x, size: 16, color: hollow.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Date separator
// ─────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final now = DateTime.now();
    String label;
    if (_sameDay(date, now)) {
      label = 'Today';
    } else if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HollowSpacing.md),
      child: Row(
        children: [
          Expanded(child: Divider(color: hollow.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HollowSpacing.md),
            child: Text(label, style: HollowTypography.caption.copyWith(
              color: hollow.textSecondary,
            )),
          ),
          Expanded(child: Divider(color: hollow.border, height: 1)),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────
// Typing indicator bar
// ─────────────────────────────────────────────────

class _TypingBar extends ConsumerWidget {
  final String contextKey;

  const _TypingBar({required this.contextKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hollow = HollowTheme.of(context);
    final typingPeers = ref.watch(typingProvider)[contextKey] ?? {};
    if (typingPeers.isEmpty) return const SizedBox.shrink();

    final profiles = ref.watch(profileProvider);
    final names = typingPeers
        .map((pid) => displayNameFor(profiles, pid))
        .toList();

    String text;
    if (names.length == 1) {
      text = '${names.first} is typing...';
    } else if (names.length == 2) {
      text = '${names[0]} and ${names[1]} are typing...';
    } else {
      text = '${names.length} people are typing...';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HollowSpacing.lg,
        vertical: HollowSpacing.xs,
      ),
      child: Text(
        text,
        style: HollowTypography.caption.copyWith(
          color: hollow.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Profile bottom sheet with banner
// ─────────────────────────────────────────────────

Color _bannerColorFromId(String id) {
  final hash = id.hashCode;
  final hue = ((hash % 360).abs() + 40) % 360;
  return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.45, 0.35).toColor();
}

class _ProfileSheet extends ConsumerWidget {
  final String peerId;

  const _ProfileSheet({required this.peerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hollow = HollowTheme.of(context);
    final profiles = ref.watch(profileProvider);
    final profile = profiles[peerId];
    final name = displayNameFor(profiles, peerId);
    final isOnline = ref.watch(peersProvider.select((p) => p.containsKey(peerId)));
    final bannerBytes = ref.watch(bannerProvider(peerId)).valueOrNull;
    final bannerColor = _bannerColorFromId(peerId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.only(top: HollowSpacing.sm),
          child: Container(
            width: 32, height: 4,
            decoration: BoxDecoration(
              color: hollow.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Banner
        const SizedBox(height: HollowSpacing.sm),
        SizedBox(
          height: 180,
          width: double.infinity,
          child: bannerBytes != null && bannerBytes.isNotEmpty
              ? AnimatedGifImage(
                  bytes: bannerBytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [bannerColor, bannerColor.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [bannerColor, bannerColor.withValues(alpha: 0.7)],
                    ),
                  ),
                ),
        ),

        // Avatar overlapping banner
        Transform.translate(
          offset: const Offset(0, -36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(hollow.radiusMd),
                  border: Border.all(color: hollow.surface, width: 3),
                ),
                child: HollowAvatar(peerId: peerId, size: 72),
              ),
              const SizedBox(height: HollowSpacing.sm),
              Text(name, style: HollowTypography.heading.copyWith(
                color: hollow.textPrimary,
              )),
              const SizedBox(height: HollowSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StatusDot(
                    color: isOnline ? hollow.success : hollow.textSecondary,
                    size: 8, pulse: isOnline,
                  ),
                  const SizedBox(width: HollowSpacing.xs),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: HollowTypography.body.copyWith(
                      color: isOnline ? hollow.success : hollow.textSecondary,
                    ),
                  ),
                ],
              ),
              if (profile?.status != null && profile!.status.isNotEmpty) ...[
                const SizedBox(height: HollowSpacing.sm),
                Text(
                  profile.status,
                  style: HollowTypography.bodySmall.copyWith(
                    color: hollow.accent,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (profile?.aboutMe != null && profile!.aboutMe.isNotEmpty) ...[
                const SizedBox(height: HollowSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HollowSpacing.xl),
                  child: Text(
                    profile.aboutMe,
                    style: HollowTypography.body.copyWith(
                      color: hollow.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: HollowSpacing.md),
            ],
          ),
        ),
      ],
    );
  }
}
