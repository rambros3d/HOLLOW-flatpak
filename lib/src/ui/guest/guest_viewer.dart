import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/providers/channel_chat_provider.dart';
import 'package:hollow/src/core/providers/guest_provider.dart';
import 'package:hollow/src/rust/api/crdt.dart' as crdt_api;
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/ui/chat/channel_message_bubble.dart';
import 'package:hollow/src/ui/components/hollow_button.dart';
import 'package:hollow/src/ui/components/hollow_pressable.dart';
import 'package:lucide_icons/lucide_icons.dart';

class GuestViewer extends ConsumerStatefulWidget {
  const GuestViewer({super.key});

  @override
  ConsumerState<GuestViewer> createState() => _GuestViewerState();
}

class _GuestViewerState extends ConsumerState<GuestViewer> {
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && ref.read(guestLoadingProvider)) {
        ref.read(guestLoadingProvider.notifier).state = false;
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _close() {
    final serverId = ref.read(guestServerIdProvider);
    if (serverId != null) {
      crdt_api.leaveGuestRoom(serverId: serverId);
      ref.read(channelChatProvider.notifier).clearGuestServer(serverId);
    }
    ref.read(guestServerIdProvider.notifier).state = null;
    ref.read(guestServerNameProvider.notifier).state = '';
    ref.read(guestChannelListProvider.notifier).clear();
    ref.read(guestSelectedChannelProvider.notifier).state = null;
    ref.read(guestLoadingProvider.notifier).state = false;
    ref.read(guestHasMoreProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final serverId = ref.watch(guestServerIdProvider) ?? '';
    final serverName = ref.watch(guestServerNameProvider);
    final channels = ref.watch(guestChannelListProvider);
    final selectedChannel = ref.watch(guestSelectedChannelProvider);
    final isLoading = ref.watch(guestLoadingProvider);

    return Column(
      children: [
        // Guest banner
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HollowSpacing.lg,
            vertical: HollowSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: hollow.accent.withValues(alpha: 0.1),
            border: Border(bottom: BorderSide(color: hollow.border)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.globe, size: 16, color: hollow.accent),
              const SizedBox(width: HollowSpacing.sm),
              Expanded(
                child: Text(
                  serverName.isNotEmpty
                      ? 'Viewing $serverName as guest'
                      : 'Browsing as guest',
                  style: TextStyle(
                    color: hollow.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              HollowButton.ghost(
                compact: true,
                onPressed: _close,
                child: const Text('Close'),
              ),
            ],
          ),
        ),

        // Main content
        Expanded(
          child: Row(
            children: [
              // Channel sidebar
              Container(
                width: 200,
                decoration: BoxDecoration(
                  color: hollow.surface,
                  border: Border(right: BorderSide(color: hollow.border)),
                ),
                child: isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: hollow.accent,
                              ),
                            ),
                            const SizedBox(height: HollowSpacing.sm),
                            Text(
                              'Looking for members...',
                              style: TextStyle(
                                color: hollow.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : channels.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(HollowSpacing.lg),
                              child: Text(
                                'No public channels found.\nMembers may be offline.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: hollow.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              vertical: HollowSpacing.sm,
                              horizontal: HollowSpacing.sm,
                            ),
                            itemCount: channels.length,
                            itemBuilder: (context, index) {
                              final ch = channels[index];
                              final isSelected =
                                  selectedChannel == ch.channelId;
                              return _GuestChannelTile(
                                name: ch.name,
                                isSelected: isSelected,
                                onTap: () {
                                  ref
                                      .read(guestSelectedChannelProvider
                                          .notifier)
                                      .state = ch.channelId;
                                  crdt_api.requestPublicChannelSync(
                                    serverId: serverId,
                                    channelId: ch.channelId,
                                  );
                                },
                              );
                            },
                          ),
              ),

              // Chat pane
              Expanded(
                child: selectedChannel == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.hash,
                                size: 48,
                                color:
                                    hollow.textSecondary.withValues(alpha: 0.3)),
                            const SizedBox(height: HollowSpacing.md),
                            Text(
                              'Select a channel to browse',
                              style: TextStyle(
                                color: hollow.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _GuestChatPane(
                        key: ValueKey('guest:$serverId:$selectedChannel'),
                        serverId: serverId,
                        channelId: selectedChannel,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuestChannelTile extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _GuestChannelTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: HollowPressable(
        onTap: onTap,
        subtle: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: HollowSpacing.sm + 2,
            vertical: HollowSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? hollow.accentMuted : Colors.transparent,
            borderRadius: BorderRadius.circular(hollow.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.hash,
                size: 16,
                color: isSelected ? hollow.accent : hollow.textSecondary,
              ),
              const SizedBox(width: HollowSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? hollow.textPrimary
                        : hollow.textSecondary,
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestChatPane extends ConsumerWidget {
  final String serverId;
  final String channelId;

  const _GuestChatPane({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hollow = HollowTheme.of(context);
    final key = '$serverId:$channelId';
    final messages = ref.watch(channelChatProvider.select((s) => s[key])) ?? [];
    final hasMore = ref.watch(guestHasMoreProvider);
    final channelName = ref.watch(guestChannelListProvider
        .select((chs) => chs.where((c) => c.channelId == channelId).firstOrNull?.name ?? channelId));

    // Filter out hidden (deleted) messages
    final visible = messages.where((m) => m.hiddenAt == null).toList();

    return Column(
      children: [
        // Channel header
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: HollowSpacing.lg),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: hollow.border)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.hash, size: 18, color: hollow.textSecondary),
              const SizedBox(width: HollowSpacing.sm),
              Text(
                channelName,
                style: TextStyle(
                  color: hollow.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Message list
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(
                      color: hollow.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      vertical: HollowSpacing.sm),
                  itemCount: visible.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (hasMore && index == 0) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(HollowSpacing.sm),
                          child: HollowButton.ghost(
                            compact: true,
                            onPressed: () {
                              final oldest = visible.first.timestamp;
                              crdt_api.requestPublicChannelSync(
                                serverId: serverId,
                                channelId: channelId,
                                beforeTimestamp:
                                    oldest.millisecondsSinceEpoch,
                              );
                            },
                            child: const Text('Load more'),
                          ),
                        ),
                      );
                    }
                    final msgIndex = hasMore ? index - 1 : index;
                    final msg = visible[msgIndex];
                    final prevMsg = msgIndex > 0 ? visible[msgIndex - 1] : null;
                    final showHeader = prevMsg == null ||
                        prevMsg.senderId != msg.senderId ||
                        msg.timestamp
                                .difference(prevMsg.timestamp)
                                .inMinutes >
                            5;
                    return ChannelMessageBubble(
                      message: msg,
                      serverId: serverId,
                      showHeader: showHeader,
                    );
                  },
                ),
        ),

        // Guest footer
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HollowSpacing.lg,
            vertical: HollowSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: hollow.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.lock, size: 14, color: hollow.textSecondary),
              const SizedBox(width: HollowSpacing.sm),
              Text(
                'Join this server to send messages',
                style: TextStyle(
                  color: hollow.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
