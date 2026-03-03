# HAVEN — Project Instructions for Claude Code

## What Is This
Haven is a fully distributed, encrypted Discord alternative. No central servers. Members collectively host the server. See `HAVEN_PLAN.md` for the full architecture.

## Tech Stack
- **UI:** Flutter (Dart) — all platforms (Windows, macOS, Linux, Android, iOS, Web)
- **Backend:** Rust via `flutter_rust_bridge` v2.11.1 FFI
- **Networking:** libp2p 0.56 (QUIC, TCP, WSS, mDNS, Kademlia, relay, DCUtR, AutoNAT)
- **E2EE:** vodozemac (Olm/Double Ratchet) for 1:1, MLS planned for groups
- **Local DB:** SQLCipher (encrypted SQLite)
- **Identity:** Ed25519 keypairs via BIP-39 mnemonic
- **Org ID:** com.anonlisten
- **Project name:** haven

## Project Structure
```
HAVEN/
├── lib/                  # Dart/Flutter code (UI, app logic, state management)
│   ├── main.dart         # Entry point (ProviderScope + RustLib.init + window_manager init)
│   └── src/
│       ├── core/         # Models, Riverpod providers, service wrappers
│       ├── theme/        # Haven design system (colors, spacing, typography, ThemeExtension)
│       └── ui/
│           ├── shell/    # Layout: haven_shell, server_strip, channel_sidebar, member_panel, user_bar, mobile_nav, window_title_bar
│           ├── chat/     # ChatPane, MessageBubble
│           ├── sidebar/  # PeerCard, EmptyPeerList (reusable components)
│           ├── components/ # HavenPressable, HavenButton, HavenTextField, HavenDialog, HavenTooltip, HavenToast, HavenToggle, HavenAvatar, HavenCard, StatusDot
│           ├── dialogs/  # InviteDialog, MnemonicDialog, CreateServerDialog, CreateChannelDialog
│           └── animations/ # HavenCurves, HavenDurations, FadeSlideTransition, ScaleFadeTransition, SelectionShimmer, AmbientBackground, StartupRevealScope, RevealWidgets
├── rust/haven_core/      # Rust library crate (networking, crypto, storage)
│   └── src/
│       ├── api/          # FFI layer (flutter_rust_bridge scans these)
│       ├── node/         # libp2p swarm + signaling client
│       ├── crypto/       # Olm encryption + persistence
│       ├── identity/     # Ed25519 keypair management
│       └── storage/      # SQLCipher message store
├── relay/                # Combined relay + signaling server (standalone binary, deployed on OVH VPS)
├── rust_builder/         # flutter_rust_bridge build system (cargokit)
├── HAVEN_PLAN.md         # Full architecture & design document (~1500 lines)
└── CLAUDE.md             # This file
```

## Build & Run Commands
```bash
# Run on current platform (debug)
flutter run -d windows

# Build release
flutter build windows

# Check Rust code
cd rust/haven_core && cargo check
cd rust/haven_core && cargo clippy

# Regenerate FFI bindings after Rust API changes
flutter_rust_bridge_codegen generate

# Deploy relay server updates to VPS
scp relay/src/*.rs ubuntu@141.227.186.209:/home/ubuntu/relay/src/
ssh ubuntu@141.227.186.209 "cd relay && cargo build --release && sudo systemctl restart haven-relay"
```

## Current Phase
**UI Polish Pass** — COMPLETE (Mar 2 2026).

Phases 1 (LAN E2EE chat), 2 (cross-network E2EE, prekey bundles, connection management, invite links), 2.5 (UI Foundation), 2.75 (Haven Design System v2) are complete. WSS transport (Nginx + Let's Encrypt on port 443) deployed for censorship resistance.

**Phase 2.75 includes:** Complete custom widget system replacing ALL Material Design defaults. Zero InkWell, IconButton, SnackBar, Tooltip, AlertDialog, FilledButton, TextButton, or OutlinedButton remain in the codebase. All interactions use spring physics (no ripple). See "Haven Design System" section below.

**Phase 3 foundation (Rust CRDT backend):** COMPLETE. `crdts` crate + custom `AdminLwwReg` for admin-only fields. 18 Rust tests passing. Dart FFI bindings generated, models (`ServerInfo`, `ChannelInfo`), providers (`serverListProvider`, `channelListProvider`, `selectedServerProvider`, `selectedChannelProvider`), and event dispatch for all 7 CRDT events wired. Server creation + channel system UI done (ServerStrip with server icons, dual-mode ChannelSidebar, channel placeholder in ChatPane, server members in MemberPanel).

**UI Polish:** COMPLETE. Tier 1 (focus glow, hover shadows, auto-scroll, crossfade transitions), Tier 2 (server strip gradient, breathing pulse StatusDot, message entrance), Tier 3 (full-screen glassmorphism blur, selection shimmer, comprehensive 1800ms startup reveal with building-block animations), ambient background (drifting gradient blobs on chat area).

**Next:** Phase 3 — continue with channel messaging, sync protocol, room gating.

## Haven Design System (Phase 2.75)
All UI interactions go through custom Haven widgets — no Material defaults anywhere. Change behavior in one place, applies everywhere.

- **HavenPressable** (`haven_pressable.dart`): Universal interaction widget. Press: opacity 0.85 + scale 0.98, spring physics reverse. Hover: smooth color transition 150ms + shadow lift. No ripple. `subtle` mode disables press animation (for list items like channel tiles, peer cards).
- **HavenButton** (`haven_button.dart`): 4 variants — `.filled()` (accent bg), `.ghost()` (transparent), `.outline()` (1px border), `.danger()` (error red). Self-contained StatefulWidget with own press/hover animation. Hover glow shadow (20% opacity, 8px blur). Props: `onPressed`, `child`, `icon`, `expand`, `compact`.
- **HavenTextField** (`haven_text_field.dart`): Single `TextField` with `OutlineInputBorder` (no wrapper container). `haven.elevated` fill, border color animates (border→accent on focus, →error on error). Focus glow (teal BoxShadow 15% opacity, 6px blur). Error shake animation. Optional `prefixIcon`, `borderRadius`, `isDense`.
- **HavenDialog** (`haven_dialog.dart`): `showHavenDialog()` uses `showGeneralDialog` with scale 0.95→1.0 + fade entrance (200ms). Full-screen glassmorphism: `BackdropFilter` in `transitionBuilder` blurs entire screen (animated 0→12 sigma). Barrier: 8% black. Dialog bg: 92% opacity, accent border, 24px shadow.
- **HavenTooltip** (`haven_tooltip.dart`): Overlay-based, 400ms hover delay, 100ms fade+slide entrance. Dark style.
- **HavenToast** (`haven_toast.dart`): Slide-up + fade, auto-dismiss. Three types: success/error/info. Only one visible at a time. Replaces SnackBar. Controller disposed only by widget's `dispose()` (prevents double-dispose).
- **HavenToggle** (`haven_toggle.dart`): Spring physics thumb, color crossfade track.
- **StatusDot** (`status_dot.dart`): StatefulWidget with optional `pulse` for breathing glow animation (3s cycle, BoxShadow). Used in peer cards, member tiles, user bar.

## Key Architecture Notes
- **Peer state tracking in swarm.rs:** `connected_peers`, `expected_peers`, `disconnected_peers` HashSets. Bootstrap handler skips disconnected + connected peers. `InboundCircuitEstablished` clears disconnected. `ConnectionEstablished` triggers proactive DHT prekey fetch for auto-encryption. Ping: 5s/5s. Rebootstrap: 60s unconditional.
- **Event streaming:** Rust→Dart via `StreamSink` (flutter_rust_bridge), not polling. `watch_network_events()` in `api/network.rs`, `EventStreamNotifier` in `event_provider.dart`
- **Navigation shell:** Discord-like 4-panel layout — ServerStrip (72px) | ChannelSidebar (240px) | ChatPane | MemberPanel (240px). Responsive: mobile uses bottom nav with single-panel views.
- **Window chrome:** `window_manager` ^0.5.1, `setAsFrameless()`, custom 32px title bar (`window_title_bar.dart`). Native Win32 changes in `windows/runner/` for dark bg brush, DWM compositing, no-flicker resize. Known issue: drag-from-maximized doesn't live-redraw until drop (Flutter engine limitation).
- **Theme:** Dark primary (default) + light secondary. `HavenTheme.dark()`/`.light()` ThemeExtension, `HavenThemeData.dark()`/`.light()` factories. Toggle via `themeModeProvider` (Riverpod StateProvider). No persistence yet (Phase 3). Frutiger Aero theme deferred as future third option.
- **Icons:** `lucide_icons: ^0.257.0`. All `LucideIcons.*` (camelCase). Note: v0.257.0 uses `alertTriangle`/`alertCircle` (not `triangleAlert`/`circleAlert`). No `cloudCheck` — uses `cloud`.
- `haven_log!` macro (`#[macro_export]` in lib.rs) logs to stderr + `haven_debug.log` (works in release builds)
- Relay: OVH VPS 141.227.186.209, Nginx TLS termination on 443 → plain WS on 127.0.0.1:9001
- Domain: relay.anonlisten.com (Hostinger DNS, Let's Encrypt cert)
- Connection priority: LAN (mDNS) → Hole punch (DCUtR) → QUIC relay → TCP relay → WSS relay
- libp2p SwarmBuilder chain: with_tcp → with_quic → with_dns → with_websocket → with_relay_client → with_behaviour

## Coding Conventions
- Dart: follow standard `flutter_lints` / `analysis_options.yaml`
- Rust: follow standard `cargo clippy` recommendations
- File naming: snake_case for Dart and Rust files
- No Electron, no Node.js, no web frameworks — Flutter only for UI

## Rules
- Never commit secrets, keys, or credentials
- Rust handles: networking (libp2p), crypto, CRDTs, storage engine
- Dart handles: UI, app logic, state management
- All crypto operations must use constant-time implementations
- Ask before making architectural decisions not covered in HAVEN_PLAN.md
- When updating memory (MEMORY.md), also update this file (CLAUDE.md) if relevant
- Ask user for external actions (installs, VPS ops, account setup) instead of trying silently
