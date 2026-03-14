import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/channel_info.dart';
import 'package:haven/src/core/providers/channel_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_button.dart';
import 'package:haven/src/ui/components/haven_dialog.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';
import 'package:haven/src/ui/components/haven_text_field.dart';
import 'package:haven/src/ui/components/haven_toast.dart';
import 'package:haven/src/rust/api/crdt.dart' as crdt_api;
import 'package:lucide_icons/lucide_icons.dart';

/// A layout item — either a category header or a channel.
sealed class LayoutItem {
  const LayoutItem();
}

class CategoryItem extends LayoutItem {
  final String name;
  const CategoryItem(this.name);
}

class ChannelItem extends LayoutItem {
  final String channelId;
  const ChannelItem(this.channelId);
}

class SeparatorItem extends LayoutItem {
  const SeparatorItem();
}

/// Channels tab — drag-and-drop layout editor with categories.
class ChannelsTab extends ConsumerStatefulWidget {
  final String serverId;

  const ChannelsTab({super.key, required this.serverId});

  @override
  ConsumerState<ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends ConsumerState<ChannelsTab> {
  List<LayoutItem> _layout = [];
  List<LayoutItem> _savedLayout = []; // What's in DB — for discard comparison.
  bool _loaded = false;

  /// Compare current layout against saved to determine if changes exist.
  bool get _dirty {
    if (_layout.length != _savedLayout.length) return true;
    for (int i = 0; i < _layout.length; i++) {
      final a = _layout[i];
      final b = _savedLayout[i];
      if (a.runtimeType != b.runtimeType) return true;
      if (a is CategoryItem && b is CategoryItem && a.name != b.name) return true;
      if (a is ChannelItem && b is ChannelItem && a.channelId != b.channelId) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    try {
      final json = await crdt_api.getChannelLayout(serverId: widget.serverId);
      final List<dynamic> items = jsonDecode(json);
      final layout = <LayoutItem>[];
      for (final item in items) {
        if (item['type'] == 'category') {
          layout.add(CategoryItem(item['name'] as String));
        } else if (item['type'] == 'channel') {
          layout.add(ChannelItem(item['channel_id'] as String));
        } else if (item['type'] == 'separator') {
          layout.add(const SeparatorItem());
        }
      }
      if (mounted) {
        // Compute effective layout (includes newly created channels)
        // and use it as both current and saved baseline.
        final channels = ref.read(channelListProvider);
        final effective = _effectiveLayoutFrom(layout, channels);
        setState(() { _layout = effective; _savedLayout = List.from(effective); _loaded = true; });
      }
    } catch (_) {
      if (mounted) {
        final channels = ref.read(channelListProvider);
        final effective = _effectiveLayoutFrom([], channels);
        setState(() { _layout = effective; _savedLayout = List.from(effective); _loaded = true; });
      }
    }
  }

  /// Like _effectiveLayout but takes an explicit base layout.
  List<LayoutItem> _effectiveLayoutFrom(List<LayoutItem> base, Map<String, ChannelInfo> channels) {
    final layout = List<LayoutItem>.from(base);
    final layoutChannelIds = layout
        .whereType<ChannelItem>()
        .map((c) => c.channelId)
        .toSet();
    final missing = channels.keys
        .where((id) => !layoutChannelIds.contains(id))
        .toList()
      ..sort((a, b) =>
          (channels[a]?.name ?? '').compareTo(channels[b]?.name ?? ''));
    for (final id in missing) {
      layout.add(ChannelItem(id));
    }
    layout.removeWhere((item) =>
        item is ChannelItem && !channels.containsKey(item.channelId));
    return layout;
  }

  /// Build the effective layout: current layout + any channels not yet in it.
  List<LayoutItem> _effectiveLayout(Map<String, ChannelInfo> channels) {
    return _effectiveLayoutFrom(_layout, channels);
  }

  void _save() {
    final jsonList = _layout.map((item) {
      if (item is CategoryItem) {
        return {'type': 'category', 'name': item.name};
      } else if (item is ChannelItem) {
        return {'type': 'channel', 'channel_id': item.channelId};
      } else if (item is SeparatorItem) {
        return {'type': 'separator'};
      }
    }).toList();

    crdt_api.updateChannelLayout(
      serverId: widget.serverId,
      layoutJson: jsonEncode(jsonList),
    );

    setState(() {
           _savedLayout = List.from(_layout);
    });
    HavenToast.show(
      context,
      'Channel layout saved',
      type: HavenToastType.success,
    );
  }

  void _addChannel() {
    final controller = TextEditingController();
    showHavenDialog(
      context: context,
      builder: (ctx) => HavenDialog(
        title: 'New Channel',
        content: HavenTextField(
          controller: controller,
          hintText: 'Channel name',
          autofocus: true,
          maxLength: 32,
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              crdt_api.createChannel(
                serverId: widget.serverId,
                name: name,
                category: null,
              );
              // Channel will appear in _layout via _effectiveLayout
              // on next build. Mark dirty so Save is required.
              setState(() {});
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          HavenButton.ghost(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          HavenButton.filled(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                crdt_api.createChannel(
                  serverId: widget.serverId,
                  name: name,
                  category: null,
                );
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _addCategory() {
    final controller = TextEditingController();
    showHavenDialog(
      context: context,
      builder: (ctx) => HavenDialog(
        title: 'New Category',
        content: HavenTextField(
          controller: controller,
          hintText: 'Category name',
          autofocus: true,
          maxLength: 32,
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              setState(() {
                _layout.add(CategoryItem(name));
                             });
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          HavenButton.ghost(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          HavenButton.filled(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _layout.add(CategoryItem(name));
                                 });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _renameCategory(int index, String currentName) {
    final controller = TextEditingController(text: currentName);
    showHavenDialog(
      context: context,
      builder: (ctx) => HavenDialog(
        title: 'Rename Category',
        content: HavenTextField(
          controller: controller,
          hintText: 'Category name',
          autofocus: true,
          maxLength: 32,
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              setState(() {
                _layout[index] = CategoryItem(name);
                             });
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          HavenButton.ghost(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          HavenButton.filled(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _layout[index] = CategoryItem(name);
                                 });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _removeCategory(int index) {
    setState(() {
      _layout.removeAt(index);
         });
  }

  void _renameChannel(String channelId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showHavenDialog(
      context: context,
      builder: (ctx) => HavenDialog(
        title: 'Rename Channel',
        content: HavenTextField(
          controller: controller,
          hintText: 'Channel name',
          autofocus: true,
          onSubmitted: (_) {
            final newName = controller.text.trim();
            if (newName.isNotEmpty && newName != currentName) {
              crdt_api.renameChannel(
                serverId: widget.serverId,
                channelId: channelId,
                newName: newName,
              );
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          HavenButton.ghost(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          HavenButton.filled(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                crdt_api.renameChannel(
                  serverId: widget.serverId,
                  channelId: channelId,
                  newName: newName,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _deleteChannel(String channelId, String name) {
    showHavenDialog(
      context: context,
      builder: (ctx) => HavenDialog(
        title: 'Delete Channel',
        content: Text(
          'Are you sure you want to delete #$name? This cannot be undone.',
          style: HavenTypography.body,
        ),
        actions: [
          HavenButton.ghost(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          HavenButton.danger(
            onPressed: () {
              crdt_api.removeChannel(
                serverId: widget.serverId,
                channelId: channelId,
              );
              setState(() {
                _layout.removeWhere(
                    (i) => i is ChannelItem && i.channelId == channelId);
              });
              Navigator.pop(ctx);
              HavenToast.show(
                context,
                'Channel #$name deleted',
                type: HavenToastType.info,
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final channels = ref.watch(channelListProvider);

    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final effective = _effectiveLayout(channels);
    // Sync local state if effective differs (new channels added/removed externally).
    // Auto-save so sidebar updates immediately without requiring manual Save.
    if (effective.length != _layout.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _layout = effective;
            _savedLayout = List.from(effective);
          });
          // Auto-save the layout so sidebar reflects the change.
          final jsonList = effective.map((item) {
            if (item is CategoryItem) {
              return {'type': 'category', 'name': item.name};
            } else if (item is ChannelItem) {
              return {'type': 'channel', 'channel_id': item.channelId};
            } else if (item is SeparatorItem) {
              return {'type': 'separator'};
            }
          }).toList();
          crdt_api.updateChannelLayout(
            serverId: widget.serverId,
            layoutJson: jsonEncode(jsonList),
          );
        }
      });
    }

    return Column(
      children: [
        // Header row with action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HavenSpacing.lg, HavenSpacing.md, HavenSpacing.lg, HavenSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Drag to reorder channels and categories',
                  style: HavenTypography.caption.copyWith(
                    color: haven.textSecondary,
                  ),
                ),
              ),
              HavenButton.ghost(
                onPressed: () {
                  setState(() {
                    _layout.add(const SeparatorItem());
                                     });
                },
                compact: true,
                icon: Icon(LucideIcons.minus, size: 14),
                child: const Text('Break'),
              ),
              const SizedBox(width: HavenSpacing.sm),
              HavenButton.ghost(
                onPressed: _addCategory,
                compact: true,
                icon: Icon(LucideIcons.folderPlus, size: 14),
                child: const Text('Category'),
              ),
              const SizedBox(width: HavenSpacing.sm),
              HavenButton.ghost(
                onPressed: _addChannel,
                compact: true,
                icon: Icon(LucideIcons.plus, size: 14),
                child: const Text('Channel'),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: haven.border),

        // Drag-and-drop list
        Expanded(
          child: _layout.isEmpty
              ? Center(
                  child: Text(
                    'No channels yet. Create one to get started.',
                    style: HavenTypography.body
                        .copyWith(color: haven.textSecondary),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(HavenSpacing.md),
                  itemCount: _layout.length,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (ctx, child) => Material(
                        color: Colors.transparent,
                        elevation: 4,
                        shadowColor: Colors.black26,
                        borderRadius:
                            BorderRadius.circular(haven.radiusMd),
                        child: child,
                      ),
                      child: child,
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _layout.removeAt(oldIndex);
                      _layout.insert(newIndex, item);
                                         });
                  },
                  itemBuilder: (context, index) {
                    final item = _layout[index];
                    // Check if this channel is under a category.
                    // A separator breaks the category scope.
                    bool isUnderCategory = false;
                    if (item is ChannelItem) {
                      for (int i = index - 1; i >= 0; i--) {
                        if (_layout[i] is SeparatorItem) break;
                        if (_layout[i] is CategoryItem) {
                          isUnderCategory = true;
                          break;
                        }
                      }
                    }
                    // Is this the last channel before next category, separator, or end?
                    bool isLastInCategory = false;
                    if (isUnderCategory) {
                      isLastInCategory = index == _layout.length - 1 ||
                          _layout[index + 1] is CategoryItem ||
                          _layout[index + 1] is SeparatorItem;
                    }

                    if (item is SeparatorItem) {
                      return _SeparatorRow(
                        key: ValueKey('sep-$index'),
                        index: index,
                        onDelete: () {
                          setState(() {
                            _layout.removeAt(index);
                                                     });
                        },
                      );
                    } else if (item is CategoryItem) {
                      return _CategoryRow(
                        key: ValueKey('cat-$index-${item.name}'),
                        index: index,
                        name: item.name,
                        onRename: () =>
                            _renameCategory(index, item.name),
                        onDelete: () => _removeCategory(index),
                      );
                    } else if (item is ChannelItem) {
                      final info = channels[item.channelId];
                      final name = info?.name ?? item.channelId;
                      return _ChannelRow(
                        key: ValueKey('ch-${item.channelId}'),
                        index: index,
                        name: name,
                        indented: isUnderCategory,
                        isLast: isLastInCategory,
                        onRename: () =>
                            _renameChannel(item.channelId, name),
                        onDelete: () =>
                            _deleteChannel(item.channelId, name),
                      );
                    }
                    return const SizedBox.shrink(key: ValueKey('unknown'));
                  },
                ),
        ),

        // Save / Cancel buttons
        if (_dirty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HavenSpacing.lg, HavenSpacing.sm, HavenSpacing.lg, HavenSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: HavenButton.ghost(
                    onPressed: () {
                      // Reload from DB to get current state
                      // (channels created/deleted are CRDT ops, can't undo).
                      setState(() {
                        _loaded = false;
                      });
                      _loadLayout();
                    },
                    expand: true,
                    icon: Icon(LucideIcons.x, size: 16),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: HavenSpacing.sm),
                Expanded(
                  child: HavenButton.filled(
                    onPressed: _save,
                    expand: true,
                    icon: Icon(LucideIcons.save, size: 16),
                    child: const Text('Save Layout'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final int index;
  final String name;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CategoryRow({
    super.key,
    required this.index,
    required this.name,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: HavenSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HavenSpacing.sm,
          vertical: HavenSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: haven.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(haven.radiusMd),
          border: Border.all(
            color: haven.accent.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Icon(LucideIcons.gripVertical,
                  size: 16, color: haven.textSecondary),
            ),
            const SizedBox(width: HavenSpacing.sm),
            Icon(LucideIcons.folder, size: 16, color: haven.accent),
            const SizedBox(width: HavenSpacing.sm),
            Expanded(
              child: Text(
                name.toUpperCase(),
                style: HavenTypography.caption.copyWith(
                  color: haven.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            HavenPressable(
              onTap: onRename,
              borderRadius: BorderRadius.circular(haven.radiusSm),
              padding: const EdgeInsets.all(HavenSpacing.xs),
              child: Icon(LucideIcons.pencil,
                  size: 14, color: haven.textSecondary),
            ),
            const SizedBox(width: HavenSpacing.xs),
            HavenPressable(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(haven.radiusSm),
              padding: const EdgeInsets.all(HavenSpacing.xs),
              child:
                  Icon(LucideIcons.trash2, size: 14, color: haven.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final int index;
  final String name;
  final bool indented;
  final bool isLast;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ChannelRow({
    super.key,
    required this.index,
    required this.name,
    this.indented = false,
    this.isLast = false,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: HavenSpacing.xs),
      child: Row(
        children: [
          if (indented) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 16,
              height: 32,
              child: CustomPaint(
                painter: _TreeConnectorPainter(
                  color: haven.border,
                  isLast: isLast,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: HavenSpacing.sm,
                vertical: HavenSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: haven.elevated,
                borderRadius: BorderRadius.circular(haven.radiusMd),
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(LucideIcons.gripVertical,
                        size: 16, color: haven.textSecondary),
                  ),
                  const SizedBox(width: HavenSpacing.sm),
                  Icon(LucideIcons.hash, size: 16, color: haven.textSecondary),
                  const SizedBox(width: HavenSpacing.sm),
                  Expanded(
                    child: Text(
                      name,
                      style: HavenTypography.body
                          .copyWith(color: haven.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  HavenPressable(
                    onTap: onRename,
                    borderRadius: BorderRadius.circular(haven.radiusSm),
                    padding: const EdgeInsets.all(HavenSpacing.xs),
                    child: Icon(LucideIcons.pencil,
                        size: 14, color: haven.textSecondary),
                  ),
                  const SizedBox(width: HavenSpacing.xs),
                  HavenPressable(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(haven.radiusSm),
                    padding: const EdgeInsets.all(HavenSpacing.xs),
                    child:
                        Icon(LucideIcons.trash2, size: 14, color: haven.error),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A separator row — thin divider that breaks the category scope.
class _SeparatorRow extends StatelessWidget {
  final int index;
  final VoidCallback onDelete;

  const _SeparatorRow({
    super.key,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HavenSpacing.xs),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(LucideIcons.gripVertical,
                size: 16, color: haven.textSecondary),
          ),
          const SizedBox(width: HavenSpacing.sm),
          Expanded(
            child: Container(
              height: 1.5,
              color: haven.border,
            ),
          ),
          const SizedBox(width: HavenSpacing.sm),
          HavenPressable(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(haven.radiusSm),
            padding: const EdgeInsets.all(HavenSpacing.xs),
            child: Icon(LucideIcons.x, size: 12, color: haven.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Paints the tree connector line (├── or └──).
class _TreeConnectorPainter extends CustomPainter {
  final Color color;
  final bool isLast;

  _TreeConnectorPainter({required this.color, required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.lerp(color, Colors.white, 0.3)!
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Vertical line from top to middle (or full height if not last).
    final midY = size.height / 2;
    canvas.drawLine(
      Offset(0, 0),
      Offset(0, isLast ? midY : size.height),
      paint,
    );

    // Horizontal line from left to right at middle.
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TreeConnectorPainter oldDelegate) =>
      color != oldDelegate.color || isLast != oldDelegate.isLast;
}
