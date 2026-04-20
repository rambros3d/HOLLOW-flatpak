# Hollow Protocol Whitepaper

**Version 0.1 — Alpha**
**Author: AnonListen**

---

## 1. Introduction

Hollow is a fully distributed, end-to-end encrypted communication platform. There are no central servers that store messages, files, or metadata. Members of a server collectively host it — the relay is a dumb signaling pipe that routes encrypted blobs between peers without any ability to read, modify, or store them.

### 1.1 Design Goals

- **Zero-knowledge relay.** The relay sees room membership and peer IDs. It cannot read message contents, encryption keys, file data, or any application-layer semantics.
- **No accounts.** Identity is a cryptographic keypair. There is no email, phone number, or username registration.
- **Forward secrecy.** DM sessions use the Double Ratchet algorithm. Compromising a long-term key does not reveal past messages.
- **Decentralized state.** Server metadata (channels, members, roles) is synchronized via CRDTs with no authoritative source. Any online member can serve as a sync peer.
- **Verifiable authorship.** Every message carries an Ed25519 signature over a canonical payload. Recipients verify that the claimed sender actually authored the message.

### 1.2 Threat Model

Hollow assumes the relay operator is honest-but-curious: the relay faithfully forwards messages but may attempt to read or log traffic. An attacker who fully compromises the relay learns only which peer IDs are connected and which rooms they occupy. Message contents, encryption keys, and file data remain opaque.

Hollow does **not** currently defend against:
- Traffic analysis (message timing and size patterns)
- Compromise of a user's local device (key extraction)
- A relay that selectively drops or delays messages (availability attacks)

---

## 2. Identity

### 2.1 Key Generation

Each Hollow identity is an **Ed25519 keypair** (256-bit secret, 256-bit public) generated via `ed25519-dalek` v2.

The keypair is derived from a **BIP-39 mnemonic** (24 words, 256 bits of entropy):

1. Generate 32 bytes of cryptographically secure randomness (`getrandom`).
2. Encode as a BIP-39 mnemonic (24 words from the English wordlist).
3. Derive a 64-byte seed via `mnemonic.to_seed("")` (PBKDF2-HMAC-SHA512, 2048 rounds, empty passphrase).
4. Use the first 32 bytes as the Ed25519 secret key.
5. Derive the public key from the secret key.

The mnemonic is shown to the user once at account creation and never transmitted. It serves as the sole recovery mechanism.

### 2.2 Peer ID

The peer ID is a **base58-encoded identity multihash** of the public key, matching the libp2p PeerId format:

```
PeerId = Base58( [0x00, length, public_key_protobuf] )
```

Public key protobuf encoding: `[0x08, 0x01, 0x12, 0x20, <32-byte Ed25519 public key>]` (36 bytes).

Peer IDs are deterministic: the same mnemonic always produces the same peer ID. This format begins with `12D3KooW...` and is used as the universal identifier throughout the protocol.

### 2.3 Local Storage Encryption

All local data is stored in **SQLCipher** (encrypted SQLite). The database encryption key is derived from the first 32 bytes of the keypair's protobuf encoding, hex-encoded as a passphrase. The database is inaccessible without the keypair.

---

## 3. Direct Message Encryption (Olm / Double Ratchet)

DMs between two peers use the **Olm protocol** (Double Ratchet with Curve25519 key exchange) via the `vodozemac` v0.9 library — the same cryptographic implementation used by Matrix/Element.

### 3.1 Session Establishment

1. **Prekey bundle exchange.** When peer A wants to message peer B, A requests B's prekey bundle:
   - B's Curve25519 identity key (32 bytes, base64)
   - B's one-time key (Curve25519, 32 bytes, base64)
   
2. **Outbound session.** A creates an outbound Olm session using B's identity key and one-time key. The first message is a **PreKey message** (type 0) containing the key material needed for B to establish the inbound session.

3. **Inbound session.** Upon receiving the PreKey message, B creates an inbound session. All subsequent messages from B are **Normal messages** (type 1).

4. **Ratcheting.** After the initial exchange, both sides enter the Double Ratchet: each message advances the ratchet, deriving a new symmetric key. This provides forward secrecy — compromising the current key does not reveal past messages.

### 3.2 State Persistence

Olm session state is serialized ("pickled") to JSON and stored in SQLCipher. Account state (long-term Curve25519 identity keys) is persisted separately. Sessions survive application restarts.

### 3.3 Key Exchange via Relay

Prekey bundles travel as signed JSON messages through the relay. The relay sees base64-encoded key material but cannot derive session keys without the private Curve25519 keys, which never leave the device.

---

## 4. Server Encryption (MLS)

Servers (group chats) use **Messaging Layer Security (MLS)**, RFC 9420, via `OpenMLS` v0.8.

### 4.1 Ciphersuite

```
MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519
```

- **Key encapsulation:** X25519 (Curve25519 DH)
- **AEAD:** AES-128-GCM
- **Hash:** SHA-256
- **Signature:** Ed25519

### 4.2 Group Lifecycle

- **One MLS group per server.** All channels within a server share a single MLS group. Channel routing is handled at the application layer.
- **Group ID:** The server ID string, encoded as bytes.
- **Credentials:** `BasicCredential` containing the peer ID as the identity.

**Creating a server:**
1. Creator generates an MLS `KeyPackage` and creates a new `MlsGroup`.
2. The group's ratchet tree is initialized with the creator as the sole member.

**Adding members:**
1. Existing member generates a `Commit` + `Welcome` message via `group.add_members()`.
2. The Welcome message is sent to the joining peer, containing the group secrets.
3. The joiner initializes their group state from the Welcome.

**Removing members:**
1. Any authorized member generates a `Commit` via `group.remove_members()`.
2. The commit is broadcast to all remaining members.
3. The epoch advances, rotating all group keys.

### 4.3 Epoch and Key Rotation

Every membership change (add or remove) advances the MLS **epoch** — a monotonically increasing counter. Each epoch derives fresh encryption keys. An attacker who compromises keys from one epoch cannot decrypt messages from other epochs.

### 4.4 Coordinator Model

MLS operations (add/remove) require a single member to generate the Commit. Hollow uses **deterministic coordinator election**: the online member with the lexicographically lowest peer ID in the MLS group acts as coordinator. This avoids conflicts without requiring consensus.

### 4.5 Message Encryption

```
Plaintext → MLS group.create_message() → MlsMessage (ciphertext)
MlsMessage → MLS group.process_message() → Plaintext
```

Messages are encrypted under the current epoch's key schedule. The relay forwards the opaque `MlsMessage` blob without any ability to decrypt it.

### 4.6 Reconnection Caveat

After a WebSocket reconnection, a peer's MLS epoch may be stale (the group advanced while they were offline). Messages that must work immediately after reconnection — sync requests, shard coordination, voice channel state changes — are sent as plaintext `HavenMessage` envelopes, not MLS-encrypted `MessageEnvelope`. This is a deliberate design choice: sync probes are idempotent and carry no sensitive content.

---

## 5. Voice and Video Encryption (SFrame)

Real-time voice and video streams are encrypted with **SFrame** using keys derived from the MLS epoch.

### 5.1 Key Derivation

```
SFrame key = MLS group.export_secret("sframe", context=[], key_length=32)
```

Each MLS epoch produces a unique 32-byte SFrame key via the MLS exporter mechanism. When the epoch advances (member join/leave), the SFrame key rotates automatically.

### 5.2 Encryption

- **Algorithm:** AES-128-GCM
- **Key:** 16 bytes (first 16 bytes of the exported secret, or derived per SFrame spec)
- **Nonce:** 12 bytes
- **Auth tag:** 16 bytes

Each audio/video frame is independently encrypted. The short frame lifetime and per-epoch key rotation provide forward secrecy for real-time media.

### 5.3 Transport

Voice/video travels over **WebRTC peer-to-peer connections** (DTLS-SRTP as the base transport, SFrame as the application-layer encryption). The relay is not in the media path — it only carries WebRTC signaling (SDP offers/answers, ICE candidates).

For peers behind symmetric NATs (~5–10% of users), a **TURN server** relays the encrypted media. The TURN server sees only SFrame ciphertext.

---

## 6. File Transfer Encryption

### 6.1 Direct File Transfer (P2P)

Files under 34 MB are sent directly via WebRTC data channels or WebSocket relay streaming.

- **Algorithm:** AES-256-GCM
- **Key:** 32 bytes, randomly generated per file (`getrandom`)
- **Nonce:** 12 bytes, randomly generated per file (`getrandom`)
- **Auth tag:** 16 bytes (implicit in GCM)

The entire file is encrypted as a single unit. The AES key and nonce are transmitted inside the `FileHeader` message, which itself is encrypted via Olm (DMs) or MLS (servers).

### 6.2 Hollow Share (Large File Sharing)

Share is a chunked, resumable P2P file sharing system for files of any size.

**Chunk encryption:**
- **Algorithm:** AES-256-GCM
- **Key:** 32 bytes, randomly generated per share (`getrandom`)
- **Chunk size:** 262,144 bytes (256 KiB)
- **Nonce derivation:** `[0x00; 4] || chunk_index_big_endian_u64` (12 bytes)
  - Deterministic: same key + different chunk index = unique nonce
  - No nonce reuse possible within a share's lifetime

**Manifest:**
```json
{
  "version": 1,
  "file_name": "...",
  "mime": "...",
  "total_size": 123456789,
  "chunk_size": 262144,
  "chunk_count": 472,
  "chunk_hashes": ["<SHA-256 hex of each ciphertext chunk>", ...],
  "created_at": 1713456789
}
```

**Root hash:** SHA-256 of the canonical JSON manifest. Serves as the content identifier.

**Share link format:**
```
hollow://share/<base64url([version: 1 byte][root_hash: 32 bytes][key: 32 bytes])>
```

The link encodes everything needed to verify and decrypt the file. Anyone with the link can download; anyone without it cannot.

**Peer coordination:**
- Chunk availability tracked via compact bitmaps (MSB-first, 1 bit per chunk).
- Have-maps broadcast every 10 seconds.
- Rarest-first chunk scheduling (BitTorrent-style).
- Max 4 inflight chunks per peer to avoid data channel buffer overflow.
- Receiver-initiated WebRTC reconnection with 10-second stale-offer timeout.

---

## 7. Vault (Distributed Encrypted Storage)

The vault provides persistent storage for server files using erasure coding.

### 7.1 Encryption

Files are encrypted **before** erasure coding:
- **Algorithm:** AES-256-GCM (same as Section 6.1)
- **Key/nonce:** Random, stored in the file manifest (encrypted via MLS for the server)

### 7.2 Erasure Coding

**Library:** `reed-solomon-erasure` v6.0

**Parameter selection:**
- **≤5 members:** Full replication. The entire encrypted file is stored by all eligible peers. No erasure coding applied (sentinel values k=0, m=0).
- **6+ members:** Reed-Solomon erasure coding with adaptive parameters:
  - `k` data shards + `m` parity shards, computed from member count
  - Any `k` of `k+m` shards can reconstruct the original ciphertext
  - Shard size: `ceil(ciphertext_length / k)`

**Content ID:** SHA-256 hex of the ciphertext (before splitting into shards). Used as the unique content identifier across the network.

### 7.3 Shard Format

```
[header_length: u32 LE][header JSON][shard data]
```

Header:
```json
{
  "shard_index": 0,
  "content_id": "<SHA-256 hex>",
  "k": 4,
  "m": 2,
  "shard_size": 65536,
  "total_data_size": 250000
}
```

### 7.4 Storage Tiers

- **Standard:** 365-day retention
- **Low:** 90-day retention
- **Permanent:** No expiration

Storage tier multipliers adjust the k/m ratio to balance redundancy against storage cost.

### 7.5 Storage Layout

- Shards: `~/.hollow/vault/{server_id}/{shard_key}.shard`
- Decrypted cache: `~/.hollow/vault_cache/{content_id}.{ext}` (LRU-evicted, 1 GB cap)
- Full-replication files: `~/.hollow/files/{file_id}.{ext}`

---

## 8. CRDT Synchronization

Server state (channels, members, roles, settings) is replicated across all members using **Conflict-free Replicated Data Types (CRDTs)** via the `crdts` v7.3 library.

### 8.1 Hybrid Logical Clock (HLC)

All CRDT operations are timestamped with a custom **Hybrid Logical Clock**:

```
HlcTimestamp {
    physical_ms: u64,   // wall clock (milliseconds since epoch)
    counter: u32,       // logical counter for same-millisecond ordering
    actor: String,      // peer ID (tiebreaker for simultaneous events)
}
```

Properties:
- Monotonically increasing per actor.
- Causally consistent: if event A happened before event B, A's HLC < B's HLC.
- Wall clock drift protection: updates more than 5 minutes ahead of local time are rejected.
- Deterministic ordering: `(physical_ms, counter, actor)` tuple provides total order.

### 8.2 Operation Format

```rust
CrdtOp {
    server_id: String,
    hlc: HlcTimestamp,
    author: String,         // peer ID of originator
    payload: CrdtPayload,  // the actual mutation
}
```

### 8.3 Payload Types

| Category | Operations |
|----------|-----------|
| Server | ServerCreated, ServerRenamed, ServerSettingChanged |
| Channels | ChannelAdded, ChannelRemoved, ChannelRenamed |
| Members | MemberAdded, MemberRemoved |
| Roles | RoleChanged (owner/admin/moderator/member) |
| Messages | MessagePinned, MessageUnpinned |
| Storage | StoragePledgeChanged |

### 8.4 Conflict Resolution

**Last-Write-Wins (LWW)** per key, ordered by HLC timestamp. For role conflicts, a priority system applies:

| Role | Priority |
|------|----------|
| Owner | 3 |
| Admin | 2 |
| Moderator | 1 |
| Member | 0 |

Higher-priority role changes take precedence over lower-priority ones at the same HLC timestamp.

### 8.5 Synchronization Protocol

When two peers connect:
1. Each sends a **state vector** — a compact summary of the latest HLC timestamp seen from each author.
2. The recipient computes the delta: operations it has that the sender lacks.
3. The delta is transmitted as a batch of `CrdtOp` values.
4. Both peers converge to the same state.

This is idempotent: applying the same operation twice has no effect. Peers can sync with any other online member — there is no single source of truth.

---

## 9. Relay Architecture

### 9.1 Design Principle

The relay is a **dumb pipe**. It routes encrypted blobs between peers based on room membership. It has no knowledge of message semantics, encryption keys, or application state.

### 9.2 Authentication

Peers authenticate to the relay via Ed25519 signature:

```
Signed payload: "hollow-ws-auth:{peer_id}:{unix_timestamp}"
```

The relay verifies the signature against the provided public key and checks that the timestamp is within ±60 seconds of server time (replay protection).

### 9.3 Room Model

- Peers join named rooms (alphanumeric + `:-_.`, max 128 characters).
- Messages can be broadcast to all room members or sent directly to a specific peer.
- Max 100 rooms per peer.
- Max 10 MB per message (text or binary).
- Binary frame rate limiting: 20 tokens/sec, 100-token burst.

### 9.4 What the Relay Sees

| Data | Visible to Relay |
|------|-----------------|
| Peer IDs | Yes |
| Room membership | Yes |
| Connection timestamps | Yes |
| Message contents | **No** (encrypted) |
| Encryption keys | **No** |
| File contents | **No** (encrypted) |
| Message signatures | **No** (inside encrypted envelope) |
| User profiles | **No** (encrypted) |

### 9.5 Binary Protocol

Two binary frame types for efficient transport:

- **0x01 (Broadcast):** `[0x01][room_hash: 32 bytes][payload]` — forwarded to all room members.
- **0x02 (Direct):** `[0x02][room\0][target_peer\0][payload]` — forwarded to a specific peer; relay replaces target with sender ID.

Used for WebRTC signaling, file streaming, and shard transfers.

---

## 10. Message Signing and Verification

### 10.1 Canonical Signing Payload

Every message carries an Ed25519 signature over a canonical string:

```
hollow-msg:{type}:{context}:{sender}:{timestamp_ms}:{text}
```

| Field | Value |
|-------|-------|
| type | `"ch"` (channel) or `"dm"` (direct message) |
| context | `"{server_id}:{channel_id}"` for channels; `"{recipient_peer_id}"` for DMs |
| sender | Sender's peer ID |
| timestamp_ms | Milliseconds since Unix epoch (i64) |
| text | Message body (may be empty for file-only messages) |

### 10.2 Verification

1. Decode the sender's public key from the protobuf-encoded bytes.
2. Derive the peer ID from the public key (identity multihash → base58).
3. Verify that the derived peer ID matches the claimed sender.
4. Verify the Ed25519 signature over the canonical payload.

If any step fails, the message is rejected. This prevents impersonation: even if an attacker can inject messages into the encrypted channel, they cannot forge a valid signature without the sender's private key.

### 10.3 Timestamp Integrity

The timestamp in the signature payload is authoritative. The Dart UI hydrates its display timestamp from the Rust-signed value, not from `DateTime.now()`. This prevents timestamp manipulation on the receiver side.

---

## 11. Summary of Cryptographic Primitives

| Component | Algorithm | Key Size | Library |
|-----------|-----------|----------|---------|
| Identity | Ed25519 | 256-bit | ed25519-dalek 2.x |
| Mnemonic | BIP-39 | 256-bit entropy (24 words) | bip39 2.2 |
| DM encryption | Olm (Double Ratchet / Curve25519) | 256-bit | vodozemac 0.9 |
| Server encryption | MLS (X25519 + AES-128-GCM + SHA-256 + Ed25519) | 128-bit AEAD | OpenMLS 0.8 |
| Voice/video | SFrame (AES-128-GCM, MLS-derived keys) | 128-bit | Custom + OpenMLS |
| File encryption | AES-256-GCM | 256-bit key, 96-bit nonce | aes-gcm 0.10 |
| Share chunks | AES-256-GCM (deterministic nonce per index) | 256-bit key, 96-bit nonce | aes-gcm 0.10 |
| Erasure coding | Reed-Solomon | Adaptive k/m | reed-solomon-erasure 6.0 |
| Message signing | Ed25519 | 256-bit | ed25519-dalek 2.x |
| Relay auth | Ed25519 (timestamp-bound) | 256-bit | ed25519-dalek 2.x |
| CRDT ordering | Hybrid Logical Clock | 64-bit physical + 32-bit counter | Custom |
| Local storage | SQLCipher (AES-256-CBC) | 256-bit | SQLCipher |

---

## 12. Limitations and Future Work

- **No post-quantum cryptography.** All key exchanges use Curve25519. A future migration to ML-KEM (Kyber) is planned but not prioritized for the alpha.
- **No traffic analysis protection.** Message sizes and timing patterns are visible to the relay and network observers. Pluggable transports (obfs4, domain fronting) are planned for censorship-resistant deployments.
- **Single relay dependency.** The current deployment uses a single relay server. Multi-relay support with cross-relay room gossip is designed but not yet implemented.
- **No device linking.** Each device has an independent identity. Multi-device sync (QR code linking, cross-device key sharing) is planned.
- **Trust-on-first-use (TOFU).** Peer identity verification relies on out-of-band fingerprint comparison. There is no certificate authority or web of trust.

---

*This document describes the Hollow protocol as implemented in the Alpha release. The protocol is subject to change. For the latest implementation details, refer to the source code.*
