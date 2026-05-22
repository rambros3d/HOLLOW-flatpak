import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/providers/channel_chat_provider.dart';
import 'package:hollow/src/core/providers/guest_provider.dart';
import 'package:hollow/src/rust/api/crdt.dart' as crdt_api;
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/ui/components/hollow_button.dart';
import 'package:hollow/src/ui/components/hollow_dialog.dart';
import 'package:hollow/src/ui/components/hollow_text_field.dart';

void showBrowsePublicDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();

  showHollowDialog(
    context: context,
    builder: (dialogContext) {
      final hollow = HollowTheme.of(dialogContext);

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HollowSpacing.xl),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(HollowSpacing.xl),
              decoration: BoxDecoration(
                color: hollow.surface,
                borderRadius: BorderRadius.circular(hollow.radiusXl),
                border: Border.all(color: hollow.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse Public Channels',
                    style: TextStyle(
                      color: hollow.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: HollowSpacing.sm),
                  Text(
                    'Enter a server invite link or ID to browse its public channels as a guest.',
                    style: TextStyle(
                      color: hollow.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: HollowSpacing.lg),
                  HollowTextField(
                    controller: controller,
                    hintText: 'Server ID or invite link',
                    autofocus: true,
                    onSubmitted: (_) =>
                        _browse(dialogContext, ref, controller),
                  ),
                  const SizedBox(height: HollowSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      HollowButton.ghost(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: HollowSpacing.sm),
                      HollowButton.filled(
                        onPressed: () =>
                            _browse(dialogContext, ref, controller),
                        child: const Text('Browse'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _browse(
    BuildContext context, WidgetRef ref, TextEditingController controller) {
  final input = controller.text.trim();
  if (input.isEmpty) return;

  // Parse server ID from various invite formats:
  // - Raw hex ID: d847d4f67412fa0033aa125913565f8d
  // - Path-based: hollow://join/d847d4f6...
  // - Query-based: https://example.com/join?server=d847d4f6...
  String serverId = input;
  final serverParam = Uri.tryParse(input)?.queryParameters['server'];
  if (serverParam != null && serverParam.isNotEmpty) {
    serverId = serverParam;
  } else if (input.contains('/')) {
    serverId = input.split('/').last;
  }

  // Clear any existing guest state
  final existingGuest = ref.read(guestServerIdProvider);
  if (existingGuest != null) {
    crdt_api.leaveGuestRoom(serverId: existingGuest);
    ref.read(channelChatProvider.notifier).clearGuestServer(existingGuest);
  }

  ref.read(guestServerIdProvider.notifier).state = serverId;
  ref.read(guestServerNameProvider.notifier).state = '';
  ref.read(guestChannelListProvider.notifier).clear();
  ref.read(guestSelectedChannelProvider.notifier).state = null;
  ref.read(guestLoadingProvider.notifier).state = true;
  ref.read(guestHasMoreProvider.notifier).state = false;

  crdt_api.requestPublicChannels(serverId: serverId);

  Navigator.pop(context);
}
