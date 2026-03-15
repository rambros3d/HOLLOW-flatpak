import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/file_attachment.dart';
import 'package:haven/src/core/providers/file_transfer_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Renders a file attachment inline in a message bubble.
///
/// - Images: inline preview (rounded, max 300x250).
/// - Other files: card with icon + name + size + progress.
class FileAttachmentWidget extends ConsumerWidget {
  final FileAttachment attachment;

  const FileAttachmentWidget({
    super.key,
    required this.attachment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haven = HavenTheme.of(context);

    // Watch live transfer progress.
    final transfer = ref.watch(
      fileTransferProvider.select((s) => s[attachment.fileId]),
    );

    final isComplete = transfer?.isComplete ?? attachment.isComplete;
    final diskPath = transfer?.diskPath ?? attachment.diskPath;
    final progress = transfer?.progress ?? attachment.progress;

    if (attachment.isImage) {
      return _buildImagePreview(haven, isComplete, diskPath, progress);
    }
    return _buildFileCard(haven, isComplete, progress);
  }

  Widget _buildImagePreview(
      HavenTheme haven, bool isComplete, String? diskPath, double progress) {
    // Calculate display size maintaining aspect ratio.
    const maxWidth = 300.0;
    const maxHeight = 250.0;

    double displayWidth = maxWidth;
    double displayHeight = maxHeight;
    if (attachment.width != null && attachment.height != null) {
      final aspect = attachment.width! / attachment.height!;
      if (aspect > maxWidth / maxHeight) {
        displayWidth = maxWidth;
        displayHeight = maxWidth / aspect;
      } else {
        displayHeight = maxHeight;
        displayWidth = maxHeight * aspect;
      }
    }

    if (isComplete && diskPath != null && File(diskPath).existsSync()) {
      // Show the actual image.
      return ClipRRect(
        borderRadius: BorderRadius.circular(haven.radiusSm),
        child: Image.file(
          File(diskPath),
          width: displayWidth,
          height: displayHeight,
          fit: BoxFit.cover,
          errorBuilder: (_, e, st) => _buildPlaceholder(
              haven, displayWidth, displayHeight, 1.0),
        ),
      );
    }

    // Show placeholder with progress.
    return _buildPlaceholder(haven, displayWidth, displayHeight, progress);
  }

  Widget _buildPlaceholder(
      HavenTheme haven, double width, double height, double progress) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: haven.surface,
        borderRadius: BorderRadius.circular(haven.radiusSm),
        border: Border.all(color: haven.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.image, size: 32, color: haven.textSecondary),
          const SizedBox(height: HavenSpacing.sm),
          if (progress > 0 && progress < 1) ...[
            SizedBox(
              width: 80,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: haven.elevated,
                valueColor: AlwaysStoppedAnimation(haven.accent),
              ),
            ),
            const SizedBox(height: HavenSpacing.xs),
            Text(
              '${(progress * 100).toInt()}%',
              style: HavenTypography.caption.copyWith(
                color: haven.textSecondary,
                fontSize: 10,
              ),
            ),
          ] else
            Text(
              attachment.formattedSize,
              style: HavenTypography.caption.copyWith(
                color: haven.textSecondary,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileCard(HavenTheme haven, bool isComplete, double progress) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(HavenSpacing.md),
      decoration: BoxDecoration(
        color: haven.surface,
        borderRadius: BorderRadius.circular(haven.radiusSm),
        border: Border.all(color: haven.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _fileIcon(),
            size: 28,
            color: haven.accent,
          ),
          const SizedBox(width: HavenSpacing.md),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.fileName,
                  style: HavenTypography.body.copyWith(
                    color: haven.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: HavenSpacing.xxs),
                if (!isComplete && progress > 0) ...[
                  SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: haven.elevated,
                      valueColor: AlwaysStoppedAnimation(haven.accent),
                    ),
                  ),
                  const SizedBox(height: HavenSpacing.xxs),
                ],
                Text(
                  attachment.formattedSize,
                  style: HavenTypography.caption.copyWith(
                    color: haven.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon() {
    final ext = attachment.fileExt.toLowerCase();
    return switch (ext) {
      'pdf' => LucideIcons.fileText,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => LucideIcons.fileArchive,
      'mp3' || 'ogg' || 'wav' || 'flac' => LucideIcons.fileAudio,
      'mp4' || 'webm' || 'avi' || 'mkv' => LucideIcons.fileVideo,
      'txt' || 'md' || 'log' => LucideIcons.fileText,
      _ => LucideIcons.file,
    };
  }
}
