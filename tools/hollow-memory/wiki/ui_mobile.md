# Mobile UI — Shell, Chat Route, and Actions

Covers all mobile-specific UI: the shell layout, chat route, message actions bottom sheet, and navigation. All files under `lib/src/ui/mobile/`.

---

## MobileShell

**File:** `lib/src/ui/mobile/mobile_shell.dart`
**Class:** `MobileShell extends ConsumerWidget`
**Purpose:** 4-tab mobile layout replacing desktop HollowShell below 600px breakpoint.

### Tabs (indexed 0-3)
| Index | Tab | Widget | Icon |
|-------|-----|--------|------|
| 0 | Chats | `MobileChatsTab` | `LucideIcons.messageCircle` |
| 1 | Friends | `MobileFriendsTab` | `LucideIcons.users` |
| 2 | Archive | `MobileArchiveTab` | `LucideIcons.archive` |
| 3 | Settings | `MobileSettingsTab` | `LucideIcons.settings` |

Tab state: `mobileTabProvider` (`StateProvider<int>`, default 0) in `lib/src/ui/shell/mobile_nav.dart`.

### MobileNavBar
**File:** `lib/src/ui/mobile/mobile_nav_bar.dart`
Bottom bar (56px) with 4 `_NavTab` widgets. Badges:
- Chats tab: total unread count (DM + channel)
- Friends tab: pending incoming friend request count

---

## MobileChatRoute

**File:** `lib/src/ui/mobile/mobile_chat_route.dart`
**Class:** `MobileChatRoute extends ConsumerStatefulWidget`
**Purpose:** Shared chat view for both DM and channel conversations. Pushes onto root navigator (bottom nav disappears).

### Constructor
| Parameter | Type | Description |
|---|---|---|
| `peerId` | `String?` | Set for DM conversations |
| `serverId` | `String?` | Set for channel conversations |
| `channelId` | `String?` | Set for channel conversations |
| `channelName` | `String?` | Display name for channel header |

`isDm` getter: `peerId != null`.

### State Variables
- `_controller` / `_focusNode` — main text input
- `_scrollController` / `_positionsListener` — `ScrollablePositionedList` controllers
- `_replyToMessageId` / `_replyToText` / `_replyToSenderName` — reply state
- `_editingMessageId` — inline edit mode (message ID being edited)
- `_editController` / `_editFocusNode` — edit TextField controllers
- `_lastTypingSent` — 3s throttle for typing indicators
- `_isInAutoScrollZone` — auto-scroll on new messages
- `_stagedFilePath` / `_stagedFileName` / `_stagedFileIsImage` — staged file attachment
- `_isRecordingVoice` — swaps input bar for VoiceRecorderBar
- `_searchOpen` / `_searchController` / `_searchFocusNode` / `_searchResults` — channel search
- `_highlightIndex` — search result highlight (auto-clears after 1.5s)
- `_channelKey` — getter for `'$serverId:$channelId'` (channelChatProvider map key)

### Provider Management (Critical)
On entry: `_openDmChat` sets `selectedPeerProvider`, clears `selectedServerProvider`. `_openChannelChat` sets both `selectedServerProvider` and `selectedChannelProvider`.
On exit: `dispose()` clears these providers so the event provider doesn't treat the user as still viewing the chat.

### Widget Tree
```
Scaffold
├── SafeArea
│   └── Column
│       ├── _MobileChatHeader (back, name, status, search icon, mute bell)
│       ├── _buildSearchBar (channel only, when _searchOpen)
│       ├── Expanded → Stack
│       │   ├── ScrollablePositionedList.builder (initialScrollIndex: messages.length, initialAlignment: 1.0)
│       │   │   └── _LongPressMessage → MessageBubble / ChannelMessageBubble (isHighlighted for search)
│       │   └── Builder → unread pill (DM + channel, "N new messages")
│       ├── _TypingBar
│       ├── _ReplyPreview (if replying)
│       ├── StagedHollowLinkCard / StagedLinkPreviewCard (link preview)
│       ├── _StagedFilePreview (if file staged)
│       └── VoiceRecorderBar (if _isRecordingVoice) OR _MobileInputBar (paperclip + mic + text + send)
```

### Message Rendering
Uses `ScrollablePositionedList.builder` with sentinel pattern (`itemCount: messages.length + 1`).

**Grouping:** 5-minute window + sender change triggers `showHeader`.

**Reply context:** For each message with `replyToMid`, looks up the original in the message list and passes `replyToSenderName` + `replyToText` to the bubble.

**Edit mode:** When `_editingMessageId` matches a message, renders `_buildEditView()` instead of the bubble — an inline `TextField` with accent border + Save/Cancel buttons.

### _LongPressMessage Widget
Wraps each message bubble. Provides:
- `HitTestBehavior.opaque` — full-width tap target (not just painted content)
- Teal highlight animation during long-press hold (`AnimatedContainer` with `hollow.accent.withValues(alpha: 0.08)`)
- Triggers `showMobileMessageActions()` on long-press complete

### File Actions
- `_saveFile(FileAttachment)` — reads bytes, passes to `FilePicker.platform.saveFile(bytes:)`. Android requires `bytes:` param (crashes without it). Converts WebP→PNG if needed via `network_api.convertImageFormat()`.
- `_requestFileFromPeer(FileAttachment, senderId)` — requests file via P2P when not on disk.
- `_handleSend()` — if `_stagedFilePath` is set, sends as file attachment via `network_api.sendFile()`, otherwise sends text.

### Action Callbacks Wired
Both DM and channel builders wire:
- `onToggleReaction` on bubbles → reaction pills are tappable
- Long-press → `_showDmActions()` / `_showChannelActions()` → bottom sheet
- `onDownload` — shows when message has file attachment. Saves locally or requests from peer. Guards duplicate downloads via `fileTransferProvider`.

---

## Mobile Message Actions

**File:** `lib/src/ui/mobile/mobile_message_actions.dart`
**Function:** `showMobileMessageActions()` — `showModalBottomSheet` with contextual actions.

### Bottom Sheet Layout
```
Column (mainAxisSize: min)
├── Drag handle (32×4px)
├── _MessagePreview (sender name + truncated text + timestamp)
├── _QuickReactionsRow (top 6 emojis + "More..." button)
├── Divider
└── Action rows (HollowPressable, icon + label)
    ├── Reply (LucideIcons.reply)
    ├── Edit Message (LucideIcons.pencil) — own messages only, no file
    ├── Copy Text (LucideIcons.copy) — text messages only
    ├── Save File (LucideIcons.download) — file messages only
    ├── Message Info (LucideIcons.shieldCheck) — shows proof dialog
    └── Delete Message (LucideIcons.trash2, error color) — own messages only
```

### Three Views (AnimatedSize transitions)
1. **actions** — default view with action rows
2. **allEmojis** — full 30-emoji grid (6 columns), triggered by "More..." button. Back button returns to actions.
3. **deleteConfirm** — inline confirmation: warning icon + "Delete this message? This can't be undone." + Cancel/Delete buttons

### Parameters
All action callbacks are nullable — only shown when non-null:
- `onReply`, `onEdit`, `onDelete`, `onCopy`, `onDownload` — `VoidCallback?`
- `onReaction` — `void Function(String emoji)?`
- `onInfo` — `VoidCallback?`

Note: `onCopyImage` was removed — `super_clipboard` image operations don't work on Android. "Save File" covers the use case.

### Emoji Source
Imports `kReactionEmojis` from `lib/src/ui/chat/emoji_picker.dart` (30 curated emojis). Does NOT use the desktop's `showEmojiPicker()` overlay — embeds the grid directly in the sheet to avoid raw `OverlayEntry`.

---

## Widget Test Framework

**Files:**
- `test/helpers/test_app.dart` — `pumpHollowMobile()` + 20 mock notifiers
- `test/helpers/test_data.dart` — fake peer IDs, servers, channels, friends, unread state
- `test/helpers/mock_rust_lib.dart` — documentation only (mocking is at provider level)

### Key Pattern
All FFI-dependent providers are overridden with mock notifiers that return static test data. No native library loading needed. Tests run in ~1s.

`pumpHollowMobile(tester)` sets viewport to 400×800 and wraps `MobileShell` in `ProviderScope` with all overrides.

### Test Files
- `test/widget/mobile_shell_test.dart` — 7 tests (rendering, nav bar, tab switching)
- `test/widget/desktop_shell_test.dart` — 5 tests (responsive breakpoints, themes)
- `test/widget/mobile_nav_badge_test.dart` — 3 tests (unread badges, pending friends)
- `test/widget_test.dart` — 1 smoke test
