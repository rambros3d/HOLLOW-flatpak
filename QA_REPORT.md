# Hollow Performance/Quality Audit — QA Report

**Date:** May 4, 2026
**Scope:** Full codebase audit across 5 domains (MLS+Crypto, UI Performance, Storage+CRDTs, Networking+WebRTC, Offline-to-Online)
**Status:** Tier 1-4 complete. Remaining items tracked below.

---

## Completed Fixes

### Tier 1 — Quick wins (all in swarm.rs Disconnected handler)
- [x] **H1 (CRITICAL):** `synced_peers.clear()` on WS disconnect — fixed all sync after network flaps
- [x] **M12:** CRDT SyncReq always plaintext after reconnection
- [x] **M13:** `mls_bootstrap_requested` 60s timeout (was permanent)
- [x] **M14:** Clear `key_request_in_flight` + `pending_messages` on disconnect

### Tier 2 — Important bugs
- [x] **H12+H13:** Edit/delete sync gap — `updated_at` column, sync query `OR updated_at >= ?`, message_id existence check before INSERT, edit/delete applied in sync batch receivers with event emissions
- [x] **H3:** HollowShell no longer watches full `chatProvider` — new `lastDmMessageProvider`
- [x] **H4:** `profileProvider` hoisted out of `itemBuilder` in both chat panes
- [x] **Relay backpressure:** 64KB→2MB soft, 256KB→4MB hard, stderr drop logging

### Tier 3 — Performance at scale
- [x] **H6+H7:** CrdtStore actor (`node/crdt_store.rs`) — one DB connection, batch-drain, 34 sync_handler sites refactored
- [x] **H5:** crdt_ops table pruning every 30min via `prune_ops(1000)` (ROW_NUMBER window function)
- [x] **H8:** MLS persistence via CryptoStore actor (20 call sites, no more per-call DB opens)
- [x] **H2:** Member panel virtualization — `_MemberListEntry` data class, truly lazy `ListView.builder`

### Tier 4 — Architectural scaling
- [x] **H9:** Vault coordinator separated from MLS coordinator (`elect_vault_coordinator` = 2nd-lowest peer). Adaptive MLS batch timer (2s→5s→10s based on queue depth)
- [x] **H10:** Relay topic-based channel routing — `0x07`/`0x08` frames, subscribe command, `send_mls_broadcast_topic()` for channel messages. Deployed to VPS
- [x] **H11:** Voice WebRTC hard caps — `maxVoicePcs=15`, `maxScreenShareOutgoing=5`, `maxScreenShareIncoming=3`

### Additional fixes discovered during implementation
- [x] **SFrame key initialization:** MLS epoch key now emitted on voice channel join + cached by Dart provider. `rotateKey` used instead of `setSharedKey`. `setKeyIndexForPeer` called after every cryptor creation. Fixed pre-existing black screen in voice channel screen share.

### Tier 5 — UI performance & lazy loading
- [x] **M1:** `_ServerMemberTile` + `_MemberTile` now use `.select()` on profileProvider — only affected peer's tile rebuilds
- [x] **M2:** HollowAvatar uses `listEquals` content check instead of `identical()` identity check — prevents re-decode on reference change
- [x] **M3:** HollowPressable skips AnimationController allocation in `subtle` mode — saves widget tree depth for list items
- [x] **M4:** Member panel filtering/grouping extracted into `_serverMemberEntriesProvider` computed provider — memoized, no per-build O(n) work
- [x] **M5+M11:** Lazy profile blob loading — startup loads metadata only (`getAllProfilesLight()`), avatars/banners load on-demand via `avatarProvider`/`bannerProvider`. HollowAvatar is now a ConsumerWidget.
- [x] **L1:** Channel sidebar `ListView(children:)` → `ListView.builder` for lazy rendering

### Tier 6 — Voice ghost cleanup
- [x] **M25+M29+L13:** Voice channel participants cleaned on PeerLeft (per-server) and WsEvent::Disconnected (retain only self). Fixes ghost participants after abrupt disconnect.

### Tier 7 — Storage hygiene
- [x] **M9:** O(n) duplicate detection in `apply_op` → HashSet dedup (lazy-init from op_log, rebuilt after compaction)
- [x] **M10:** In-memory HashMap eviction every 5 min: peer_rate_tokens, vc_signal_rate_tokens, decrypt_fail_cooldown, channel_sync_sent, pending_shard_assembly
- [x] **L2:** `banned_members` pruned (unbanned entries removed during op_log compaction)
- [x] **L3:** `channel_sync_sent` pruned in same eviction cycle (entries >30s removed)
- [x] **L5:** SQLCipher incremental auto-vacuum enabled + `incremental_vacuum(100)` on startup

### Tier 8 — Relay hardening
- [x] **M21:** Text frame 1 MB size cap added (text frames are only join/leave/subscribe JSON)
- [x] **L12:** Text frames now share same 1 MB cap; binary rate limit unchanged (100 burst/20 per sec). `maxPayloadLength` raised to 64 MB (was 10 MB) — lowering silently kills connections due to ChannelSyncBatch size

---

## Remaining Items (not yet fixed)

### MEDIUM Severity
| # | Domain | Title |
|---|--------|-------|
| M6 | Storage | Server avatar in CRDT settings (133KB in every serialization). Hot/cold deferred — needs sync FFI read path fix |
| M7 | Storage | No message retention policy (~850 MB/server/year) |
| M8 | Storage | Full op_log (300-500 KB) sent as plaintext to new joiners |
| M15 | MLS | MLS recovery only targets Owner, not current coordinator |
| M16 | MLS | Targeted MLS messages encrypt+broadcast to ALL members (O(n)) |
| M17 | MLS | Commits only sent to online members — offline permanently desync |
| M18 | Network | Gossip PeerExchange broadcasts topology to all room members |
| M19 | Network | WS stream transfer reads entire file (34 MB) into memory |
| M20 | Network | Gossip neighbor selection can exceed MAX_TOTAL_WEBRTC=50 cap |
| M22 | Network | Relay silently drops messages under backpressure (now logged but not retried) |
| M23 | Network | Background bandwidth scales poorly at 1000+ members |
| M24 | Network | No file transfer resumption on WS disconnect |
| M26 | Offline | Pending friend requests not re-sent after app restart |
| M27 | Offline | Banned user retains server state until CRDT sync completes |
| M28 | Offline | @Mentions during offline sync don't trigger mention-specific unread |
| M29 | Network | Voice channel state not synced to newly-connecting peers (PeerJoined re-broadcast timing) |
| M30 | MLS | Channel visibility not cryptographically enforced (known, pre-v1.0) |

### LOW Severity
| # | Domain | Title |
|---|--------|-------|
| L4 | Storage | `LIKE '%query%'` search without FTS index |
| L6 | MLS | KeyPackage accepted without CRDT membership verification |
| L7 | MLS | Remove-then-add recovery creates 2 epoch advances per peer |
| L8 | MLS | Ed25519 uses `verify()` not `verify_strict()` |
| L9 | MLS | Olm session count unbounded, no stale pruning |
| L10 | Network | Data channel backpressure uses polling instead of callbacks |
| L11 | Network | Gossip overlay `known_peers` not cleared on disconnect |
| L14 | Offline | Server invites have no expiry mechanism |

### New items from HOLLOW_PLAN.md
- [ ] Screen share gossip relay for voice channels (current limit: 5 viewers)
- [ ] Topic-routed channel notifications (@mentions for unsubscribed channels)
