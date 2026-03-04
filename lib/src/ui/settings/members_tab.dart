import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/providers/server_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_avatar.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Members tab — view members with their roles.
class MembersTab extends ConsumerWidget {
  final String serverId;

  const MembersTab({super.key, required this.serverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haven = HavenTheme.of(context);
    final membersAsync = ref.watch(serverMembersProvider(serverId));

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return Center(
            child: Text(
              'No members',
              style:
                  HavenTypography.body.copyWith(color: haven.textSecondary),
            ),
          );
        }

        // Sort: owner first, then admin, then member
        final sorted = [...members]..sort((a, b) {
            const order = {'owner': 0, 'admin': 1, 'member': 2};
            return (order[a.role] ?? 3).compareTo(order[b.role] ?? 3);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(HavenSpacing.lg),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final member = sorted[index];
            return _MemberRow(
              displayName: member.displayName,
              peerId: member.peerId,
              role: member.role,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Failed to load members: $e',
          style: HavenTypography.body.copyWith(color: haven.error),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String displayName;
  final String peerId;
  final String role;

  const _MemberRow({
    required this.displayName,
    required this.peerId,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    Color roleColor;
    IconData roleIcon;
    switch (role) {
      case 'owner':
        roleColor = haven.warning;
        roleIcon = LucideIcons.crown;
      case 'admin':
        roleColor = haven.accent;
        roleIcon = LucideIcons.shield;
      default:
        roleColor = haven.textSecondary;
        roleIcon = LucideIcons.user;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: HavenSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HavenSpacing.md,
          vertical: HavenSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: haven.elevated,
          borderRadius: BorderRadius.circular(haven.radiusMd),
        ),
        child: Row(
          children: [
            HavenAvatar(peerId: peerId, size: 32),
            const SizedBox(width: HavenSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: HavenTypography.body
                        .copyWith(color: haven.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    peerId,
                    style: HavenTypography.caption,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: HavenSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: HavenSpacing.sm,
                vertical: HavenSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(HavenRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(roleIcon, size: 12, color: roleColor),
                  const SizedBox(width: HavenSpacing.xs),
                  Text(
                    role[0].toUpperCase() + role.substring(1),
                    style: HavenTypography.caption.copyWith(
                      color: roleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
