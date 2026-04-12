import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/models/channel_chat_message.dart';
import 'package:hollow/src/core/models/chat_message.dart';
import 'package:hollow/src/core/models/file_attachment.dart';
import 'package:hollow/src/core/providers/archive_provider.dart';
import 'package:hollow/src/core/providers/download_manager_provider.dart';
import 'package:hollow/src/core/providers/identity_provider.dart';
import 'package:hollow/src/core/providers/profile_provider.dart';
import 'package:hollow/src/rust/api/network.dart' as network_api;
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:hollow/src/ui/chat/channel_message_bubble.dart';
import 'package:hollow/src/ui/chat/chat_input_shortcuts.dart';
import 'package:hollow/src/ui/chat/chat_pane.dart'
    show shouldGroup, shouldShowDateSeparator, DateSeparator;
import 'package:hollow/src/ui/chat/message_action_bar.dart';
import 'package:hollow/src/ui/chat/message_bubble.dart';
import 'package:hollow/src/ui/components/hollow_avatar.dart';
import 'package:hollow/src/ui/components/hollow_pressable.dart';
import 'package:hollow/src/ui/components/hollow_toast.dart';
import 'package:hollow/src/ui/dialogs/export_archive_dialog.dart';
import 'package:hollow/src/ui/dialogs/message_proof_dialog.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Right panel of "My Data" — shows empty state or a read-only message viewer.
class ArchiveMessageViewer extends ConsumerWidget {
  const ArchiveMessageViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hollow = HollowTheme.of(context);
    final selectedDm = ref.watch(archiveSelectedDmProvider);
    final selectedChannel = ref.watch(archiveSelectedChannelProvider);

    if (selectedDm == null && selectedChannel == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.archive,
              size: 64,
              color: hollow.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: HollowSpacing.lg),
            Text(
              'Select a conversation to browse your message history',
              style: HollowTypography.body.copyWith(
                color: hollow.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (selectedDm != null) {
      return _ArchiveDmViewer(
          key: ValueKey('dm:$selectedDm'), peerId: selectedDm);
    }

    final parts = selectedChannel!.split(':');
    final serverId = parts[0];
    final channelId = parts.sublist(1).join(':');
    return _ArchiveChannelViewer(
      key: ValueKey('ch:$selectedChannel'),
      serverId: serverId,
      channelId: channelId,
    );
  }
}

// ── DM Viewer ───────────────────────────────────────────────────

class _ArchiveDmViewer extends ConsumerWidget {
  final String peerId;

  const _ArchiveDmViewer({super.key, required this.peerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hollow = HollowTheme.of(context);
    final messagesAsync = ref.watch(archiveDmMessagesProvider(peerId));
    final profiles = ref.watch(profileProvider);
    final displayName = displayNameFor(profiles, peerId);

    return Container(
      color: hollow.background,
      child: Column(
        children: [
          _ArchiveHeader(
            leading: HollowAvatar(
              peerId: peerId,
              size: 24,
              imageBytes: profiles[peerId]?.avatarBytes,
            ),
            title: displayName,
            messageCount: messagesAsync.whenOrNull(data: (m) => m.length),
            onExport: () => showExportArchiveDialog(
              context,
              isDm: true,
              peerId: peerId,
              name: displayName,
              messageCount: messagesAsync.valueOrNull?.length ?? 0,
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Failed to load messages: $e',
                    style: TextStyle(color: hollow.error)),
              ),
              data: (messages) => _DmMessageList(
                messages: messages,
                peerId: peerId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DmMessageList extends ConsumerStatefulWidget {
  final List<ChatMessage> messages;
  final String peerId;

  const _DmMessageList({required this.messages, required this.peerId});

  @override
  ConsumerState<_DmMessageList> createState() => _DmMessageListState();
}

class _DmMessageListState extends ConsumerState<_DmMessageList> {
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final messages = widget.messages;

    if (messages.isEmpty) {
      return Center(
        child: Text('No messages',
            style:
                HollowTypography.body.copyWith(color: hollow.textSecondary)),
      );
    }

    final localPeerId = ref.watch(identityProvider).peerId ?? '';
    final profiles = ref.watch(profileProvider);

    return MessageActionBarScope(
      child: Builder(
        builder: (scopeContext) => NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              MessageActionBarScope.of(scopeContext)?.dismissAll();
            }
            return false;
          },
          child: SelectionArea(
            contextMenuBuilder: (_, __) => const SizedBox.shrink(),
            child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          vertical: HollowSpacing.sm,
        ),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          final prev = index > 0 ? messages[index - 1] : null;

          final showDate = shouldShowDateSeparator(
            msg.timestamp,
            prev?.timestamp,
          );

          final showHeader = prev == null ||
              showDate ||
              !shouldGroup(
                currentIsMe: msg.isMe,
                previousIsMe: prev.isMe,
                currentTime: msg.timestamp,
                previousTime: prev.timestamp,
              );

          // Look up reply text.
          String? replyToText;
          String? replyToSenderName;
          if (msg.replyToMid != null) {
            final replyMsg = messages
                .where((m) => m.messageId == msg.replyToMid)
                .firstOrNull;
            if (replyMsg != null) {
              replyToText = replyMsg.fileAttachment != null
                  ? (replyMsg.fileAttachment!.isImage
                      ? '\u{1F4F7} Image'
                      : '\u{1F4CE} ${replyMsg.fileAttachment!.fileName}')
                  : replyMsg.text;
              replyToSenderName = replyMsg.isMe
                  ? displayNameFor(profiles, localPeerId)
                  : displayNameFor(profiles, widget.peerId);
            }
          }

          Widget bubble = MessageBubble(
            message: msg,
            peerId: widget.peerId,
            showHeader: showHeader,
            replyToText: replyToText,
            replyToSenderName: replyToSenderName,
            onReplyTap: null,
            onToggleReaction: null,
          );

          // Deleted message overlay.
          if (msg.hiddenAt != null) {
            bubble =
                _DeletedOverlay(hiddenAt: msg.hiddenAt!, child: bubble);
          }

          // Wrap with hover actions (Save, Copy, Copy Image, Message Proof).
          final senderPeerId =
              msg.isMe ? localPeerId : widget.peerId;

          bubble = MessageHoverWrapper(
            isMe: msg.isMe,
            messageId: msg.messageId,
            currentText: msg.text,
            onDownload: msg.fileAttachment != null &&
                    msg.fileAttachment!.diskPath != null
                ? () => _saveFile(msg.fileAttachment!)
                : null,
            onCopy: msg.text.isNotEmpty &&
                    !msg.text.startsWith('[file:')
                ? () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    HollowToast.show(context, 'Copied to clipboard',
                        type: HollowToastType.success);
                  }
                : null,
            onCopyImage: msg.fileAttachment != null &&
                    msg.fileAttachment!.diskPath != null &&
                    msg.fileAttachment!.isImage
                ? () async {
                    final ok = await copyImageToClipboard(
                        msg.fileAttachment!.diskPath!);
                    if (mounted) {
                      HollowToast.show(
                        context,
                        ok
                            ? 'Image copied to clipboard'
                            : 'Failed to copy image',
                        type: ok
                            ? HollowToastType.success
                            : HollowToastType.error,
                      );
                    }
                  }
                : null,
            onInfo: () {
              showMessageProofDialog(
                context,
                MessageProofData(
                  senderPeerId: senderPeerId,
                  senderDisplayName:
                      displayNameFor(profiles, senderPeerId),
                  senderAvatar: profiles[senderPeerId]?.avatarBytes,
                  text: msg.text,
                  timestampMs: (msg.editedAt ?? msg.timestamp)
                      .millisecondsSinceEpoch,
                  signature: msg.signature,
                  publicKey: msg.publicKey,
                  messageId: msg.messageId,
                  context: msg.isMe ? widget.peerId : localPeerId,
                  msgType: 'dm',
                  fileAttachment: msg.fileAttachment,
                ),
              );
            },
            child: bubble,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDate) DateSeparator(date: msg.timestamp),
              bubble,
            ],
          );
        },
      ),
    ),
    ),
    ),
    );
  }

  Future<void> _saveFile(FileAttachment attachment) async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final isImage = attachment.isImage;
      final isGif = attachment.fileExt.toLowerCase() == 'gif';
      final allowedExtensions = isImage
          ? ['png', 'jpg', 'jpeg', 'webp', 'gif']
          : [attachment.fileExt];

      final baseName = attachment.fileName.contains('.')
          ? attachment.fileName
              .substring(0, attachment.fileName.lastIndexOf('.'))
          : attachment.fileName;

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save file',
        fileName: isImage
            ? (isGif ? '$baseName.gif' : '$baseName.png')
            : attachment.fileName,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (savePath == null || attachment.diskPath == null) return;

      final targetExt = savePath.contains('.')
          ? savePath.split('.').last.toLowerCase()
          : attachment.fileExt;

      if (isImage && targetExt != 'webp' && attachment.fileExt == 'webp') {
        final converted = await network_api.convertImageFormat(
          sourcePath: attachment.diskPath!,
          targetFormat: targetExt,
        );
        await File(savePath).writeAsBytes(converted);
      } else {
        await File(attachment.diskPath!).copy(savePath);
      }

      ref.read(downloadManagerStateProvider.notifier).recordSavedFile(
            savedPath: savePath,
            isImage: isImage,
            isVideo: attachment.videoThumb != null,
          );

      if (mounted) {
        HollowToast.show(context, 'File saved',
            type: HollowToastType.success);
      }
    } catch (e) {
      if (mounted) {
        HollowToast.show(context, 'Save failed: $e',
            type: HollowToastType.error);
      }
    } finally {
      _isPicking = false;
    }
  }
}

// ── Channel Viewer ──────────────────────────────────────────────

class _ArchiveChannelViewer extends ConsumerWidget {
  final String serverId;
  final String channelId;

  const _ArchiveChannelViewer({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hollow = HollowTheme.of(context);
    final key = '$serverId:$channelId';
    final messagesAsync = ref.watch(archiveChannelMessagesProvider(key));

    // Get channel/server name from the channel list provider.
    final channelGroups = ref.watch(archiveChannelListProvider).valueOrNull;
    String channelName = channelId;
    String serverName = serverId;
    if (channelGroups != null) {
      for (final group in channelGroups) {
        for (final ch in group.channels) {
          if (ch.serverId == serverId && ch.channelId == channelId) {
            channelName = ch.channelName;
            serverName = ch.serverName;
            break;
          }
        }
      }
    }

    return Container(
      color: hollow.background,
      child: Column(
        children: [
          _ArchiveHeader(
            leading: Text(
              '#',
              style: TextStyle(
                color: hollow.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            title: channelName,
            subtitle: 'in $serverName',
            messageCount:
                messagesAsync.whenOrNull(data: (m) => m.length),
            onExport: () => showExportArchiveDialog(
              context,
              isDm: false,
              serverId: serverId,
              channelId: channelId,
              channelName: channelName,
              name: channelName,
              messageCount: messagesAsync.valueOrNull?.length ?? 0,
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Failed to load messages: $e',
                    style: TextStyle(color: hollow.error)),
              ),
              data: (messages) => _ChannelMessageList(
                messages: messages,
                serverId: serverId,
                channelId: channelId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelMessageList extends ConsumerStatefulWidget {
  final List<ChannelChatMessage> messages;
  final String serverId;
  final String channelId;

  const _ChannelMessageList({
    required this.messages,
    required this.serverId,
    required this.channelId,
  });

  @override
  ConsumerState<_ChannelMessageList> createState() =>
      _ChannelMessageListState();
}

class _ChannelMessageListState extends ConsumerState<_ChannelMessageList> {
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final messages = widget.messages;

    if (messages.isEmpty) {
      return Center(
        child: Text('No messages',
            style:
                HollowTypography.body.copyWith(color: hollow.textSecondary)),
      );
    }

    final profiles = ref.watch(profileProvider);

    return MessageActionBarScope(
      child: Builder(
        builder: (scopeContext) => NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              MessageActionBarScope.of(scopeContext)?.dismissAll();
            }
            return false;
          },
          child: SelectionArea(
            contextMenuBuilder: (_, __) => const SizedBox.shrink(),
            child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          vertical: HollowSpacing.sm,
        ),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          final prev = index > 0 ? messages[index - 1] : null;

          final showDate = shouldShowDateSeparator(
            msg.timestamp,
            prev?.timestamp,
          );

          final showHeader = prev == null ||
              showDate ||
              !shouldGroup(
                currentIsMe: msg.isMe,
                previousIsMe: prev.isMe,
                currentTime: msg.timestamp,
                previousTime: prev.timestamp,
                currentSenderId: msg.senderId,
                previousSenderId: prev.senderId,
              );

          // Look up reply text.
          String? replyToText;
          String? replyToSenderName;
          if (msg.replyToMid != null) {
            final replyMsg = messages
                .where((m) => m.messageId == msg.replyToMid)
                .firstOrNull;
            if (replyMsg != null) {
              replyToText = replyMsg.fileAttachment != null
                  ? (replyMsg.fileAttachment!.isImage
                      ? '\u{1F4F7} Image'
                      : '\u{1F4CE} ${replyMsg.fileAttachment!.fileName}')
                  : replyMsg.text;
              replyToSenderName =
                  displayNameFor(profiles, replyMsg.senderId);
            }
          }

          Widget bubble = ChannelMessageBubble(
            message: msg,
            serverId: widget.serverId,
            showHeader: showHeader,
            replyToText: replyToText,
            replyToSenderName: replyToSenderName,
            onReplyTap: null,
            onToggleReaction: null,
          );

          // Deleted message overlay.
          if (msg.hiddenAt != null) {
            bubble =
                _DeletedOverlay(hiddenAt: msg.hiddenAt!, child: bubble);
          }

          // Wrap with hover actions.
          bubble = MessageHoverWrapper(
            isMe: msg.isMe,
            messageId: msg.messageId,
            currentText: msg.text,
            onDownload: msg.fileAttachment != null &&
                    msg.fileAttachment!.diskPath != null
                ? () => _saveFile(msg.fileAttachment!)
                : null,
            onCopy: msg.text.isNotEmpty &&
                    !msg.text.startsWith('[file:')
                ? () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    HollowToast.show(context, 'Copied to clipboard',
                        type: HollowToastType.success);
                  }
                : null,
            onCopyImage: msg.fileAttachment != null &&
                    msg.fileAttachment!.diskPath != null &&
                    msg.fileAttachment!.isImage
                ? () async {
                    final ok = await copyImageToClipboard(
                        msg.fileAttachment!.diskPath!);
                    if (mounted) {
                      HollowToast.show(
                        context,
                        ok
                            ? 'Image copied to clipboard'
                            : 'Failed to copy image',
                        type: ok
                            ? HollowToastType.success
                            : HollowToastType.error,
                      );
                    }
                  }
                : null,
            onInfo: () {
              showMessageProofDialog(
                context,
                MessageProofData(
                  senderPeerId: msg.senderId,
                  senderDisplayName:
                      displayNameFor(profiles, msg.senderId),
                  senderAvatar: profiles[msg.senderId]?.avatarBytes,
                  text: msg.text,
                  timestampMs: (msg.editedAt ?? msg.timestamp)
                      .millisecondsSinceEpoch,
                  signature: msg.signature,
                  publicKey: msg.publicKey,
                  messageId: msg.messageId,
                  context:
                      '${widget.serverId}:${widget.channelId}',
                  msgType: 'ch',
                  fileAttachment: msg.fileAttachment,
                ),
              );
            },
            child: bubble,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDate) DateSeparator(date: msg.timestamp),
              bubble,
            ],
          );
        },
      ),
    ),
    ),
    ),
    );
  }

  Future<void> _saveFile(FileAttachment attachment) async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final isImage = attachment.isImage;
      final isGif = attachment.fileExt.toLowerCase() == 'gif';
      final allowedExtensions = isImage
          ? ['png', 'jpg', 'jpeg', 'webp', 'gif']
          : [attachment.fileExt];

      final baseName = attachment.fileName.contains('.')
          ? attachment.fileName
              .substring(0, attachment.fileName.lastIndexOf('.'))
          : attachment.fileName;

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save file',
        fileName: isImage
            ? (isGif ? '$baseName.gif' : '$baseName.png')
            : attachment.fileName,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (savePath == null || attachment.diskPath == null) return;

      final targetExt = savePath.contains('.')
          ? savePath.split('.').last.toLowerCase()
          : attachment.fileExt;

      if (isImage && targetExt != 'webp' && attachment.fileExt == 'webp') {
        final converted = await network_api.convertImageFormat(
          sourcePath: attachment.diskPath!,
          targetFormat: targetExt,
        );
        await File(savePath).writeAsBytes(converted);
      } else {
        await File(attachment.diskPath!).copy(savePath);
      }

      ref.read(downloadManagerStateProvider.notifier).recordSavedFile(
            savedPath: savePath,
            isImage: isImage,
            isVideo: attachment.videoThumb != null,
          );

      if (mounted) {
        HollowToast.show(context, 'File saved',
            type: HollowToastType.success);
      }
    } catch (e) {
      if (mounted) {
        HollowToast.show(context, 'Save failed: $e',
            type: HollowToastType.error);
      }
    } finally {
      _isPicking = false;
    }
  }
}

// ── Shared header ───────────────────────────────────────────────

class _ArchiveHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final int? messageCount;
  final VoidCallback? onExport;

  const _ArchiveHeader({
    required this.leading,
    required this.title,
    this.subtitle,
    this.messageCount,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: HollowSpacing.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: hollow.border)),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: HollowSpacing.sm),
          Expanded(
            child: subtitle != null
                ? Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: title,
                        style: HollowTypography.body.copyWith(
                          color: hollow.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '  $subtitle',
                        style: HollowTypography.caption.copyWith(
                          color: hollow.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    title,
                    style: HollowTypography.body.copyWith(
                      color: hollow.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (messageCount != null)
            Text(
              '$messageCount messages',
              style: HollowTypography.caption.copyWith(
                color: hollow.textSecondary,
                fontSize: 11,
              ),
            ),
          if (onExport != null) ...[
            const SizedBox(width: HollowSpacing.sm),
            HollowPressable(
              onTap: onExport,
              borderRadius: BorderRadius.circular(hollow.radiusSm),
              padding: const EdgeInsets.all(6),
              child: Icon(LucideIcons.fileOutput,
                  size: 16, color: hollow.accent),
            ),
          ],
          const SizedBox(width: HollowSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hollow.elevated,
              borderRadius: BorderRadius.circular(hollow.radiusSm),
            ),
            child: Text(
              'read-only',
              style: HollowTypography.caption.copyWith(
                color: hollow.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Deleted message overlay ─────────────────────────────────────

class _DeletedOverlay extends StatelessWidget {
  final DateTime hiddenAt;
  final Widget child;

  const _DeletedOverlay({required this.hiddenAt, required this.child});

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final time =
        '${hiddenAt.hour.toString().padLeft(2, '0')}:${hiddenAt.minute.toString().padLeft(2, '0')}';

    return AnimatedOpacity(
      opacity: 0.4,
      duration: Duration.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          Padding(
            padding: const EdgeInsets.only(left: 42, top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.trash2,
                    size: 11,
                    color: hollow.error.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  'Deleted at $time',
                  style: HollowTypography.caption.copyWith(
                    color: hollow.error.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
