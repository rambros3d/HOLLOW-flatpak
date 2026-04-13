import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/rust/api/crdt.dart' as crdt_api;

/// Status of a single vault file (erasure-coded) for the shard status indicator.
class VaultFileStatus {
  final String contentId;
  final String fileName;
  final int originalSize;
  final int k;
  final int m;
  final int localShardCount;
  final bool isReconstructable;
  final String channelId;
  final int createdAt;

  const VaultFileStatus({
    required this.contentId,
    required this.fileName,
    required this.originalSize,
    required this.k,
    required this.m,
    required this.localShardCount,
    required this.isReconstructable,
    required this.channelId,
    required this.createdAt,
  });
}

/// Vault file statuses for a given server. Shows which erasure-coded files
/// exist locally, how many shards are held, and whether each is reconstructable.
///
/// Keyed by server_id. Used by the Archive tab's Vault Files view.
final vaultFileStatusProvider = FutureProvider.autoDispose
    .family<List<VaultFileStatus>, String>((ref, serverId) async {
  final ffiList = await crdt_api.getVaultFileStatuses(serverId: serverId);
  return ffiList
      .map((f) => VaultFileStatus(
            contentId: f.contentId,
            fileName: f.fileName,
            originalSize: f.originalSize.toInt(),
            k: f.k,
            m: f.m,
            localShardCount: f.localShardCount,
            isReconstructable: f.isReconstructable,
            channelId: f.channelId,
            createdAt: f.createdAt,
          ))
      .toList();
});
