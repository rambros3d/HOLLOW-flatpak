import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/server_info.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_button.dart';
import 'package:haven/src/ui/components/haven_text_field.dart';
import 'package:haven/src/ui/components/haven_toast.dart';
import 'package:haven/src/rust/api/crdt.dart' as crdt_api;
import 'package:lucide_icons/lucide_icons.dart';

/// Overview tab — rename server, set description, view server ID.
class OverviewTab extends ConsumerStatefulWidget {
  final ServerInfo server;

  const OverviewTab({super.key, required this.server});

  @override
  ConsumerState<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<OverviewTab> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.server.name);
    _descController = TextEditingController();
    _loadDescription();
  }

  Future<void> _loadDescription() async {
    try {
      final desc = await crdt_api.getServerSetting(
        serverId: widget.server.serverId,
        key: 'description',
      );
      if (mounted && desc.isNotEmpty) {
        _descController.text = desc;
      }
    } catch (_) {
      // No description set yet — leave field empty.
    }
  }

  @override
  void didUpdateWidget(OverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.server.name != widget.server.name) {
      _nameController.text = widget.server.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == widget.server.name) return;

    setState(() => _saving = true);
    try {
      await crdt_api.renameServer(
        serverId: widget.server.serverId,
        newName: newName,
      );
      if (mounted) {
        HavenToast.show(context, 'Server renamed', type: HavenToastType.success);
      }
    } catch (e) {
      if (mounted) {
        HavenToast.show(context, 'Failed to rename: $e', type: HavenToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDescription() async {
    final desc = _descController.text.trim();
    setState(() => _saving = true);
    try {
      await crdt_api.updateServerSetting(
        serverId: widget.server.serverId,
        key: 'description',
        value: desc,
      );
      if (mounted) {
        HavenToast.show(context, 'Description updated', type: HavenToastType.success);
      }
    } catch (e) {
      if (mounted) {
        HavenToast.show(context, 'Failed to update: $e', type: HavenToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(HavenSpacing.xl),
      children: [
        // Server Name
        Text(
          'Server Name',
          style: HavenTypography.label.copyWith(color: haven.textSecondary),
        ),
        const SizedBox(height: HavenSpacing.sm),
        Row(
          children: [
            Expanded(
              child: HavenTextField(
                controller: _nameController,
                hintText: 'Server name',
                onSubmitted: (_) => _saveName(),
              ),
            ),
            const SizedBox(width: HavenSpacing.sm),
            HavenButton.filled(
              onPressed: _saving ? null : _saveName,
              child: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: HavenSpacing.xl),

        // Description
        Text(
          'Description',
          style: HavenTypography.label.copyWith(color: haven.textSecondary),
        ),
        const SizedBox(height: HavenSpacing.sm),
        HavenTextField(
          controller: _descController,
          hintText: 'What is this server about?',
          maxLines: 3,
          onSubmitted: (_) => _saveDescription(),
        ),
        const SizedBox(height: HavenSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: HavenButton.filled(
            onPressed: _saving ? null : _saveDescription,
            compact: true,
            child: const Text('Save Description'),
          ),
        ),
        const SizedBox(height: HavenSpacing.xl),

        // Server ID
        Text(
          'Server ID',
          style: HavenTypography.label.copyWith(color: haven.textSecondary),
        ),
        const SizedBox(height: HavenSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HavenSpacing.md,
            vertical: HavenSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: haven.elevated,
            borderRadius: BorderRadius.circular(haven.radiusMd),
            border: Border.all(color: haven.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  widget.server.serverId,
                  style: HavenTypography.mono.copyWith(
                    color: haven.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: HavenSpacing.sm),
              HavenButton.ghost(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.server.serverId),
                  );
                  HavenToast.show(context, 'Copied to clipboard');
                },
                compact: true,
                icon: const Icon(LucideIcons.copy),
                child: const Text('Copy'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
