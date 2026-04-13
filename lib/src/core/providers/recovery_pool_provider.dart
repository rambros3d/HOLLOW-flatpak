import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State of an active recovery pool.
class RecoveryPoolState {
  final String serverId;
  final String inviteLink;
  final List<String> memberPeerIds;
  final int totalFiles;
  final int reconstructable;
  final int partial;
  final int noShards;
  final double overallProgress;
  final bool isInitiator;
  final bool isActive;
  final List<RecoveredFile> recoveredFiles;

  const RecoveryPoolState({
    required this.serverId,
    this.inviteLink = '',
    this.memberPeerIds = const [],
    this.totalFiles = 0,
    this.reconstructable = 0,
    this.partial = 0,
    this.noShards = 0,
    this.overallProgress = 0.0,
    this.isInitiator = false,
    this.isActive = false,
    this.recoveredFiles = const [],
  });

  RecoveryPoolState copyWith({
    String? inviteLink,
    List<String>? memberPeerIds,
    int? totalFiles,
    int? reconstructable,
    int? partial,
    int? noShards,
    double? overallProgress,
    bool? isInitiator,
    bool? isActive,
    List<RecoveredFile>? recoveredFiles,
  }) {
    return RecoveryPoolState(
      serverId: serverId,
      inviteLink: inviteLink ?? this.inviteLink,
      memberPeerIds: memberPeerIds ?? this.memberPeerIds,
      totalFiles: totalFiles ?? this.totalFiles,
      reconstructable: reconstructable ?? this.reconstructable,
      partial: partial ?? this.partial,
      noShards: noShards ?? this.noShards,
      overallProgress: overallProgress ?? this.overallProgress,
      isInitiator: isInitiator ?? this.isInitiator,
      isActive: isActive ?? this.isActive,
      recoveredFiles: recoveredFiles ?? this.recoveredFiles,
    );
  }
}

/// A file recovered during the pool session.
class RecoveredFile {
  final String contentId;
  final String diskPath;

  const RecoveredFile({required this.contentId, required this.diskPath});
}

/// Provider for the currently active recovery pool (null if none).
class RecoveryPoolNotifier extends Notifier<RecoveryPoolState?> {
  @override
  RecoveryPoolState? build() => null;

  void onPoolCreated(String serverId, String inviteLink) {
    state = RecoveryPoolState(
      serverId: serverId,
      inviteLink: inviteLink,
      isInitiator: true,
      isActive: true,
    );
  }

  void onPoolJoined(String serverId) {
    state = RecoveryPoolState(
      serverId: serverId,
      isInitiator: false,
      isActive: true,
    );
  }

  void onMemberJoined(String serverId, String peerId) {
    final s = state;
    if (s == null || s.serverId != serverId) return;
    state = s.copyWith(
      memberPeerIds: [...s.memberPeerIds, peerId],
    );
  }

  void onMemberLeft(String serverId, String peerId) {
    final s = state;
    if (s == null || s.serverId != serverId) return;
    state = s.copyWith(
      memberPeerIds: s.memberPeerIds.where((p) => p != peerId).toList(),
    );
  }

  void onStatus(
    String serverId, {
    required int totalFiles,
    required int reconstructable,
    required int partial,
    required int noShards,
    required double progressPct,
  }) {
    final s = state;
    if (s == null || s.serverId != serverId) return;
    state = s.copyWith(
      totalFiles: totalFiles,
      reconstructable: reconstructable,
      partial: partial,
      noShards: noShards,
      overallProgress: progressPct,
    );
  }

  void onFileRecovered(String serverId, String contentId, String diskPath) {
    final s = state;
    if (s == null || s.serverId != serverId) return;
    state = s.copyWith(
      recoveredFiles: [
        ...s.recoveredFiles,
        RecoveredFile(contentId: contentId, diskPath: diskPath),
      ],
    );
  }

  void onPoolStopped(String serverId) {
    final s = state;
    if (s == null || s.serverId != serverId) return;
    // Auto-clear for non-initiators (they were told the pool stopped).
    // For initiators, the stop command already clears via the dashboard.
    if (!s.isInitiator) {
      state = null;
    } else {
      state = s.copyWith(isActive: false);
    }
  }

  void clear() {
    state = null;
  }
}

final recoveryPoolProvider =
    NotifierProvider<RecoveryPoolNotifier, RecoveryPoolState?>(
        RecoveryPoolNotifier.new);
