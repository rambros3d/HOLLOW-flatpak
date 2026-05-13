# HOLLOW — Complete Feature Matrix

> Generated 2026-05-12, updated 2026-05-12. Covers every user-facing feature on desktop, with mobile porting status.
> Used for: mobile port punch list, integration test coverage planning, QA tracking.

## Legend

| Status | Meaning |
|--------|---------|
| **Done** | Fully implemented on mobile |
| **Partial** | Basic version exists, missing interactions or polish |
| **Not impl** | Desktop only, no mobile equivalent |
| **N/A** | Not applicable to mobile (e.g. window chrome) |

---

## 1. Chat — Core Messaging

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 1 | Send text message | `chat_pane.dart`, `channel_chat_pane.dart` | Done | Enter / tap send | Desktop: Enter sends. Mobile: tap send button |
| 2 | Edit own message | `message_action_bar.dart`, `chat_pane.dart` | Done | Long-press → Edit → inline TextField | Mobile: Save/Cancel buttons. Sync gap: offline peers don't receive edits |
| 3 | Delete message (own/mod) | `message_action_bar.dart` | Done | Long-press → Delete → confirm | Mobile: inline confirmation in bottom sheet. Sync gap: same as edit |
| 4 | Copy message text | `message_action_bar.dart` | Done | Long-press → Copy Text | Toast confirmation |
| 5 | Emoji reactions (add) | `reaction_bar.dart`, `emoji_picker.dart` | Done | Long-press → quick react or full grid | 6 quick emojis + "More..." for full 30 |
| 6 | Emoji reactions (remove) | `reaction_bar.dart` | Done | Tap reaction pill on message | Toggle off own reaction |
| 7 | Emoji reactions (view) | `reaction_bar.dart` | Done | Reaction pills below message | Count + accent highlight for own reactions |
| 8 | Reply to message | `message_action_bar.dart`, `chat_pane.dart` | Done | Long-press → Reply | Reply preview above input bar |
| 9 | Reply preview in bubble | `message_bubble.dart` | Done | Inline display | Shows quoted sender + text above message |
| 10 | Pin message (channel) | `channel_chat_pane.dart`, `message_action_bar.dart` | Not impl | Hover → pin | Permission-gated, channel only |
| 11 | Pinned messages list | `channel_chat_pane.dart` | Not impl | Click pin icon in header | Modal with pinned count |
| 12 | Message proof / info | `message_action_bar.dart`, `message_proof_dialog.dart` | Done | Long-press → Message Info | Shows sender, timestamp, signature verification |
| 13 | Message action bar (hover) / long-press sheet | `message_action_bar.dart`, `mobile_message_actions.dart` | Done | Long-press → bottom sheet | Mobile: bottom sheet with actions. Desktop: hover overlay |

## 2. Chat — File Attachments

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 14 | Send file attachment | `chat_pane.dart`, `chat_drop_zone.dart` | Done | Click paperclip / file picker | Mobile: file picker only, no drag-drop (N/A on mobile) |
| 15 | Image inline display | `file_attachment_widget.dart` | Done | Tap → fullscreen | Uses desktop widget, renders inline |
| 16 | Image fullscreen lightbox | `file_attachment_widget.dart` | Done | Tap image | Uses desktop fullscreen viewer |
| 17 | Video thumbnail display | `video_message_bubble.dart` | Done | Tap → play | Uses desktop video player widget |
| 18 | Video inline playback | `video_message_bubble.dart` | Done | Tap play | Uses desktop video player widget |
| 19 | Audio playback inline | `audio_message_bubble.dart` | Done | Tap play | Uses desktop audio player widget |
| 20 | Download file | `file_attachment_widget.dart`, `mobile_chat_route.dart` | Done | Long-press → Save File | Bottom sheet action, save dialog with WebP conversion |
| 21 | Copy image to clipboard | `chat_input_shortcuts.dart` | N/A | Hover → image copy | Desktop only (super_clipboard unreliable on Android); Save File covers mobile |
| 22 | Paste image from clipboard | `chat_input_shortcuts.dart` | N/A | Ctrl+V | Desktop only; mobile uses file picker + Android native paste |
| 23 | Drag-drop file into chat | `chat_drop_zone.dart` | N/A | Drag file over area | Desktop only |
| 24 | File progress indicator | `download_manager_popup.dart` | Done | Inline in message | Uses desktop progress widget |
| 25 | Download manager popup | `download_manager_popup.dart` | N/A | Click icon to toggle | Desktop popup, not applicable to mobile |

## 3. Chat — Link Previews

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 26 | Link preview (OG metadata) | `chat_pane.dart`, `channel_chat_pane.dart` | Not impl | Auto-fetch on URL type | 600ms debounce, sender-side only |
| 27 | Link preview card | `link_preview_card.dart` | Not impl | Rendered below message | 400px max, thumbnail + title/desc |
| 28 | Staged link preview | `staged_link_preview_card.dart` | Not impl | Above input while composing | Loading/loaded/failed states |
| 29 | Hollow protocol links | `hollow_link_card.dart`, `hollow_link_utils.dart` | Not impl | Click card | Share/ServerInvite/RoomInvite types |

## 4. Chat — Voice Messages

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 30 | Record voice message | `voice_recorder_bar.dart` | Not impl | Click mic button | OGG Opus, 34hr limit, waveform viz |
| 31 | Voice message playback | `audio_message_bubble.dart` | Not impl | Click play in bubble | Full inline player |

## 5. Chat — Text Rendering & Formatting

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 32 | Bold `**text**` | `message_text_parser.dart` | Partial | Auto-parse | Full parser + tokenizer + cache |
| 33 | Italic `*text*` | `message_text_parser.dart` | Partial | Auto-parse | |
| 34 | Code block `` ```code``` `` | `message_text_parser.dart` | Partial | Auto-parse | Full-width container |
| 35 | Inline code `` `code` `` | `message_text_parser.dart` | Partial | Auto-parse | Background pill |
| 36 | Strikethrough `~~text~~` | `message_text_parser.dart` | Partial | Auto-parse | |
| 37 | Spoiler `\|\|text\|\|` | `message_text_parser.dart` | Partial | Tap to reveal/hide | |
| 38 | URL auto-linking | `message_text_parser.dart` | Partial | Clickable accent text | http(s):// and hollow:// |
| 39 | @mention autocomplete | `channel_chat_pane.dart` | Not impl | Type @ → overlay popup | Up/down/enter/esc, shows avatars |
| 40 | @mention highlight | `channel_message_bubble.dart`, `message_text_parser.dart` | Not impl | Accent pill badges | Bold, accent background |
| 41 | Keyboard shortcuts (Ctrl+B/I/E) | `chat_input_shortcuts.dart` | N/A | Wrap selection | Desktop only |
| 42 | Keyboard shortcuts (Shift+Enter) | `chat_input_shortcuts.dart` | N/A | Insert newline | Desktop: Shift+Enter. Mobile: keyboard newline |

## 6. Chat — Status & Navigation

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 43 | Typing indicator (show) | `chat_pane.dart`, `channel_chat_pane.dart` | Partial | Above input bar | Custom TypingDots animation |
| 44 | Typing indicator (send) | `chat_pane.dart`, `channel_chat_pane.dart` | Partial | 3s throttle on input | DM only on mobile |
| 45 | Message grouping by sender | `chat_pane.dart` | Partial | Consecutive within 5 min | Implemented on mobile |
| 46 | Message timestamp separator | `chat_pane.dart` | Partial | "Today"/"Yesterday"/date | Implemented on mobile |
| 47 | Scroll-to-bottom button | `chat_pane.dart`, `channel_chat_pane.dart` | Partial | Floating "N new" pill | Auto-hide at bottom |
| 48 | Unread message indicator | `chat_pane.dart`, `channel_chat_pane.dart` | Partial | Accent pill with count | Click scrolls to unread |
| 49 | In-channel search | `channel_chat_pane.dart` | Not impl | Ctrl+K or search icon | Full-text + regex in SQLCipher |
| 50 | Search results navigation | `channel_chat_pane.dart` | Not impl | Click result → jump | Highlight + scroll to match |
| 51 | Per-DM mute toggle | `chat_pane.dart` | Not impl | Click bell icon | Per-conversation mute |

## 7. Chat — Layout & Panels

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 52 | DM chat (1:1) | `chat_pane.dart` | Partial | Full ChatPane | Mobile: basic MobileChatRoute |
| 53 | Channel chat (server text) | `channel_chat_pane.dart` | Partial | Full ChannelChatPane | Mobile: basic MobileChatRoute |
| 54 | Chat header bar | `chat_pane.dart`, `channel_chat_pane.dart` | Partial | Avatar, name, status, buttons | Mobile: basic header + back button |
| 55 | Member panel toggle | `channel_chat_pane.dart` | Not impl | Click users icon | Right sidebar 240px |
| 56 | DM profile panel | `chat_pane.dart` | Not impl | Click user icon | Left 240px panel with profile |
| 57 | DM call buttons (voice) | `chat_pane.dart` | Not impl | Click phone icon | Green when active |
| 58 | DM call buttons (video) | `chat_pane.dart` | Not impl | Click video icon | Toggle video |
| 59 | Inline call panel (DM) | `chat_pane.dart` | Not impl | Slides down during call | Video/audio controls |
| 60 | Screen share overlay (DM) | `chat_pane.dart` | Not impl | Click monitor icon | Full-bleed with chat overlay |
| 61 | Split view (dock mode) | `chat_pane.dart`, `hollow_shell.dart` | N/A | Ctrl+Shift+\ | Desktop dock layout only |

## 8. Chat — Input Bar

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 62 | Text input field | `chat_pane.dart`, `channel_chat_pane.dart` | Partial | Max 5 lines, 4000 chars | Auto-expand, mobile 120px max |
| 63 | Attachment button | `chat_pane.dart`, `channel_chat_pane.dart` | Partial | File picker trigger | Both platforms |
| 64 | Microphone button | `chat_pane.dart` | Not impl | Voice recording trigger | Full recorder with cancel/send |
| 65 | Emoji picker button | `message_action_bar.dart` | Not impl | Shows popup picker | Only via action bar on desktop |
| 66 | Send button | `chat_pane.dart`, `channel_chat_pane.dart` | Partial | Enter key or click | Both platforms |

## 9. Chat — Permissions & Sync

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 67 | Read permission gate | `channel_chat_pane.dart` | Not impl | Hide messages | UI-only check |
| 68 | Post permission gate | `channel_chat_pane.dart` | Not impl | Disable input | Shows "no permission" |
| 69 | Channel sync request | `channel_chat_pane.dart` | Not impl | Auto on open | Fire-and-forget |
| 70 | Sync status indicator | `channel_chat_pane.dart` | Not impl | Spinner + text | Syncing/synced/failed |
| 71 | Vault health indicator | `channel_chat_pane.dart` | Not impl | Icon + tooltip | 6+ member servers |

---

## 10. Server Management

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 72 | Create server | `create_server_dialog.dart` | Not impl | Dialog (create/join tabs) | Name input, initial setup |
| 73 | Join server (invite code) | `create_server_dialog.dart` | Partial | Dialog or `hollow://join` link | Mobile: chats tab shows servers |
| 74 | Leave server | `danger_zone_tab.dart` | Not impl | Settings → Danger Zone | Confirmation dialog |
| 75 | Delete server | `danger_zone_tab.dart` | Not impl | Settings → Danger Zone | Owner only, confirmation |
| 76 | Server name edit | `overview_tab.dart` | Not impl | Text input, max 32 chars | `renameServer` CRDT call |
| 77 | Server avatar | `overview_tab.dart`, `server_avatar_provider.dart` | Not impl | File picker + crop | 44×44 in strip, initials fallback |
| 78 | Server description | `overview_tab.dart` | Not impl | Text field, max 256 chars | Multi-line |
| 79 | Server ID display + copy | `overview_tab.dart` | Not impl | Selectable text | Copy button |
| 80 | Server settings access | `channel_sidebar.dart`, `server_settings_panel.dart` | Not impl | Gear icon in header | Permission-gated tabs |
| 81 | Server export/import template | `overview_tab.dart`, `server_template.dart` | Not impl | Export/Import buttons | Layout, roles, channels as template |

## 11. Channel Management

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 82 | Create channel (text) | `create_channel_dialog.dart` | Not impl | Dialog with type selector | Name input |
| 83 | Create channel (voice) | `create_channel_dialog.dart` | Not impl | Dialog with type selector | Same dialog |
| 84 | Delete channel | `channels_tab.dart` | Not impl | Settings context menu | Confirmation dialog |
| 85 | Rename channel | `channels_tab.dart` | Not impl | Settings context menu | Dialog with text input |
| 86 | Reorder channels (drag-drop) | `channels_tab.dart` | Not impl | Drag in settings | Layout saved via `updateChannelLayout` |
| 87 | Channel categories | `channels_tab.dart`, `channel_sidebar.dart` | Not impl | Collapsible headers | Chevron toggle, state tracked |
| 88 | Channel visibility toggle | `channels_tab.dart` | Not impl | Settings dropdown | everyone/moderator/admin |
| 89 | Channel sidebar display | `channel_sidebar.dart` | Partial | Always visible in server | Categorized channels, unread dots |
| 90 | Channel switching | `channel_sidebar.dart` | Partial | Click channel | Updates `selectedChannelProvider` |
| 91 | Unread per channel | `unread_provider.dart`, `channel_sidebar.dart` | Partial | Blue dot / @mention badge | Mute-aware |

## 12. Members & Roles

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 92 | Member list panel | `member_panel.dart` | Partial | Right sidebar 240px | Online first with glow divider |
| 93 | Member online/offline status | `member_panel.dart` | Partial | Status dot on avatar | Green = online, gray = offline |
| 94 | Member profile popup | `member_panel.dart`, `profile_card_popup.dart` | Partial | Click member | Peer ID, role, Twitch, labels |
| 95 | Member sync indicator | `member_panel.dart` | Partial | Spinning refresh icon | Replaces status dot during sync |
| 96 | Assign roles | `members_tab.dart` | Not impl | Settings dropdown | Owner/Admin only |
| 97 | Change member role | `members_tab.dart` | Not impl | Settings role selector | Priority-based (lower-rank only) |
| 98 | Kick members | `members_tab.dart` | Not impl | Settings button | Admin+ only |
| 99 | Ban/unban members | `members_tab.dart` | Not impl | Settings section | `_BannedMembersSection` |
| 100 | Create/edit roles | `roles_tab.dart` | Not impl | Settings tab | 6 permission toggles |
| 101 | Labels (cosmetic) | `labels_tab.dart` | Not impl | Settings tab | Create, assign colors, self-assign |
| 102 | Server nickname | `overview_tab.dart` | Not impl | Text input, max 32 chars | Per-server "Your Identity" |

## 13. Invitations & Twitch

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 103 | Invite generation | `channel_sidebar.dart`, `invite_dialog.dart` | Not impl | Header button / dialog | `hollow://join?server=<id>` |
| 104 | Invite link copy | `invite_dialog.dart` | Not impl | Copy button | Server ID display + link |
| 105 | Twitch verification toggle | `overview_tab.dart` | Not impl | Settings toggle | Master enable/disable |
| 106 | Twitch channel linking | `overview_tab.dart` | Not impl | Text input + fill | Channel ID + display name |
| 107 | Twitch min follow days | `overview_tab.dart` | Not impl | Number input | 0 = just follow |
| 108 | Twitch subscription req | `overview_tab.dart` | Not impl | Toggle | Require sub not just follow |
| 109 | Twitch owner-online | `overview_tab.dart` | Not impl | Toggle | Only owner accepts joins |
| 110 | Twitch join dialog | `twitch_join_dialog.dart` | Not impl | Multi-step modal | Requirements → connect → verify → result |
| 111 | Twitch badge on member | `member_panel.dart` | Not impl | Purple icon + username | Loaded from profile |

---

## 14. Profile & Identity

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 112 | Profile card popup | `profile_card_popup.dart` | Not impl | Hover/click avatar | Full profile: avatar, banner, name, status, about, badges |
| 113 | Edit display name | `user_settings_dialog.dart` | Not impl | Text field, max 32 chars | Profile tab |
| 114 | Edit status | `user_settings_dialog.dart` | Not impl | Text field, max 48 chars | Profile tab |
| 115 | Edit about me | `user_settings_dialog.dart` | Not impl | Text area, max 128 chars | Profile tab, 3 lines max |
| 116 | Avatar upload/change | `user_settings_dialog.dart` | Not impl | File picker → crop (1:1) | WebP optimization, max 1MB |
| 117 | Avatar clear | `user_settings_dialog.dart` | Not impl | Trash icon | Clear to initials fallback |
| 118 | Avatar GIF support | `user_settings_dialog.dart` | Not impl | File picker accepts .gif | Skip crop, raw bytes |
| 119 | Banner upload/change | `user_settings_dialog.dart` | Not impl | File picker → crop (3:1) | Max 2MB |
| 120 | Banner clear | `user_settings_dialog.dart` | Not impl | Trash icon | Gradient fallback |
| 121 | Banner GIF support | `user_settings_dialog.dart` | Not impl | File picker accepts .gif | Skip crop, raw bytes |
| 122 | Twitch connect/disconnect | `user_settings_dialog.dart` | Not impl | Device code auth button | Profile tab |
| 123 | Peer ID display + copy | `profile_card_popup.dart`, `user_bar.dart` | Partial | Tap to copy | Last 8 chars shown, full ID copied |
| 124 | Recovery phrase display | `mnemonic_dialog.dart` | Partial | Modal dialog | 24-word BIP-39, selectable + copy |
| 125 | Identity creation flow | `welcome_dialog.dart` | Partial | First launch dialog | Create / restore mnemonic / restore backup |
| 126 | Restore from mnemonic | `welcome_dialog.dart` | Partial | Text input (24 words) | Derives Ed25519 keypair |
| 127 | Restore from backup | `welcome_dialog.dart` | Not impl | File picker + passphrase | Decrypt `.hollow` backup |

## 15. Friends & Social

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 128 | Send friend request | `friends_provider.dart`, `profile_card_popup.dart` | Done | Button action | "Add Friend" in profile card |
| 129 | Accept friend request | `friends_provider.dart` | Done | Button action | Accept button |
| 130 | Reject friend request | `friends_provider.dart` | Done | Cross icon | Request rows |
| 131 | Remove friend | `friends_bar.dart` | Not impl | Remove icon | Also clears favourites + active DM |
| 132 | Favourite friends | `favourite_friends_provider.dart`, `friends_bar.dart` | Not impl | Star toggle | Custom order, drag-to-reorder |
| 133 | Local nicknames | `local_nickname_provider.dart`, `profile_card_popup.dart` | Not impl | Set button in profile card | Never synced, max 32 chars |
| 134 | Friends list | `friends_bar.dart`, `mobile_friends_tab.dart` | Done | Horizontal bar / tab | Online-first then alphabetical |
| 135 | Friends manager dialog | `friends_bar.dart` | Not impl | Full-screen dialog | 5 tabs: Friends, Favourites, Incoming, Outgoing, Add |
| 136 | Add friend dialog | `friends_bar.dart`, `mobile_friends_tab.dart` | Done | Input dialog | Peer ID text field |
| 137 | Pending friend badge | `friends_bar.dart` | Partial | Red badge | Count of incoming requests |
| 138 | Start DM conversation | `peer_card.dart`, `mobile_friends_tab.dart` | Done | Tap friend | Navigate to DM chat |
| 139 | Friend search/filter | `friends_bar.dart` | Not impl | Search field | Case-insensitive substring |
| 140 | DM unread count | `friends_bar.dart`, `peer_card.dart` | Done | Red badge on avatar | Respects mute |
| 141 | Last message preview | `peer_card.dart` | Done | Text + timestamp | Truncated, "You:" prefix |
| 142 | Encryption status icon | `peer_card.dart` | Done | Green lock icon | E2E cipher active |
| 143 | Online/offline status | `user_bar.dart`, `peers_provider.dart` | Done | Status dot + text | Color-coded |
| 144 | Invisible mode | `settings_provider.dart`, `user_bar.dart` | Partial | Toggle | Suppresses typing + online status |

---

## 16. Voice — 1:1 DM Calls

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 145 | Initiate voice call | `call_provider.dart`, `chat_pane.dart` | Not impl | Phone icon in DM header | |
| 146 | Accept call | `call_provider.dart`, `incoming_call_dialog.dart` | Not impl | Dialog accept button | 30s timeout |
| 147 | Reject/decline call | `call_provider.dart`, `incoming_call_dialog.dart` | Not impl | Dialog decline button | |
| 148 | Hang up / end call | `call_provider.dart`, `active_call_bar.dart` | Not impl | phoneOff icon | Either party |
| 149 | Video call | `call_provider.dart` | Not impl | Camera icon in DM | Auto-enables after audio stabilizes |
| 150 | Camera toggle mid-call | `call_provider.dart`, `active_call_bar.dart` | Not impl | Video icon | SDP renegotiation |
| 151 | Microphone mute | `call_provider.dart`, `active_call_bar.dart` | Not impl | Mic icon | Toggles track.enabled |
| 152 | Screen share (DM) | `call_provider.dart`, `active_call_bar.dart` | N/A | Monitor icon + dialog | Desktop only |
| 153 | Incoming call dialog | `incoming_call_dialog.dart` | Not impl | Top-center overlay | Avatar, name, type, 30s countdown |
| 154 | Incoming call ringtone | `incoming_call_dialog.dart` | Not impl | Audio playback | Custom file, trimmed, looped |
| 155 | Call duration display | `active_call_bar.dart` | Not impl | MM:SS in call bar | Updates every 1s |
| 156 | Active call bar (floating) | `active_call_bar.dart` | Not impl | Draggable pill | Duration, peer name, controls |
| 157 | PiP video view | `call_video_view.dart` | Not impl | Floating draggable panel | 320×240, local preview 96×72 |
| 158 | Remote volume control | `call_provider.dart` | Not impl | Slider 0-200% | Per-peer |
| 159 | Call stats logging | `call_provider.dart` | Not impl | Diagnostic | 5s after connect: bitrates, codecs, packets |

## 17. Voice — Server Voice Channels

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 160 | Join voice channel | `voice_channel_provider.dart`, `channel_sidebar.dart` | Not impl | Click voice channel tile | |
| 161 | Leave voice channel | `voice_channel_provider.dart`, `voice_channel_panel.dart` | Not impl | Disconnect button | |
| 162 | Participant list | `voice_channel_provider.dart`, `member_panel.dart` | Not impl | Below channel in sidebar | Avatars + status icons |
| 163 | Mute/unmute | `voice_channel_provider.dart`, `voice_channel_panel.dart` | Not impl | Mic icon | |
| 164 | Deafen/undeafen | `voice_channel_provider.dart`, `voice_channel_panel.dart` | Not impl | Headphones icon | No audio output |
| 165 | Camera toggle | `voice_channel_provider.dart`, `voice_channel_panel.dart` | Not impl | Video icon | |
| 166 | Video grid layout | `voice_channel_pane.dart` | Not impl | Adaptive grid | 1→full, 2→1×2, 3→2+1, 4→2×2, 5+→3+2 |
| 167 | Video tile fullscreen | `voice_channel_pane.dart` | Not impl | Tap tile | PiP thumbnails at bottom |
| 168 | Speaking indicator (VAD) | `voice_channel_pane.dart`, `voice_channel_service.dart` | Not impl | 2px accent border | audioLevel threshold 0.01 |
| 169 | Screen share (start) | `voice_channel_provider.dart`, `voice_channel_panel.dart` | N/A | Monitor icon + dialog | Desktop only |
| 170 | Screen share (stop) | `voice_channel_provider.dart`, `voice_channel_pane.dart` | N/A | Stop button | |
| 171 | Screen share full-bleed | `voice_channel_pane.dart` | N/A | UI layout | Full-screen presentation |
| 172 | Screen share quality label | `voice_channel_pane.dart` | Not impl | UI display | "1080p60", "4K30" etc. |
| 173 | Screen share mixed mode | `voice_channel_pane.dart` | N/A | Source switcher tabs | Camera + screen |
| 174 | Chat overlay in voice | `voice_channel_pane.dart` | Not impl | Slide-in 360px panel | Auto-hides after 1s |
| 175 | Controls pill (floating) | `voice_channel_pane.dart` | Not impl | Bottom-center bar | Mute, deafen, camera, share, disconnect + timer |
| 176 | Duration timer | `voice_channel_pane.dart` | Not impl | MM:SS in controls pill | Updates every 1s |
| 177 | Connection status | `voice_channel_panel.dart` | Not impl | Green text | "Voice Connected" + channel name |
| 178 | Voice channel panel | `voice_channel_panel.dart` | Not impl | Bottom of sidebar | Controls during voice session |

## 18. Voice — Audio Settings

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 179 | Input device selection | `settings_provider.dart`, `user_settings_dialog.dart` | Not impl | Dropdown | Persisted, applied on next join |
| 180 | Output device selection | `settings_provider.dart`, `user_settings_dialog.dart` | Not impl | Dropdown | Persisted |
| 181 | Camera device selection | `settings_provider.dart`, `user_settings_dialog.dart` | Not impl | Dropdown | Persisted |
| 182 | Audio quality preset | `settings_provider.dart` | Not impl | Dropdown | Voice/Music/Hi-Fi |
| 183 | Microphone gain | `settings_provider.dart` | Not impl | Slider 0.0-2.0 | Default 1.0 |
| 184 | Echo cancellation | `voice_channel_service.dart`, `voice_service.dart` | Not impl | Audio constraint | getUserMedia flag |
| 185 | Noise suppression | `voice_channel_service.dart`, `voice_service.dart` | Not impl | Audio constraint | getUserMedia flag |
| 186 | Auto gain control | `voice_channel_service.dart`, `voice_service.dart` | Not impl | Audio constraint | getUserMedia flag |
| 187 | Ringtone file picker | `settings_provider.dart` | Not impl | File picker | Custom audio file |
| 188 | Ringtone trim (start/end) | `settings_provider.dart` | Not impl | Slider | Clip range |
| 189 | Ringtone volume | `settings_provider.dart` | Not impl | Slider 0.0-1.0 | Default 0.5 |

## 19. Voice — Encryption & WebRTC

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 190 | SFrame E2EE (DM calls) | `call_provider.dart`, `frame_cryptor_service.dart` | Not impl | Transparent | AES-GCM, random key per call |
| 191 | SFrame E2EE (voice channels) | `voice_channel_provider.dart`, `frame_cryptor_service.dart` | Not impl | Transparent | MLS epoch key, ring size 16 |
| 192 | SFrame E2EE (screen share) | `call_provider.dart`, `voice_channel_provider.dart` | Not impl | Transparent | Dedicated PC |
| 193 | ICE candidate handling | `voice_service.dart`, `voice_channel_service.dart` | Not impl | Queued flush | Max 100/peer |
| 194 | TURN/STUN config | `ice_config_provider.dart` | Not impl | Auto-refresh 50min | HMAC-SHA1 creds |

---

## 20. Settings — Appearance

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 195 | Theme (dark/light) | `user_settings_dialog.dart` | Not impl | Toggle | `themeModeProvider` |
| 196 | Custom accent hue | `user_settings_dialog.dart` | Not impl | HSL slider 0-360° | `accentHueProvider` |
| 197 | Accent color presets | `user_settings_dialog.dart` | Not impl | Add/remove saved hues | JSON array |
| 198 | Background image | `user_settings_dialog.dart` | Not impl | File picker + crop | Disables ambient blobs |
| 199 | Animations toggle | `user_settings_dialog.dart` | Not impl | Toggle | `disableAnimationsProvider` |

## 21. Settings — Layout

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 200 | Layout mode (dock/classic) | `user_settings_dialog.dart` | N/A | Toggle | Desktop only |
| 201 | Minimize to tray | `user_settings_dialog.dart` | N/A | Toggle | Desktop only |
| 202 | Image quality selection | `settings_provider.dart` | Not impl | Radio buttons | Lossless/Balanced/Small |
| 203 | Auto-download threshold | `settings_provider.dart` | Not impl | Number input (MB) | 34-2048 MB |
| 204 | Vault cache cap | `settings_provider.dart` | Not impl | Number input (MB) | 256-10240 MB |

## 22. Settings — Network

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 205 | Relay domain selection | `user_settings_dialog.dart`, `relay_domain_provider.dart` | Not impl | Dropdown | Saved relay list |
| 206 | Custom relay domain entry | `user_settings_dialog.dart` | Not impl | Text input + Add | Validates + saves |
| 207 | Remove relay from list | `user_settings_dialog.dart` | Not impl | Delete button | Can't remove default |
| 208 | License key entry | `license_key_dialog.dart` | Not impl | Modal dialog | XXXX-XXXX-XXXX-XXXX |

## 23. Settings — Dialogs

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 209 | User settings dialog | `user_settings_dialog.dart` | Partial | 5-tab modal | Profile/System/Security/Updates/About |
| 210 | Image crop dialog | `image_crop_dialog.dart` | Not impl | Modal with ratio | 1:1 (avatar) or 3:1 (banner) |
| 211 | Screen share picker dialog | `screen_share_dialog.dart` | N/A | Modal | Screens/windows, res, fps, audio |
| 212 | Storage dashboard dialog | `storage_dashboard_dialog.dart` | Not impl | Modal | Cache, vault, DB usage |
| 213 | Paste link dialog | `paste_link_dialog.dart` | Not impl | Modal | `hollow://` deep link navigation |

---

## 24. Archive & Data

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 214 | Archive dashboard | `archive_dashboard.dart` | Partial | Tab switcher | My Data / Imported |
| 215 | My data view | `my_data_view.dart` | Not impl | Two-panel layout | Conversations + viewer |
| 216 | Conversation list | `archive_conversation_list.dart` | Not impl | Searchable panel | DMs + channels by server |
| 217 | Message viewer | `archive_message_viewer.dart` | Not impl | Read-only display | Full history |
| 218 | DM export | `export_archive_dialog.dart` | Not impl | Right-click → Export | `.hollow-archive` file |
| 219 | Channel export | `export_archive_dialog.dart` | Not impl | Right-click → Export | Single or multi-channel |
| 220 | Server export | `export_archive_dialog.dart` | Not impl | Header → Export | All channels |
| 221 | Export mode (full/text) | `export_archive_dialog.dart` | Not impl | Radio buttons | With/without attachments |
| 222 | Hidden DM management | `archive_conversation_list.dart` | Not impl | Eye toggle | Hide/unhide in archive |
| 223 | Imported archives view | `imported_archives_view.dart` | Not impl | Right panel | Browse + search + verify |
| 224 | Archive search | `archive_conversation_list.dart` | Not impl | Search field | Case-insensitive contains |

## 25. Vault & Recovery

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 225 | Vault files view | `vault_files_view.dart` | Not impl | Right panel | Per-server shard status |
| 226 | Recovery pool join | `recovery_pool_dialog.dart` | Not impl | Join button → dialog | Phrase + shards |
| 227 | Recovery pool dashboard | `recovery_pool_dashboard.dart` | Not impl | Right panel | Status, shard distribution |
| 228 | Shard bundle dialog | `shard_bundle_dialog.dart` | Not impl | Upload modal | |

## 26. Share System

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 229 | Share card display | `share_card.dart` | Not impl | In-chat card | Preview + download button |
| 230 | Share dashboard | `share_dashboard.dart` | Not impl | Full panel | Browse, download, delete, expiry |

---

## 27. Notifications

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 231 | System tray notifications | `system_notification_provider.dart` | Not impl | Native OS toast | Grouped by source |
| 232 | In-app notification overlay | `notification_overlay.dart` | Not impl | Card popup in chat | When app focused |
| 233 | In-app toast (success) | `hollow_toast.dart` | Partial | Green slide-up | Auto-dismiss 3s |
| 234 | In-app toast (error) | `hollow_toast.dart` | Partial | Red slide-up | Auto-dismiss 3s |
| 235 | In-app toast (info) | `hollow_toast.dart` | Partial | Blue slide-up | Auto-dismiss 3s |
| 236 | Unread badge (per DM) | `unread_provider.dart` | Partial | Pill badge | Count on DM list item |
| 237 | Unread badge (per channel) | `unread_provider.dart` | Partial | Pill badge | Count on channel item |
| 238 | Unread badge (per server) | `unread_provider.dart` | Partial | Pill badge | Aggregate on server icon |
| 239 | Unread badge (home button) | `server_strip.dart` | Not impl | Pill on home icon | Total DM unread |
| 240 | Notification level (server) | `notification_provider.dart` | Not impl | Dropdown | All/Mentions/Muted |
| 241 | Notification level (channel) | `notification_provider.dart` | Not impl | Dropdown | Inherit/All/Mentions/Muted |
| 242 | Mute DM notifications | `notification_provider.dart` | Not impl | Toggle | Per-DM |

---

## 28. Shell & Navigation

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 243 | Server strip (classic) | `server_strip.dart` | Not impl | Vertical icon bar 72px | Home, Share, Archive, servers, add |
| 244 | Server strip reordering | `server_strip.dart` | Not impl | Long-press drag | 300ms delay, scale 1.08 |
| 245 | Server folders | `server_strip.dart`, `server_folder_popup.dart` | Not impl | Drag server onto another | 2×2 mini-grid, rename/delete |
| 246 | Friends bar (dock) | `friends_bar.dart` | Not impl | Horizontal 44px | Friend avatars + Add Friend |
| 247 | Bottom bar (dock) | `bottom_bar.dart` | Not impl | Horizontal 56px | Server strip center, user left, utils right |
| 248 | Channel sidebar | `channel_sidebar.dart` | Partial | Left panel 240px | Categories, search, context menus |
| 249 | Member panel | `member_panel.dart` | Partial | Right panel 240px | Online/offline sections |
| 250 | User bar (classic) | `user_bar.dart` | Partial | Bottom of sidebar | Avatar, name, status, settings gear |
| 251 | Home dashboard (dock) | `home_dashboard.dart` | Not impl | 3-column layout | Profile, Recent, Network stats |
| 252 | Voice channel panel | `voice_channel_panel.dart` | Not impl | Bottom of sidebar | Controls during voice |
| 253 | Mobile shell (4-tab) | `mobile_shell.dart` | Done | Bottom nav | Chats/Friends/Archive/Settings |
| 254 | Mobile chat route | `mobile_chat_route.dart` | Done | Push onto navigator | Back button, input bar |

## 29. Window & Desktop Chrome

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 255 | Custom title bar | `window_title_bar.dart` | N/A | 32px chrome | Hollow branding, drag-to-move |
| 256 | Minimize button | `window_title_bar.dart` | N/A | Click | Minimize / tray |
| 257 | Maximize button | `window_title_bar.dart` | N/A | Click | Toggle maximize |
| 258 | Close button | `window_title_bar.dart` | N/A | Click | Close / tray based on setting |
| 259 | Resize handles | `hollow_shell.dart` | N/A | Edge drag | DragToResizeArea |

## 30. Animations & Visual Effects

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 260 | Startup reveal | `startup_reveal.dart` | Not impl | Auto-play | 2.5s staggered fade+slide |
| 261 | Ambient background blobs | `ambient_background.dart` | Not impl | Auto-play ~15fps | Teal+purple, 45s figure-8 |
| 262 | Panel slide animations | `hollow_shell.dart` | Not impl | On open/close | Slide+fade+clip |
| 263 | Crossfade view switching | `hollow_shell.dart` | Not impl | AnimatedSwitcher | Pane transitions |
| 264 | Tooltip fade+slide | `hollow_tooltip.dart` | Not impl | 400ms hover | 100ms fade + 4px slide |
| 265 | Toast slide+fade | `hollow_toast.dart` | Partial | Auto-dismiss | Slide up + fade out |
| 266 | Selection shimmer | `selection_shimmer.dart` | Not impl | Text selection | Shimmer during multi-message select |

## 31. Components (Reusable)

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 267 | HollowAvatar | `hollow_avatar.dart` | Done | Circular image | Lazy-load, initials fallback, GIF |
| 268 | HollowButton | `hollow_button.dart` | Done | Click | filled/ghost/outline/danger variants |
| 269 | HollowTextField | `hollow_text_field.dart` | Done | Text input | Border animation, error state |
| 270 | HollowPressable | `hollow_pressable.dart` | Partial | Press | Opacity+scale spring, subtle mode |
| 271 | HollowDialog | `hollow_dialog.dart` | Partial | Modal | Scale+fade, glassmorphism blur |
| 272 | HollowToggle | `hollow_toggle.dart` | Not impl | Click | Spring thumb, color crossfade |
| 273 | HollowTooltip | `hollow_tooltip.dart` | N/A | 400ms hover | Desktop hover only |
| 274 | HollowToast | `hollow_toast.dart` | Partial | Auto-dismiss | Success/error/info |
| 275 | HollowCard | `hollow_card.dart` | Not impl | Container | Elevated, bordered, rounded |
| 276 | StatusDot | `status_dot.dart` | Done | Visual indicator | Optional pulse glow |
| 277 | ConnectionProgress | `connection_progress.dart` | Partial | Display | Encrypted/Custom/Offline states |

## 32. Context Menus

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 278 | Message context menu | `message_action_bar.dart`, `mobile_message_actions.dart` | Done | Long-press → bottom sheet | Edit/delete/react/reply/copy (pin/info pending) |
| 279 | Channel context menu | `channel_sidebar.dart` | Not impl | Right-click channel | Mute/notify/export/delete |
| 280 | DM context menu | `chat_pane.dart` | Not impl | Right-click DM | Mute/notify/export/block/delete |
| 281 | Server context menu | `server_strip.dart` | Not impl | Right-click server | Settings/mute/leave/invite |
| 282 | Server folder context menu | `server_folder_popup.dart` | Not impl | Right-click folder | Rename/delete |
| 283 | Bottom bar server context menu | `bottom_bar.dart` | Not impl | Right-click server | Same as strip |

## 33. Miscellaneous

| # | Feature | Desktop File(s) | Mobile | Interaction | Notes |
|---|---------|-----------------|--------|-------------|-------|
| 284 | Update checker | `updater_provider.dart` | Not impl | Background | Periodic check |
| 285 | News/blog display | `news_provider.dart` | Not impl | Home dashboard | Latest project news |
| 286 | Relay stats display | `relay_stats_provider.dart` | Not impl | Home network column | Latency, uptime |
| 287 | Animated GIF display | `animated_gif_image.dart` | Partial | Auto-play | Messages + profiles |
| 288 | Responsive layout | `hollow_shell.dart` | Done | LayoutBuilder | <600 mobile, 600-1024 tablet, 1024+ desktop |

---

## Summary

| Category | Total | Done | Partial | Not Impl | N/A |
|----------|-------|------|---------|----------|-----|
| Chat (messaging) | 71 | 19 | 12 | 31 | 9 |
| Server/Channel | 40 | 0 | 7 | 33 | 0 |
| Profile/Identity | 16 | 0 | 4 | 12 | 0 |
| Friends/Social | 17 | 10 | 2 | 5 | 0 |
| Voice (DM calls) | 15 | 0 | 0 | 14 | 1 |
| Voice (channels) | 19 | 0 | 0 | 15 | 4 |
| Voice (settings) | 11 | 0 | 0 | 11 | 0 |
| Voice (encryption) | 5 | 0 | 0 | 5 | 0 |
| Settings | 18 | 0 | 1 | 13 | 4 |
| Archive/Vault | 17 | 0 | 1 | 16 | 0 |
| Notifications | 12 | 0 | 5 | 7 | 0 |
| Shell/Navigation | 12 | 2 | 4 | 5 | 1 |
| Window/Chrome | 5 | 0 | 0 | 0 | 5 |
| Animations | 7 | 0 | 1 | 6 | 0 |
| Components | 11 | 4 | 4 | 2 | 1 |
| Context Menus | 6 | 1 | 0 | 5 | 0 |
| Misc | 5 | 1 | 1 | 3 | 0 |
| **TOTAL** | **288** | **37** | **42** | **183** | **26** |

**Mobile coverage: 13% done, 15% partial, 64% not implemented, 9% desktop-only (N/A)**

### Session 2026-05-13 Progress
- **Section 2 complete (8 done, 4 N/A)**: Image display, lightbox, video, audio, save file, file progress all working
- **+8 features done**: #14-20, #24. N/A: #21-23, #25 (clipboard image, drag-drop, download popup — desktop only)
- **New mobile action**: "Save File" in long-press bottom sheet (reads bytes → FilePicker.saveFile with `bytes:` for Android)
- **Android fix**: FilePicker.saveFile requires `bytes:` param on Android (crashes without it)
- **Android fix**: Added super_clipboard ContentProvider to AndroidManifest.xml (image clipboard still unreliable — deferred)
- **Staged file preview**: Shows thumbnail + filename above input bar with cancel button

### Session 2026-05-12 Progress
- **+12 features done**: Send message, Edit, Delete, Copy, Reactions (add/remove/view), Reply (action + preview in bubble), Message action sheet, Message Info dialog
- **UX polish**: Long-press teal highlight animation + full-width hit target (`HitTestBehavior.opaque`)
- **Known sync gap**: DM edits/deletes are live-only events — offline peers never receive them. Channel sync batch doesn't include edit/delete history. Needs Rust-side sync protocol extension.
- **Section 1 status**: 11/13 done. #10-11 (pin messages) remaining — needs permission provider wiring
- **Test framework**: 16 widget tests passing (mobile shell, nav badges, responsive breakpoints, themes)
