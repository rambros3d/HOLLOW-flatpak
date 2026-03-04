import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/server_info.dart';
import 'package:haven/src/core/providers/server_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';
import 'package:haven/src/ui/settings/channels_tab.dart';
import 'package:haven/src/ui/settings/danger_zone_tab.dart';
import 'package:haven/src/ui/settings/members_tab.dart';
import 'package:haven/src/ui/settings/overview_tab.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Full server settings panel — replaces the chat pane.
class ServerSettingsPanel extends ConsumerStatefulWidget {
  final ServerInfo server;

  const ServerSettingsPanel({super.key, required this.server});

  @override
  ConsumerState<ServerSettingsPanel> createState() =>
      _ServerSettingsPanelState();
}

class _ServerSettingsPanelState extends ConsumerState<ServerSettingsPanel> {
  int _selectedTab = 0;

  static const _tabs = [
    (icon: LucideIcons.info, label: 'Overview'),
    (icon: LucideIcons.hash, label: 'Channels'),
    (icon: LucideIcons.users, label: 'Members'),
    (icon: LucideIcons.alertTriangle, label: 'Danger'),
  ];

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    // Re-read the server from provider so it updates when renamed
    final currentServer =
        ref.watch(serverListProvider)[widget.server.serverId] ?? widget.server;

    return Column(
      children: [
        // Header bar
        Container(
          height: 48,
          padding:
              const EdgeInsets.symmetric(horizontal: HavenSpacing.lg),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: haven.border)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.settings,
                  size: 18, color: haven.textSecondary),
              const SizedBox(width: HavenSpacing.sm),
              Expanded(
                child: Text(
                  'Server Settings — ${currentServer.name}',
                  style: HavenTypography.subheading.copyWith(
                    color: haven.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              HavenPressable(
                onTap: () {
                  ref.read(serverSettingsOpenProvider.notifier).state =
                      false;
                },
                borderRadius: BorderRadius.circular(haven.radiusSm),
                padding: const EdgeInsets.all(HavenSpacing.xs),
                child: Icon(LucideIcons.x,
                    size: 18, color: haven.textSecondary),
              ),
            ],
          ),
        ),

        // Tab bar
        Container(
          height: 40,
          padding:
              const EdgeInsets.symmetric(horizontal: HavenSpacing.md),
          decoration: BoxDecoration(
            color: haven.surface,
            border: Border(bottom: BorderSide(color: haven.border)),
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isSelected = i == _selectedTab;
              return _TabButton(
                icon: tab.icon,
                label: tab.label,
                isSelected: isSelected,
                isDanger: i == 3,
                onTap: () => setState(() => _selectedTab = i),
              );
            }),
          ),
        ),

        // Tab content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildTabContent(currentServer),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(ServerInfo server) {
    return switch (_selectedTab) {
      0 => OverviewTab(key: const ValueKey('overview'), server: server),
      1 => ChannelsTab(
          key: const ValueKey('channels'), serverId: server.serverId),
      2 => MembersTab(
          key: const ValueKey('members'), serverId: server.serverId),
      3 => DangerZoneTab(key: const ValueKey('danger'), server: server),
      _ => const SizedBox.shrink(),
    };
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDanger;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final activeColor = isDanger ? haven.error : haven.accent;
    final color = isSelected ? activeColor : haven.textSecondary;

    return HavenPressable(
      onTap: onTap,
      subtle: true,
      borderRadius: BorderRadius.circular(haven.radiusSm),
      padding: const EdgeInsets.symmetric(
        horizontal: HavenSpacing.md,
        vertical: HavenSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: HavenSpacing.xs),
          Text(
            label,
            style: HavenTypography.label.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
