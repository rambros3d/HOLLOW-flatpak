import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hollow/src/core/providers/share_tab_provider.dart';
import 'package:hollow/src/rust/api/share.dart' as share_api;
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:hollow/src/ui/components/hollow_button.dart';
import 'package:hollow/src/ui/components/hollow_dialog.dart';
import 'package:hollow/src/ui/share/paste_link_dialog.dart';
import 'package:hollow/src/ui/share/share_card.dart';

class ShareDashboard extends ConsumerStatefulWidget {
  const ShareDashboard({super.key});

  @override
  ConsumerState<ShareDashboard> createState() => _ShareDashboardState();
}

class _ShareDashboardState extends ConsumerState<ShareDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(shareTabProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final shares = ref.watch(shareTabProvider);
    final downloading = downloadingShares(shares);
    final seeding = seedingShares(shares);

    return Container(
      color: hollow.background,
      child: Column(
        children: [
          _buildHeader(hollow),
          Expanded(
            child: shares.isEmpty
                ? _buildEmptyState(hollow)
                : _buildList(downloading, seeding, hollow),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(HollowTheme hollow) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HollowSpacing.lg,
        vertical: HollowSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: hollow.border)),
      ),
      child: Row(
        children: [
          Text('Share', style: HollowTypography.heading.copyWith(color: hollow.textPrimary)),
          const Spacer(),
          HollowButton.ghost(
            compact: true,
            icon: const Icon(LucideIcons.filePlus, size: 14),
            onPressed: _pickFile,
            child: const Text('Share a File'),
          ),
          const SizedBox(width: HollowSpacing.sm),
          HollowButton.filled(
            compact: true,
            icon: const Icon(LucideIcons.link, size: 14),
            onPressed: _showPasteDialog,
            child: const Text('Paste Link'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(HollowTheme hollow) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.share2, size: 48, color: hollow.textSecondary),
          const SizedBox(height: HollowSpacing.lg),
          Text(
            'No shares yet',
            style: HollowTypography.subheading.copyWith(color: hollow.textSecondary),
          ),
          const SizedBox(height: HollowSpacing.xs),
          Text(
            'Paste a link or share a file to get started',
            style: HollowTypography.bodySmall.copyWith(color: hollow.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    List<ShareItemState> downloading,
    List<ShareItemState> seeding,
    HollowTheme hollow,
  ) {
    return ListView(
      padding: const EdgeInsets.all(HollowSpacing.lg),
      children: [
        if (downloading.isNotEmpty) ...[
          _sectionHeader('Downloading (${downloading.length})', hollow),
          const SizedBox(height: HollowSpacing.sm),
          for (final item in downloading) ...[
            ShareCard(item: item),
            const SizedBox(height: HollowSpacing.sm),
          ],
          const SizedBox(height: HollowSpacing.lg),
        ],
        if (seeding.isNotEmpty) ...[
          _sectionHeader('Seeding (${seeding.length})', hollow),
          const SizedBox(height: HollowSpacing.sm),
          for (final item in seeding) ...[
            ShareCard(item: item),
            const SizedBox(height: HollowSpacing.sm),
          ],
        ],
      ],
    );
  }

  Widget _sectionHeader(String label, HollowTheme hollow) {
    return Padding(
      padding: const EdgeInsets.only(left: HollowSpacing.xs),
      child: Text(
        label,
        style: HollowTypography.label.copyWith(color: hollow.textSecondary),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      await share_api.shareCreateFromFile(sourcePath: result.files.single.path!);
    }
  }

  void _showPasteDialog() {
    showHollowDialog(
      context: context,
      builder: (ctx) => const PasteLinkDialog(),
    );
  }
}
