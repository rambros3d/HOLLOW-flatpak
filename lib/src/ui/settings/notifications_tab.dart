import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/providers/channel_provider.dart';
import 'package:haven/src/core/providers/notification_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Notifications settings tab in Server Settings.
///
/// Shows server-wide default (All / Mentions / Nothing) and
/// per-channel overrides (Default / All / Mentions / Nothing).
class NotificationsTab extends ConsumerWidget {
  final String serverId;

  const NotificationsTab({super.key, required this.serverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haven = HavenTheme.of(context);
    final notifState = ref.watch(notificationSettingsProvider);
    final notifNotifier = ref.read(notificationSettingsProvider.notifier);
    final channels = ref.watch(channelListProvider);
    final serverLevel = notifState.serverLevels[serverId] ??
        NotificationLevel.all;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HavenSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Server-wide setting
          Text(
            'SERVER NOTIFICATIONS',
            style: HavenTypography.caption.copyWith(
              color: haven.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: HavenSpacing.sm),

          Text(
            'Default notification level for all channels in this server.',
            style: HavenTypography.body.copyWith(
              color: haven.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: HavenSpacing.md),

          _NotificationLevelSelector(
            value: serverLevel,
            onChanged: (level) =>
                notifNotifier.setServerLevel(serverId, level),
          ),

          const SizedBox(height: HavenSpacing.xxl),

          // Per-channel overrides
          Text(
            'CHANNEL OVERRIDES',
            style: HavenTypography.caption.copyWith(
              color: haven.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: HavenSpacing.xs),
          Text(
            'Override notification settings for specific channels.',
            style: HavenTypography.body.copyWith(
              color: haven.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: HavenSpacing.md),

          if (channels.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: HavenSpacing.xl),
              child: Center(
                child: Text(
                  'No channels',
                  style: HavenTypography.body.copyWith(
                    color: haven.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...channels.values.map((channel) {
              final override = notifNotifier.channelOverride(
                  serverId, channel.channelId);

              return Padding(
                padding: const EdgeInsets.only(
                    bottom: HavenSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.hash,
                      size: 16,
                      color: haven.textSecondary,
                    ),
                    const SizedBox(width: HavenSpacing.sm),
                    Expanded(
                      child: Text(
                        channel.name,
                        style: HavenTypography.body.copyWith(
                          color: haven.textPrimary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: HavenSpacing.md),
                    _ChannelOverrideDropdown(
                      value: override,
                      onChanged: (level) =>
                          notifNotifier.setChannelOverride(
                              serverId, channel.channelId, level),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Server-level notification picker: All / Mentions / Nothing.
class _NotificationLevelSelector extends StatelessWidget {
  final NotificationLevel value;
  final ValueChanged<NotificationLevel> onChanged;

  const _NotificationLevelSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Row(
      children: [
        _LevelChip(
          label: 'All Messages',
          icon: LucideIcons.bell,
          isSelected: value == NotificationLevel.all,
          onTap: () => onChanged(NotificationLevel.all),
        ),
        const SizedBox(width: HavenSpacing.sm),
        _LevelChip(
          label: 'Mentions Only',
          icon: LucideIcons.atSign,
          isSelected: value == NotificationLevel.mentions,
          onTap: () => onChanged(NotificationLevel.mentions),
          activeColor: haven.warning,
        ),
        const SizedBox(width: HavenSpacing.sm),
        _LevelChip(
          label: 'Nothing',
          icon: LucideIcons.bellOff,
          isSelected: value == NotificationLevel.nothing,
          onTap: () => onChanged(NotificationLevel.nothing),
          activeColor: haven.error,
        ),
      ],
    );
  }
}

/// A single level chip (selectable pill).
class _LevelChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  final Color? activeColor;

  const _LevelChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final color = activeColor ?? haven.accent;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: HavenSpacing.md,
            vertical: HavenSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : haven.surface,
            borderRadius: BorderRadius.circular(haven.radiusMd),
            border: Border.all(
              color: isSelected ? color : haven.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : haven.textSecondary,
              ),
              const SizedBox(width: HavenSpacing.xs),
              Text(
                label,
                style: HavenTypography.body.copyWith(
                  color: isSelected ? color : haven.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-channel override selector — Haven-styled PopupMenuButton.
class _ChannelOverrideDropdown extends StatelessWidget {
  final ChannelNotificationLevel value;
  final ValueChanged<ChannelNotificationLevel> onChanged;

  const _ChannelOverrideDropdown({
    required this.value,
    required this.onChanged,
  });

  static const _options = [
    (ChannelNotificationLevel.inherit, 'Default', LucideIcons.settings),
    (ChannelNotificationLevel.all, 'All', LucideIcons.bell),
    (ChannelNotificationLevel.mentions, 'Mentions', LucideIcons.atSign),
    (ChannelNotificationLevel.nothing, 'Nothing', LucideIcons.bellOff),
  ];

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final currentLabel =
        _options.firstWhere((o) => o.$1 == value).$2;

    return PopupMenuButton<ChannelNotificationLevel>(
      onSelected: onChanged,
      color: haven.elevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(haven.radiusMd),
        side: BorderSide(color: haven.border),
      ),
      offset: const Offset(0, 32),
      itemBuilder: (context) => _options.map((option) {
        final isActive = option.$1 == value;
        return PopupMenuItem(
          value: option.$1,
          child: Row(
            children: [
              Icon(
                option.$3,
                size: 14,
                color: isActive ? haven.accent : haven.textSecondary,
              ),
              const SizedBox(width: HavenSpacing.sm),
              Text(
                option.$2,
                style: HavenTypography.body.copyWith(
                  color: isActive ? haven.accent : haven.textPrimary,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HavenSpacing.sm + 2,
          vertical: HavenSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: haven.surface,
          borderRadius: BorderRadius.circular(haven.radiusSm),
          border: Border.all(color: haven.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: HavenTypography.body.copyWith(
                color: haven.textPrimary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: HavenSpacing.xs),
            Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: haven.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
