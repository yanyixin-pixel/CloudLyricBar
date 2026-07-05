# Pure Lyric Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make CloudLyricBar act as a menu bar lyric display tool that follows the Mac's currently playing NetEase Music track instead of playing audio itself.

**Architecture:** The app will add a `NowPlayingProviding` dependency to `CloudLyricBarViewModel`. The app target will implement that dependency with a MediaRemote-backed service that reads title, artist, playback state, and elapsed time from macOS. The core view model will resolve external now-playing songs to NetEase song IDs with the existing search API, cache that mapping, and fetch lyrics with the resolved ID.

**Tech Stack:** Swift 6, SwiftPM, AppKit menu bar app, existing NetEase API client, macOS private MediaRemote loaded dynamically with `dlopen`/`dlsym`.

---

### Task 1: Resolve External Now Playing Songs To NetEase Lyrics

**Files:**
- Modify: `Sources/CloudLyricBarCore/App/CloudLyricBarViewModel.swift`
- Modify: `Tests/CloudLyricBarCoreTests/CloudLyricBarViewModelTests.swift`

- [ ] **Step 1: Write failing test**
Add a test named `testExternalNowPlayingSongSearchesNetEaseAndUsesResolvedLyrics`. It creates an external song `Song(id: "external:netease", title: "一路向北", artist: "周杰伦")`, a fake API search result `Song(id: "1901371647", title: "一路向北", artist: "周杰伦")`, and lyric lines. It calls `apply(nowPlaying:isClientRunning:)` with position `8` and expects the API to search once, fetch lyrics for `1901371647`, and show the lyric at 8 seconds.

- [ ] **Step 2: Run test to verify failure**
Run: `swift run CloudLyricBarCoreTests --filter CloudLyricBarViewModelTests.testExternalNowPlayingSongSearchesNetEaseAndUsesResolvedLyrics`
Expected: compile or test failure because the view model does not resolve external songs.

- [ ] **Step 3: Implement minimal resolver**
Add a private mapping cache in `CloudLyricBarViewModel`. When a song ID starts with `external:`, search NetEase using `"title artist"`, pick the first result, cache it, and use that song's ID for lyric fetching and display.

- [ ] **Step 4: Run focused test**
Run: `swift run CloudLyricBarCoreTests --filter CloudLyricBarViewModelTests.testExternalNowPlayingSongSearchesNetEaseAndUsesResolvedLyrics`
Expected: PASS.

### Task 2: Make Refresh Follow A NowPlayingProvider

**Files:**
- Modify: `Sources/CloudLyricBarCore/App/CloudLyricBarViewModel.swift`
- Modify: `Tests/CloudLyricBarCoreTests/CloudLyricBarViewModelTests.swift`

- [ ] **Step 1: Write failing test**
Add a test named `testRefreshUsesNowPlayingProviderWhenAvailable`. It injects a fake provider returning `NowPlayingSnapshot(song: externalSong, playback: .playing, position: 8)`, then calls `refreshEstimatedPlayback()` and expects the matching lyric to display.

- [ ] **Step 2: Run test to verify failure**
Run: `swift run CloudLyricBarCoreTests --filter CloudLyricBarViewModelTests.testRefreshUsesNowPlayingProviderWhenAvailable`
Expected: compile or test failure because the view model does not accept a provider.

- [ ] **Step 3: Implement provider dependency**
Add `nowPlayingProvider: (any NowPlayingProviding)?` to `CloudLyricBarViewModel`. In `refreshEstimatedPlayback`, prefer this provider, then audio player, then timer estimate.

- [ ] **Step 4: Run focused test**
Run: `swift run CloudLyricBarCoreTests --filter CloudLyricBarViewModelTests.testRefreshUsesNowPlayingProviderWhenAvailable`
Expected: PASS.

### Task 3: Add MediaRemote Now Playing Provider

**Files:**
- Create: `Sources/CloudLyricBarApp/MediaRemoteNowPlayingService.swift`
- Modify: `Sources/CloudLyricBarApp/AppDelegate.swift`

- [ ] **Step 1: Implement dynamic MediaRemote reader**
Create an app-layer actor/class that implements `NowPlayingProviding`. It uses `dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)` and `dlsym` for `MRMediaRemoteGetNowPlayingInfo`. It converts title, artist, elapsed time, and playback rate fields from the returned dictionary into `NowPlayingSnapshot`. It gives external songs IDs like `external:mediaremote:<title>:<artist>`.

- [ ] **Step 2: Wire provider into AppDelegate**
Instantiate `MediaRemoteNowPlayingService()` and pass it as `nowPlayingProvider`. Stop passing `AVFoundationSongAudioPlayer` as the default player so CloudLyricBar does not play audio itself.

- [ ] **Step 3: Build app**
Run: `swift build`
Expected: build succeeds.

### Task 4: Turn Search Result Click Into Manual Lyric Override

**Files:**
- Modify: `Sources/CloudLyricBarCore/App/CloudLyricBarViewModel.swift`
- Modify: `Tests/CloudLyricBarCoreTests/CloudLyricBarViewModelTests.swift`

- [ ] **Step 1: Write failing test**
Add a test named `testSelectingSongUsesItAsLyricOverrideWithoutStartingPlayback`. It injects a fake playback control and no audio player, calls `play(song)`, and expects no playback command, `currentSong == song`, and lyric display from that song.

- [ ] **Step 2: Run test to verify failure**
Run: `swift run CloudLyricBarCoreTests --filter CloudLyricBarViewModelTests.testSelectingSongUsesItAsLyricOverrideWithoutStartingPlayback`
Expected: failure because current behavior sends `.openSong`.

- [ ] **Step 3: Implement manual lyric override behavior**
Change `play(_:)` so when no audio player exists, it applies the selected song as a lyric source at the latest known playback position rather than sending `.openSong`.

- [ ] **Step 4: Run focused test**
Run: `swift run CloudLyricBarCoreTests --filter CloudLyricBarViewModelTests.testSelectingSongUsesItAsLyricOverrideWithoutStartingPlayback`
Expected: PASS.

### Task 5: Verify And Commit

**Files:**
- All changed files

- [ ] **Step 1: Run full core tests**
Run: `swift run CloudLyricBarCoreTests`
Expected: all tests pass.

- [ ] **Step 2: Build app**
Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Smoke-start app**
Run: `swift run CloudLyricBarApp`, keep it alive for 3 seconds, then terminate it.
Expected: process starts successfully.

- [ ] **Step 4: Commit**
Run: `git add ... && git commit -m "feat: follow system now playing lyrics"`
Expected: commit succeeds.
