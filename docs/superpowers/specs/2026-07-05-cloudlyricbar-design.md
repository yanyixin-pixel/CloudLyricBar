# CloudLyricBar Design

Date: 2026-07-05

## Goal

Build a native macOS menu bar companion app for NetEase Cloud Music. The NetEase Cloud Music Mac client remains responsible for audio playback. CloudLyricBar shows the current synced lyric line in the macOS menu bar and opens a compact native panel for playback controls, playlist browsing, and search.

## Product Scope

CloudLyricBar is a lightweight companion tool, not a standalone music player.

In scope for the first version:

- Show the current timed lyric line in the right-side macOS menu bar.
- Horizontally scroll long lyric lines inside a fixed-width menu bar area.
- Reset lyric scrolling when the lyric line changes.
- Open a native popover panel when the user clicks the menu bar lyric.
- Show current song metadata, album artwork, playback controls, current lyric context, search, playlists, and settings in the popover.
- Authenticate to NetEase Cloud Music with QR-code login.
- Read the user's NetEase Cloud Music playlists after login.
- Search NetEase Cloud Music by song, artist, or album keyword.
- Let the user choose a song from search results or playlists and hand playback to the official NetEase Cloud Music client.
- Handle not logged in, client not running, no timed lyrics, playback unavailable, and permission-denied states gracefully.

Out of scope for the first version:

- Playing audio directly inside CloudLyricBar.
- Desktop floating lyric window mode.
- Audio spectrum, particles, or complex music visualization.
- iCloud sync or multi-device sync.
- App Store distribution.

## Architecture

The app uses a native Swift and SwiftUI/AppKit macOS architecture.

### Components

- `StatusBarController`: owns the menu bar status item, lyric label, click handling, width constraints, and marquee behavior for long lyric lines.
- `PopoverController`: owns the native popover anchored to the status item.
- `NowPlayingService`: observes or estimates current song identity, playback state, and playback position.
- `NetEaseAuthService`: manages QR-code login and stores session data in macOS Keychain.
- `NetEaseAPIClient`: reads playlists, search results, song metadata, and timed lyrics from NetEase Cloud Music endpoints.
- `LyricSyncEngine`: parses timed lyrics, tracks the active line, and emits menu bar and popover lyric updates.
- `PlaybackControlService`: sends play, pause, previous, next, and open-song commands to the NetEase Cloud Music client.
- `PermissionCoordinator`: requests and explains optional macOS permissions only when they become necessary.
- `CacheStore`: caches playlists, search results, artwork, and lyric responses to reduce repeated network calls.

### External Dependencies

- macOS AppKit status item APIs for right-side menu bar integration.
- AppKit popover APIs for the click-to-expand panel.
- macOS media controls or automation mechanisms for playback control.
- NetEase Cloud Music QR login and content endpoints. These are likely to rely on community-documented or reverse-engineered API behavior, so the implementation must isolate this layer behind `NetEaseAPIClient`.

References:

- Apple `NSStatusItem`: https://developer.apple.com/documentation/AppKit/NSStatusItem
- Apple `NSPopover`: https://developer.apple.com/documentation/AppKit/NSPopover
- Apple menu bar HIG: https://developer.apple.com/design/human-interface-guidelines/the-menu-bar
- Community NetEase API documentation: https://binaryify.github.io/NeteaseCloudMusicApi/

## User Experience

### Menu Bar

The menu bar item displays a compact lyric string such as:

`♪ 正在唱到这一句歌词`

Behavior:

- Short lyric lines render fully.
- Long lyric lines scroll horizontally inside a configurable fixed width.
- Scrolling pauses when the user hovers over the menu bar item or opens the popover.
- The scroll position resets at the start of each new lyric line.
- If menu bar space is too constrained, the app degrades to truncation or a compact music icon to avoid crowding system icons.
- When nothing is playing, the app shows a compact idle state.

### Popover

Clicking the menu bar lyric opens a native popover below the status item.

Popover content:

- Current song title, artist, and album artwork.
- Previous, play/pause, and next controls.
- Current lyric line with previous and next lyric context.
- Search box for NetEase Cloud Music.
- Playlist list and song list views.
- Login status, refresh action, and permission settings.

The popover should feel like a system control panel: compact, fast, and scannable. It should avoid large decorative layouts.

## Playback Control Strategy

CloudLyricBar tries control paths in this order:

1. Use macOS media controls for play/pause, previous, and next when available.
2. Use NetEase Cloud Music deep links or URLs to open a selected song or playlist in the official client when available.
3. Use targeted accessibility automation only when media controls and deep links are insufficient.

The app should not request Accessibility or Automation permissions on first launch unless required. It should explain why a permission is needed at the moment the user tries a feature that needs it.

If the NetEase Cloud Music client is not running, the popover shows an action to open it. If a song cannot be played due to copyright, membership, region, or client limitations, the UI shows a clear failure state.

## Lyrics Sync

The first version targets line-by-line timed lyric sync.

Flow:

1. Detect the current song from system now-playing state or from the NetEase client when necessary.
2. Fetch timed lyrics for that song through `NetEaseAPIClient`.
3. Track the current playback position.
4. Use `LyricSyncEngine` to select the active lyric line.
5. Publish updates to the menu bar and popover.

Position strategy:

- Prefer precise playback position from system now-playing data if accessible.
- Fall back to a local timer estimate when precise progress is unavailable.
- Recalibrate on play, pause, seek, and song change events.
- If timed lyrics are unavailable, the popover states that synced lyrics are unavailable and the menu bar falls back to song title or icon.

## Login, Playlists, and Search

Authentication uses QR-code login. CloudLyricBar does not store the user's password.

Session behavior:

- Store session/cookie data in macOS Keychain.
- Reuse the session across app launches.
- Prompt for re-login when the session expires.

Playlist and search behavior:

- Load the user's playlist list after login.
- Load songs for a playlist on demand.
- Search songs, artists, and albums by keyword.
- Cache playlist and lyric data with a refresh option.
- Selecting a result attempts to open/play it in the NetEase Cloud Music client.

## Error Handling

The app must handle these states explicitly:

- NetEase Cloud Music client is not installed or not running.
- User is not logged in.
- QR login expires or fails.
- Network request fails.
- NetEase API response changes or becomes unavailable.
- Song has no timed lyrics.
- Song cannot be played in the official client.
- Required permission is denied.
- macOS menu bar has insufficient width.

Each state should show a short, direct message in the popover and keep the menu bar item stable.

## Testing Plan

Manual verification:

- Launch app with and without NetEase Cloud Music running.
- Display lyric in the menu bar during playback.
- Verify long lyric marquee behavior and reset on line change.
- Open and close the popover from the menu bar item.
- Use play/pause, previous, and next controls.
- Complete QR login and reload after app restart.
- Browse playlists and select a song.
- Search for songs and select a result.
- Verify behavior when timed lyrics are missing.
- Verify behavior when permissions are denied.

Automated tests:

- Unit-test timed lyric parsing and active-line selection.
- Unit-test marquee state transitions for short, long, and line-change cases.
- Unit-test API client decoding against saved fixture responses.
- Unit-test session expiration and error-state mapping.

## Open Risks

- NetEase Cloud Music does not provide a broadly stable public consumer playback API for this use case, so the API integration must be isolated and replaceable.
- The official Mac client may not expose reliable deep links for direct song playback; fallback automation may be needed.
- macOS now-playing access may not provide all required playback details for third-party media clients; local timer fallback is required.
- Menu bar width varies with screen size, notch layout, and other menu extras, so the lyric display must degrade gracefully.
