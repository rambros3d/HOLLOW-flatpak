import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/providers/identity_provider.dart';
import 'package:haven/src/core/providers/profile_provider.dart';
import 'package:haven/src/core/providers/settings_provider.dart';
import 'package:haven/src/core/providers/theme_provider.dart';
import 'package:haven/src/rust/api/network.dart' as network_api;
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_avatar.dart';
import 'package:haven/src/ui/components/haven_button.dart';
import 'package:haven/src/ui/components/haven_dialog.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';
import 'package:haven/src/ui/components/haven_text_field.dart';
import 'package:haven/src/ui/components/haven_toggle.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Tracks whether the settings dialog is currently open.
bool _settingsDialogOpen = false;

/// Shows the user settings dialog, or closes it if already open (toggle).
void showUserSettingsDialog(BuildContext context, WidgetRef ref) {
  // Toggle: if already open, close it.
  if (_settingsDialogOpen) {
    Navigator.of(context, rootNavigator: true).pop();
    return;
  }

  final localPeerId = ref.read(identityProvider).peerId;
  if (localPeerId == null) return;

  final profiles = ref.read(profileProvider);
  final currentProfile = profiles[localPeerId];

  final displayNameController = TextEditingController(
    text: currentProfile?.displayName ?? '',
  );
  final statusController = TextEditingController(
    text: currentProfile?.status ?? '',
  );
  final aboutMeController = TextEditingController(
    text: currentProfile?.aboutMe ?? '',
  );

  _settingsDialogOpen = true;

  showHavenDialog(
    context: context,
    builder: (dialogContext) {
      return _UserSettingsContent(
        localPeerId: localPeerId,
        displayNameController: displayNameController,
        statusController: statusController,
        aboutMeController: aboutMeController,
      );
    },
  ).then((_) {
    // Reset flag when dialog closes (Cancel, Save, barrier tap, or toggle).
    _settingsDialogOpen = false;
  });
}

/// Deterministic banner color from peer ID (shifted hue from avatar).
Color _bannerColorFromId(String id) {
  final hash = id.hashCode;
  final hue = ((hash % 360).abs() + 40) % 360; // Shift hue from avatar
  return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.45, 0.35).toColor();
}

/// Settings tab enum.
enum _SettingsTab { profile, system }

class _UserSettingsContent extends ConsumerStatefulWidget {
  final String localPeerId;
  final TextEditingController displayNameController;
  final TextEditingController statusController;
  final TextEditingController aboutMeController;

  const _UserSettingsContent({
    required this.localPeerId,
    required this.displayNameController,
    required this.statusController,
    required this.aboutMeController,
  });

  @override
  ConsumerState<_UserSettingsContent> createState() =>
      _UserSettingsContentState();
}

class _UserSettingsContentState extends ConsumerState<_UserSettingsContent> {
  // Track live fields for the preview card.
  String _liveDisplayName = '';
  String _liveStatus = '';

  // Active tab.
  _SettingsTab _activeTab = _SettingsTab.profile;

  // Pending toggle states (applied only on Save).
  late bool _pendingDarkMode;
  bool _pendingMinimizeToTray = true;
  bool _initialMinimizeToTray = true;
  bool _trayInitialized = false;
  bool _pendingProxy = false;
  bool _initialProxy = false;
  bool _proxyInitialized = false;

  @override
  void initState() {
    super.initState();
    _liveDisplayName = widget.displayNameController.text;
    _liveStatus = widget.statusController.text;
    widget.displayNameController.addListener(_onFieldChanged);
    widget.statusController.addListener(_onFieldChanged);

    _pendingDarkMode =
        ref.read(themeModeProvider) == ThemeMode.dark;

    // If already loaded, use the value directly.
    final trayAsync = ref.read(minimizeToTrayProvider);
    if (trayAsync.hasValue) {
      _pendingMinimizeToTray = trayAsync.value!;
      _initialMinimizeToTray = _pendingMinimizeToTray;
      _trayInitialized = true;
    }

    final proxyAsync = ref.read(proxyEnabledProvider);
    if (proxyAsync.hasValue) {
      _pendingProxy = proxyAsync.value!;
      _initialProxy = _pendingProxy;
      _proxyInitialized = true;
    }
  }

  void _onFieldChanged() {
    setState(() {
      _liveDisplayName = widget.displayNameController.text;
      _liveStatus = widget.statusController.text;
    });
  }

  @override
  void dispose() {
    widget.displayNameController.removeListener(_onFieldChanged);
    widget.statusController.removeListener(_onFieldChanged);
    super.dispose();
  }

  Future<void> _onSave() async {
    final displayName = widget.displayNameController.text.trim();
    final status = widget.statusController.text.trim();
    final aboutMe = widget.aboutMeController.text.trim();

    // Apply theme change.
    ref.read(themeModeProvider.notifier).state =
        _pendingDarkMode ? ThemeMode.dark : ThemeMode.light;

    // Apply minimize to tray change.
    if (_pendingMinimizeToTray != _initialMinimizeToTray) {
      await ref
          .read(minimizeToTrayProvider.notifier)
          .setEnabled(_pendingMinimizeToTray);
    }

    // Apply proxy change.
    final proxyChanged = _pendingProxy != _initialProxy;
    if (proxyChanged) {
      await ref
          .read(proxyEnabledProvider.notifier)
          .setEnabled(_pendingProxy);
    }

    // Save profile.
    await ref.read(profileProvider.notifier).updateMyProfile(
          displayName: displayName,
          status: status,
          aboutMe: aboutMe,
        );

    if (!mounted) return;
    Navigator.of(context).pop();

    // Show restart prompt if proxy setting changed.
    if (proxyChanged && mounted) {
      _showRestartDialog(context);
    }
  }

  void _showRestartDialog(BuildContext parentContext) {
    showHavenDialog(
      context: parentContext,
      builder: (ctx) => _RestartPrompt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update pending minimize-to-tray once the async value resolves.
    if (!_trayInitialized) {
      ref.listen(minimizeToTrayProvider, (prev, next) {
        if (next.hasValue && !_trayInitialized) {
          setState(() {
            _pendingMinimizeToTray = next.value!;
            _initialMinimizeToTray = _pendingMinimizeToTray;
            _trayInitialized = true;
          });
        }
      });
    }

    // Update pending proxy once the async value resolves.
    if (!_proxyInitialized) {
      ref.listen(proxyEnabledProvider, (prev, next) {
        if (next.hasValue && !_proxyInitialized) {
          setState(() {
            _pendingProxy = next.value!;
            _initialProxy = _pendingProxy;
            _proxyInitialized = true;
          });
        }
      });
    }

    final haven = HavenTheme.of(context);
    final radius = BorderRadius.circular(haven.radiusLg);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HavenSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 680,
            maxHeight: 540,
            minHeight: 540,
            minWidth: 400,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: haven.elevated.withValues(alpha: 0.92),
                borderRadius: radius,
                border: Border.all(
                  color: haven.accent.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HavenSpacing.xl,
                      HavenSpacing.xl,
                      HavenSpacing.xl,
                      0,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Settings',
                          style: HavenTypography.heading
                              .copyWith(color: haven.textPrimary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: HavenSpacing.lg),

                  // Tab rail + content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HavenSpacing.xl,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left: tab rail
                          SizedBox(
                            width: 140,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _TabItem(
                                  icon: LucideIcons.user,
                                  label: 'Profile',
                                  isActive:
                                      _activeTab == _SettingsTab.profile,
                                  onTap: () => setState(() =>
                                      _activeTab = _SettingsTab.profile),
                                ),
                                const SizedBox(height: HavenSpacing.xxs),
                                _TabItem(
                                  icon: LucideIcons.monitor,
                                  label: 'System',
                                  isActive:
                                      _activeTab == _SettingsTab.system,
                                  onTap: () => setState(() =>
                                      _activeTab = _SettingsTab.system),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: HavenSpacing.lg),

                          // Vertical divider
                          Container(
                            width: 1,
                            color: haven.border,
                          ),

                          const SizedBox(width: HavenSpacing.xl),

                          // Right: content area
                          Expanded(
                            child: _activeTab == _SettingsTab.profile
                                ? _buildProfileTab(haven)
                                : _buildSystemTab(haven),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(HavenSpacing.xl),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        HavenButton.ghost(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: HavenSpacing.sm),
                        HavenButton.filled(
                          onPressed: _onSave,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile tab ──────────────────────────────────────────────────

  Widget _buildProfileTab(HavenTheme haven) {
    final bannerColor = _bannerColorFromId(widget.localPeerId);
    final previewName = _liveDisplayName.trim().isNotEmpty
        ? _liveDisplayName.trim()
        : displayNameFor(ref.watch(profileProvider), widget.localPeerId);

    return SingleChildScrollView(
      key: const ValueKey('profile'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile preview card
          SizedBox(
            width: 200,
            child: Container(
              decoration: BoxDecoration(
                color: haven.surface,
                borderRadius: BorderRadius.circular(haven.radiusMd),
                border: Border.all(color: haven.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Banner
                  Container(
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          bannerColor,
                          bannerColor.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),

                  // Avatar overlapping banner
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HavenSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Avatar with border
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  haven.radiusMd + 2),
                              border: Border.all(
                                color: haven.surface,
                                width: 3,
                              ),
                            ),
                            child: HavenAvatar(
                              peerId: widget.localPeerId,
                              size: 56,
                            ),
                          ),

                          const SizedBox(height: HavenSpacing.xs),

                          // Display name
                          Text(
                            previewName,
                            style: HavenTypography.subheading.copyWith(
                              color: haven.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),

                          // Status
                          if (_liveStatus.trim().isNotEmpty) ...[
                            const SizedBox(height: HavenSpacing.xxs),
                            Text(
                              _liveStatus.trim(),
                              style: HavenTypography.caption.copyWith(
                                color: haven.textSecondary,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: HavenSpacing.sm),
                          Container(height: 1, color: haven.border),

                          // About Me preview
                          if (widget.aboutMeController.text
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: HavenSpacing.sm),
                            Text(
                              'ABOUT ME',
                              style: HavenTypography.caption.copyWith(
                                color: haven.textSecondary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: HavenSpacing.xxs),
                            Text(
                              widget.aboutMeController.text.trim(),
                              style: HavenTypography.caption.copyWith(
                                color: haven.textSecondary,
                                fontSize: 10,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],

                          // Peer ID footer
                          const SizedBox(height: HavenSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.copy,
                                size: 8,
                                color: haven.textSecondary
                                    .withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                widget.localPeerId.length > 16
                                    ? widget.localPeerId.substring(
                                        widget.localPeerId.length - 8)
                                    : widget.localPeerId,
                                style: HavenTypography.mono.copyWith(
                                  color: haven.textSecondary
                                      .withValues(alpha: 0.35),
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: HavenSpacing.lg),

          // Edit fields
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(label: 'DISPLAY NAME'),
                const SizedBox(height: HavenSpacing.xs),
                HavenTextField(
                  controller: widget.displayNameController,
                  hintText: 'Enter a display name',
                  autofocus: true,
                  maxLength: 32,
                ),

                const SizedBox(height: HavenSpacing.lg),

                _FieldLabel(label: 'STATUS'),
                const SizedBox(height: HavenSpacing.xs),
                HavenTextField(
                  controller: widget.statusController,
                  hintText: 'What are you up to?',
                  maxLength: 48,
                ),

                const SizedBox(height: HavenSpacing.lg),

                _FieldLabel(label: 'ABOUT ME'),
                const SizedBox(height: HavenSpacing.xs),
                HavenTextField(
                  controller: widget.aboutMeController,
                  hintText: 'Tell us about yourself',
                  maxLines: 3,
                  maxLength: 128,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── System tab ───────────────────────────────────────────────────

  Widget _buildSystemTab(HavenTheme haven) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return SingleChildScrollView(
      key: const ValueKey('system'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Appearance ──
          _SectionLabel(label: 'APPEARANCE'),
          const SizedBox(height: HavenSpacing.sm),

          // Theme toggle
          _ToggleRow(
            icon: _pendingDarkMode ? LucideIcons.moon : LucideIcons.sun,
            label: 'Dark Mode',
            value: _pendingDarkMode,
            onChanged: (value) =>
                setState(() => _pendingDarkMode = value),
          ),

          const SizedBox(height: HavenSpacing.xl),

          // ── System ──
          _SectionLabel(label: 'SYSTEM'),
          const SizedBox(height: HavenSpacing.sm),

          // Minimize to tray toggle
          if (isDesktop) ...[
            _ToggleRow(
              icon: LucideIcons.minimize2,
              label: 'Minimize to Tray',
              value: _pendingMinimizeToTray,
              onChanged: (value) =>
                  setState(() => _pendingMinimizeToTray = value),
            ),
            const SizedBox(height: HavenSpacing.md),
          ],

          // Proxy toggle
          _ToggleRow(
            icon: LucideIcons.shield,
            label: 'Use Proxy',
            subtitle: 'For restricted networks',
            value: _pendingProxy,
            onChanged: (value) =>
                setState(() => _pendingProxy = value),
          ),

          const SizedBox(height: HavenSpacing.xl),

          // ── Keyboard Shortcuts ──
          _SectionLabel(label: 'KEYBOARD SHORTCUTS'),
          const SizedBox(height: HavenSpacing.sm),

          _ShortcutRow(
            label: 'Open Settings',
            shortcut: 'Ctrl + ,',
          ),
          _ShortcutRow(
            label: 'Toggle Member Panel',
            shortcut: 'Ctrl + Shift + M',
          ),
          _ShortcutRow(
            label: 'Quick Search',
            shortcut: 'Ctrl + K',
          ),

          const SizedBox(height: HavenSpacing.lg),

          // Sub-section: Chat Input
          Padding(
            padding: const EdgeInsets.only(left: HavenSpacing.xs),
            child: Text(
              'CHAT INPUT',
              style: HavenTypography.caption.copyWith(
                color: haven.textSecondary.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(height: HavenSpacing.sm),

          _ShortcutRow(
            label: 'Send Message',
            shortcut: 'Enter',
          ),
          _ShortcutRow(
            label: 'New Line',
            shortcut: 'Shift + Enter',
          ),
          _ShortcutRow(
            label: 'Bold',
            shortcut: 'Ctrl + B',
          ),
          _ShortcutRow(
            label: 'Italic',
            shortcut: 'Ctrl + I',
          ),
          _ShortcutRow(
            label: 'Code',
            shortcut: 'Ctrl + E',
          ),
          _ShortcutRow(
            label: 'Strikethrough',
            shortcut: 'Ctrl + Shift + X',
          ),
          _ShortcutRow(
            label: 'Spoiler',
            shortcut: 'Ctrl + Shift + S',
          ),
        ],
      ),
    );
  }
}

/// Tab item in the settings rail.
class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return HavenPressable(
      onTap: onTap,
      subtle: true,
      borderRadius: BorderRadius.circular(haven.radiusSm),
      hoverColor: haven.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: HavenSpacing.md,
        vertical: HavenSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? haven.accent : haven.textSecondary,
          ),
          const SizedBox(width: HavenSpacing.sm),
          Text(
            label,
            style: HavenTypography.body.copyWith(
              color: isActive ? haven.textPrimary : haven.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable toggle row for System tab.
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: haven.textSecondary),
        const SizedBox(width: HavenSpacing.sm),
        Expanded(
          child: subtitle != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: HavenTypography.body
                          .copyWith(color: haven.textPrimary),
                    ),
                    Text(
                      subtitle!,
                      style: HavenTypography.caption.copyWith(
                        color: haven.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                )
              : Text(
                  label,
                  style: HavenTypography.body
                      .copyWith(color: haven.textPrimary),
                ),
        ),
        HavenToggle(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// Single shortcut row: label on left, key badge on right.
class _ShortcutRow extends StatelessWidget {
  final String label;
  final String shortcut;

  const _ShortcutRow({
    required this.label,
    required this.shortcut,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HavenSpacing.xxs + 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: HavenTypography.body.copyWith(
                color: haven.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          _KeyBadge(shortcut: shortcut),
        ],
      ),
    );
  }
}

/// Styled keyboard shortcut badge (e.g. "Ctrl + B").
class _KeyBadge extends StatelessWidget {
  final String shortcut;

  const _KeyBadge({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    // Split on " + " to render each key individually.
    final keys = shortcut.split(' + ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          if (i > 0)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: HavenSpacing.xxs),
              child: Text(
                '+',
                style: HavenTypography.caption.copyWith(
                  color: haven.textSecondary.withValues(alpha: 0.4),
                  fontSize: 9,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: HavenSpacing.xs + 2,
              vertical: HavenSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: haven.surface,
              borderRadius: BorderRadius.circular(haven.radiusSm - 2),
              border: Border.all(
                color: haven.border,
              ),
            ),
            child: Text(
              keys[i],
              style: HavenTypography.mono.copyWith(
                color: haven.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Section label for the system tab.
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: HavenSpacing.xs),
      child: Text(
        label,
        style: HavenTypography.caption.copyWith(
          color: haven.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// Restart prompt dialog shown after proxy setting changes.
class _RestartPrompt extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haven = HavenTheme.of(context);
    final radius = BorderRadius.circular(haven.radiusMd);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: haven.elevated.withValues(alpha: 0.95),
              borderRadius: radius,
              border: Border.all(
                color: haven.accent.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                ),
              ],
            ),
            padding: const EdgeInsets.all(HavenSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.rotateCcw,
                  size: 32,
                  color: haven.accent,
                ),
                const SizedBox(height: HavenSpacing.md),
                Text(
                  'Restart Required',
                  style: HavenTypography.subheading.copyWith(
                    color: haven.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: HavenSpacing.sm),
                Text(
                  'The proxy setting requires a restart to take effect.',
                  style: HavenTypography.body.copyWith(
                    color: haven.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: HavenSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: HavenButton.ghost(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Restart Later'),
                      ),
                    ),
                    const SizedBox(width: HavenSpacing.sm),
                    Expanded(
                      child: HavenButton.filled(
                        onPressed: () async {
                          // Graceful shutdown: notify peers, stop node.
                          try {
                            await network_api.notifyShutdown();
                            await Future.delayed(
                                const Duration(milliseconds: 200));
                          } catch (_) {}

                          // Spawn new instance before exiting.
                          final exe = Platform.resolvedExecutable;
                          await Process.start(exe, [],
                              mode: ProcessStartMode.detached);

                          // Small delay to let the OS fully detach the child.
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                          exit(0);
                        },
                        child: const Text('Restart Now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    return Text(
      label,
      style: HavenTypography.caption.copyWith(
        color: haven.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        fontSize: 10,
      ),
    );
  }
}
