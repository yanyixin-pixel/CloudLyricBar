# CloudLyricBar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working native macOS menu bar companion for NetEase Cloud Music with synced menu bar lyrics, a popover control panel, QR login, playlists, search, and client playback handoff.

**Architecture:** Use Swift Package Manager with a testable `CloudLyricBarCore` library and a `CloudLyricBarApp` executable. Keep network, playback control, lyric sync, menu bar UI, and popover view model in separate files with protocol boundaries so NetEase API and macOS client-control fragility stay isolated.

**Tech Stack:** Swift 6.3, SwiftPM, XCTest, Foundation, SwiftUI, AppKit, Security framework for Keychain, URLSession for API calls.

---

## File Structure

- `Package.swift`: SwiftPM package with `CloudLyricBarCore`, `CloudLyricBarApp`, and `CloudLyricBarCoreTests`.
- `Sources/CloudLyricBarCore/Domain/PlaybackModels.swift`: shared domain models for songs, playlists, lyrics, playback state, and user-facing app state.
- `Sources/CloudLyricBarCore/Lyrics/LyricParser.swift`: parses LRC-style timed lyric text.
- `Sources/CloudLyricBarCore/Lyrics/LyricSyncEngine.swift`: chooses active, previous, and next lyric lines from playback time.
- `Sources/CloudLyricBarCore/MenuBar/MarqueeTextEngine.swift`: pure logic for long lyric scrolling.
- `Sources/CloudLyricBarCore/NetEase/NetEaseDTO.swift`: decodable API response shapes.
- `Sources/CloudLyricBarCore/NetEase/NetEaseAPIClient.swift`: NetEase request protocol and URLSession implementation.
- `Sources/CloudLyricBarCore/Auth/SessionStore.swift`: protocol, in-memory store for tests, and Keychain-backed store.
- `Sources/CloudLyricBarCore/Auth/NetEaseAuthService.swift`: QR login polling and session state.
- `Sources/CloudLyricBarCore/Auth/NetEaseQRLoginProvider.swift`: real QR login key/create/check flow against a NetEase API-compatible service.
- `Sources/CloudLyricBarCore/Playback/PlaybackControlService.swift`: layered playback control strategies.
- `Sources/CloudLyricBarCore/Permissions/PermissionCoordinator.swift`: permission state model.
- `Sources/CloudLyricBarCore/NowPlaying/NowPlayingService.swift`: now-playing snapshot protocol and timer fallback.
- `Sources/CloudLyricBarCore/App/CloudLyricBarViewModel.swift`: observable app state for menu bar and popover.
- `Sources/CloudLyricBarApp/main.swift`: executable app entry point.
- `Sources/CloudLyricBarApp/AppDelegate.swift`: AppKit application lifecycle.
- `Sources/CloudLyricBarApp/StatusBarController.swift`: `NSStatusItem` and popover anchoring.
- `Sources/CloudLyricBarApp/PopoverController.swift`: `NSPopover` host.
- `Sources/CloudLyricBarApp/Views/PopoverView.swift`: SwiftUI popover UI.
- `Sources/CloudLyricBarApp/Views/LoginView.swift`: QR login state UI.
- `Sources/CloudLyricBarApp/Views/LibraryView.swift`: playlists and search UI.
- `Tests/CloudLyricBarCoreTests/*`: unit tests for core behavior.
- `Tests/CloudLyricBarCoreTests/Fixtures/*.json`: saved response fixtures.

## Task 1: SwiftPM Skeleton and Domain Models

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Package.swift`
- Create: `/Users/danhyolk/CloudLyricBar/.gitignore`
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Domain/PlaybackModels.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/PlaybackModelsTests.swift`

- [ ] **Step 1: Create the package manifest**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CloudLyricBar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CloudLyricBarCore", targets: ["CloudLyricBarCore"]),
        .executable(name: "CloudLyricBarApp", targets: ["CloudLyricBarApp"])
    ],
    targets: [
        .target(
            name: "CloudLyricBarCore",
            dependencies: []
        ),
        .executableTarget(
            name: "CloudLyricBarApp",
            dependencies: ["CloudLyricBarCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "CloudLyricBarCoreTests",
            dependencies: ["CloudLyricBarCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
```

- [ ] **Step 2: Add ignore rules**

```gitignore
# .gitignore
.build/
.swiftpm/
.DS_Store
DerivedData/
*.xcuserstate
.superpowers/
```

- [ ] **Step 3: Write the failing domain model tests**

```swift
// Tests/CloudLyricBarCoreTests/PlaybackModelsTests.swift
import XCTest
@testable import CloudLyricBarCore

final class PlaybackModelsTests: XCTestCase {
    func testMenuBarTitleUsesLyricWhenPlaying() {
        let state = MenuBarDisplayState(
            playback: .playing,
            lyricText: "在云端轻轻唱",
            fallbackTitle: "晴天",
            isClientRunning: true
        )

        XCTAssertEqual(state.title, "♪ 在云端轻轻唱")
        XCTAssertTrue(state.shouldAnimate)
    }

    func testMenuBarTitleFallsBackToSongTitleWhenLyricMissing() {
        let state = MenuBarDisplayState(
            playback: .playing,
            lyricText: nil,
            fallbackTitle: "晴天",
            isClientRunning: true
        )

        XCTAssertEqual(state.title, "♪ 晴天")
        XCTAssertFalse(state.shouldAnimate)
    }

    func testMenuBarTitleShowsIdleWhenClientIsClosed() {
        let state = MenuBarDisplayState(
            playback: .stopped,
            lyricText: nil,
            fallbackTitle: nil,
            isClientRunning: false
        )

        XCTAssertEqual(state.title, "♪")
        XCTAssertFalse(state.shouldAnimate)
    }
}
```

- [ ] **Step 4: Run the test and verify it fails**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter PlaybackModelsTests
```

Expected: compilation fails because `MenuBarDisplayState` and `PlaybackState` are not defined.

- [ ] **Step 5: Implement the domain models**

```swift
// Sources/CloudLyricBarCore/Domain/PlaybackModels.swift
import Foundation

public enum PlaybackState: Equatable, Sendable {
    case playing
    case paused
    case stopped
}

public struct Song: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let artworkURL: URL?

    public init(id: String, title: String, artist: String, album: String? = nil, artworkURL: URL? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
    }
}

public struct Playlist: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let trackCount: Int

    public init(id: String, name: String, trackCount: Int) {
        self.id = id
        self.name = name
        self.trackCount = trackCount
    }
}

public struct LyricLine: Equatable, Identifiable, Sendable {
    public var id: TimeInterval { startTime }
    public let startTime: TimeInterval
    public let text: String

    public init(startTime: TimeInterval, text: String) {
        self.startTime = startTime
        self.text = text
    }
}

public struct LyricContext: Equatable, Sendable {
    public let previous: LyricLine?
    public let current: LyricLine?
    public let next: LyricLine?

    public init(previous: LyricLine?, current: LyricLine?, next: LyricLine?) {
        self.previous = previous
        self.current = current
        self.next = next
    }
}

public struct NowPlayingSnapshot: Equatable, Sendable {
    public let song: Song?
    public let playback: PlaybackState
    public let position: TimeInterval?
    public let capturedAt: Date

    public init(song: Song?, playback: PlaybackState, position: TimeInterval?, capturedAt: Date = Date()) {
        self.song = song
        self.playback = playback
        self.position = position
        self.capturedAt = capturedAt
    }
}

public struct MenuBarDisplayState: Equatable, Sendable {
    public let playback: PlaybackState
    public let lyricText: String?
    public let fallbackTitle: String?
    public let isClientRunning: Bool

    public init(playback: PlaybackState, lyricText: String?, fallbackTitle: String?, isClientRunning: Bool) {
        self.playback = playback
        self.lyricText = lyricText
        self.fallbackTitle = fallbackTitle
        self.isClientRunning = isClientRunning
    }

    public var title: String {
        guard isClientRunning else { return "♪" }

        if playback == .playing, let lyricText, !lyricText.isEmpty {
            return "♪ \(lyricText)"
        }

        if let fallbackTitle, !fallbackTitle.isEmpty {
            return "♪ \(fallbackTitle)"
        }

        return "♪"
    }

    public var shouldAnimate: Bool {
        playback == .playing && lyricText != nil
    }
}
```

- [ ] **Step 6: Run the test and verify it passes**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter PlaybackModelsTests
```

Expected: all `PlaybackModelsTests` pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Package.swift .gitignore Sources/CloudLyricBarCore/Domain/PlaybackModels.swift Tests/CloudLyricBarCoreTests/PlaybackModelsTests.swift
git commit -m "chore: scaffold Swift package and domain models"
```

## Task 2: Timed Lyrics Parsing and Sync

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Lyrics/LyricParser.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Lyrics/LyricSyncEngine.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/LyricParserTests.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/LyricSyncEngineTests.swift`

- [ ] **Step 1: Write failing parser tests**

```swift
// Tests/CloudLyricBarCoreTests/LyricParserTests.swift
import XCTest
@testable import CloudLyricBarCore

final class LyricParserTests: XCTestCase {
    func testParsesLrcLinesAndSortsByTime() {
        let raw = """
        [00:12.50]第一句歌词
        [00:05.00]开头一句
        [01:02.03]一分钟后的歌词
        """

        let lines = LyricParser.parse(raw)

        XCTAssertEqual(lines, [
            LyricLine(startTime: 5.0, text: "开头一句"),
            LyricLine(startTime: 12.5, text: "第一句歌词"),
            LyricLine(startTime: 62.03, text: "一分钟后的歌词")
        ])
    }

    func testSkipsMetadataAndBlankLyricLines() {
        let raw = """
        [ar:Artist]
        [ti:Title]
        [00:01.00]
        [00:02.00]有效歌词
        """

        XCTAssertEqual(LyricParser.parse(raw), [
            LyricLine(startTime: 2.0, text: "有效歌词")
        ])
    }
}
```

- [ ] **Step 2: Write failing sync tests**

```swift
// Tests/CloudLyricBarCoreTests/LyricSyncEngineTests.swift
import XCTest
@testable import CloudLyricBarCore

final class LyricSyncEngineTests: XCTestCase {
    private let lines = [
        LyricLine(startTime: 0, text: "前奏"),
        LyricLine(startTime: 8.5, text: "第一句"),
        LyricLine(startTime: 16, text: "第二句")
    ]

    func testReturnsCurrentPreviousAndNextLine() {
        let context = LyricSyncEngine.context(at: 9.0, in: lines)

        XCTAssertEqual(context.previous?.text, "前奏")
        XCTAssertEqual(context.current?.text, "第一句")
        XCTAssertEqual(context.next?.text, "第二句")
    }

    func testBeforeFirstLineReturnsFirstAsNext() {
        let context = LyricSyncEngine.context(at: -1, in: lines)

        XCTAssertNil(context.previous)
        XCTAssertNil(context.current)
        XCTAssertEqual(context.next?.text, "前奏")
    }
}
```

- [ ] **Step 3: Run the tests and verify they fail**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter Lyric
```

Expected: compilation fails because `LyricParser` and `LyricSyncEngine` are not defined.

- [ ] **Step 4: Implement parser**

```swift
// Sources/CloudLyricBarCore/Lyrics/LyricParser.swift
import Foundation

public enum LyricParser {
    public static func parse(_ raw: String) -> [LyricLine] {
        raw
            .split(whereSeparator: \.isNewline)
            .compactMap(parseLine)
            .sorted { $0.startTime < $1.startTime }
    }

    private static func parseLine(_ line: Substring) -> LyricLine? {
        guard line.first == "[", let close = line.firstIndex(of: "]") else { return nil }

        let tag = line[line.index(after: line.startIndex)..<close]
        let textStart = line.index(after: close)
        let text = String(line[textStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let seconds = parseTimestamp(String(tag)) else { return nil }

        return LyricLine(startTime: seconds, text: text)
    }

    private static func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        let parts = timestamp.split(separator: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1])
        else {
            return nil
        }

        return minutes * 60 + seconds
    }
}
```

- [ ] **Step 5: Implement sync engine**

```swift
// Sources/CloudLyricBarCore/Lyrics/LyricSyncEngine.swift
import Foundation

public enum LyricSyncEngine {
    public static func context(at position: TimeInterval, in lines: [LyricLine]) -> LyricContext {
        guard !lines.isEmpty else {
            return LyricContext(previous: nil, current: nil, next: nil)
        }

        let currentIndex = lines.lastIndex { $0.startTime <= position }

        guard let currentIndex else {
            return LyricContext(previous: nil, current: nil, next: lines.first)
        }

        let previous = currentIndex > 0 ? lines[currentIndex - 1] : nil
        let current = lines[currentIndex]
        let next = currentIndex + 1 < lines.count ? lines[currentIndex + 1] : nil
        return LyricContext(previous: previous, current: current, next: next)
    }
}
```

- [ ] **Step 6: Run tests and verify they pass**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter Lyric
```

Expected: parser and sync tests pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/Lyrics Tests/CloudLyricBarCoreTests/LyricParserTests.swift Tests/CloudLyricBarCoreTests/LyricSyncEngineTests.swift
git commit -m "feat: add timed lyric parsing and sync"
```

## Task 3: Menu Bar Marquee Logic

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/MenuBar/MarqueeTextEngine.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/MarqueeTextEngineTests.swift`

- [ ] **Step 1: Write failing marquee tests**

```swift
// Tests/CloudLyricBarCoreTests/MarqueeTextEngineTests.swift
import XCTest
@testable import CloudLyricBarCore

final class MarqueeTextEngineTests: XCTestCase {
    func testShortTextDoesNotScroll() {
        let frame = MarqueeTextEngine.frame(text: "短歌词", visibleCharacterCount: 8, tick: 4)

        XCTAssertEqual(frame.text, "短歌词")
        XCTAssertFalse(frame.isScrolling)
    }

    func testLongTextScrollsByTick() {
        let frame = MarqueeTextEngine.frame(text: "abcdefghijklmnopqrstuvwxyz", visibleCharacterCount: 6, tick: 2)

        XCTAssertEqual(frame.text, "cdefgh")
        XCTAssertTrue(frame.isScrolling)
    }

    func testLongTextWrapsWithSpacer() {
        let frame = MarqueeTextEngine.frame(text: "abcdef", visibleCharacterCount: 4, tick: 7)

        XCTAssertEqual(frame.text.count, 4)
        XCTAssertTrue(frame.isScrolling)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter MarqueeTextEngineTests
```

Expected: compilation fails because `MarqueeTextEngine` is not defined.

- [ ] **Step 3: Implement the marquee engine**

```swift
// Sources/CloudLyricBarCore/MenuBar/MarqueeTextEngine.swift
import Foundation

public struct MarqueeFrame: Equatable, Sendable {
    public let text: String
    public let isScrolling: Bool
}

public enum MarqueeTextEngine {
    public static func frame(text: String, visibleCharacterCount: Int, tick: Int) -> MarqueeFrame {
        guard visibleCharacterCount > 0 else {
            return MarqueeFrame(text: "", isScrolling: false)
        }

        let characters = Array(text)
        guard characters.count > visibleCharacterCount else {
            return MarqueeFrame(text: text, isScrolling: false)
        }

        let loop = Array(text + "   ")
        let start = tick % loop.count
        let visible = (0..<visibleCharacterCount).map { loop[(start + $0) % loop.count] }
        return MarqueeFrame(text: String(visible), isScrolling: true)
    }
}
```

- [ ] **Step 4: Run the test and verify it passes**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter MarqueeTextEngineTests
```

Expected: all marquee tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/MenuBar/MarqueeTextEngine.swift Tests/CloudLyricBarCoreTests/MarqueeTextEngineTests.swift
git commit -m "feat: add menu bar lyric marquee logic"
```

## Task 4: NetEase API Response Decoding

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/NetEase/NetEaseDTO.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/Fixtures/playlist.json`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/Fixtures/search.json`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/Fixtures/lyric.json`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/NetEaseDTOTests.swift`

- [ ] **Step 1: Add response fixtures**

```json
// Tests/CloudLyricBarCoreTests/Fixtures/playlist.json
{
  "code": 200,
  "playlist": [
    { "id": 123, "name": "我喜欢的音乐", "trackCount": 88 },
    { "id": 456, "name": "夜晚播放", "trackCount": 24 }
  ]
}
```

```json
// Tests/CloudLyricBarCoreTests/Fixtures/search.json
{
  "code": 200,
  "result": {
    "songs": [
      {
        "id": 1901371647,
        "name": "一路向北",
        "artists": [{ "name": "周杰伦" }],
        "album": {
          "name": "十一月的萧邦",
          "picUrl": "https://p1.music.126.net/artwork.jpg"
        }
      }
    ]
  }
}
```

```json
// Tests/CloudLyricBarCoreTests/Fixtures/lyric.json
{
  "code": 200,
  "lrc": {
    "lyric": "[00:01.00]第一句歌词\n[00:03.50]第二句歌词"
  }
}
```

- [ ] **Step 2: Write failing DTO tests**

```swift
// Tests/CloudLyricBarCoreTests/NetEaseDTOTests.swift
import XCTest
@testable import CloudLyricBarCore

final class NetEaseDTOTests: XCTestCase {
    func testDecodesPlaylistResponse() throws {
        let response: NetEasePlaylistResponse = try decodeFixture("playlist")

        XCTAssertEqual(response.playlists.map(\.domain), [
            Playlist(id: "123", name: "我喜欢的音乐", trackCount: 88),
            Playlist(id: "456", name: "夜晚播放", trackCount: 24)
        ])
    }

    func testDecodesSearchResponse() throws {
        let response: NetEaseSearchResponse = try decodeFixture("search")

        XCTAssertEqual(response.songs.map(\.domain), [
            Song(
                id: "1901371647",
                title: "一路向北",
                artist: "周杰伦",
                album: "十一月的萧邦",
                artworkURL: URL(string: "https://p1.music.126.net/artwork.jpg")
            )
        ])
    }

    func testDecodesTimedLyrics() throws {
        let response: NetEaseLyricResponse = try decodeFixture("lyric")

        XCTAssertEqual(response.lines, [
            LyricLine(startTime: 1.0, text: "第一句歌词"),
            LyricLine(startTime: 3.5, text: "第二句歌词")
        ])
    }

    private func decodeFixture<T: Decodable>(_ name: String) throws -> T {
        let url = Bundle.module.url(forResource: name, withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

- [ ] **Step 3: Run the tests and verify they fail**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NetEaseDTOTests
```

Expected: compilation fails because NetEase response types are not defined.

- [ ] **Step 4: Implement DTOs**

```swift
// Sources/CloudLyricBarCore/NetEase/NetEaseDTO.swift
import Foundation

public struct NetEasePlaylistResponse: Decodable, Sendable {
    public let code: Int
    public let playlists: [NetEasePlaylist]

    private enum CodingKeys: String, CodingKey {
        case code
        case playlists = "playlist"
    }
}

public struct NetEasePlaylist: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let trackCount: Int

    public var domain: Playlist {
        Playlist(id: String(id), name: name, trackCount: trackCount)
    }
}

public struct NetEaseSearchResponse: Decodable, Sendable {
    public let code: Int
    public let result: Result

    public var songs: [NetEaseSong] { result.songs }

    public struct Result: Decodable, Sendable {
        public let songs: [NetEaseSong]
    }
}

public struct NetEaseSong: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let artists: [Artist]
    public let album: Album?

    public struct Artist: Decodable, Sendable {
        public let name: String
    }

    public struct Album: Decodable, Sendable {
        public let name: String
        public let picUrl: URL?
    }

    public var domain: Song {
        Song(
            id: String(id),
            title: name,
            artist: artists.map(\.name).joined(separator: ", "),
            album: album?.name,
            artworkURL: album?.picUrl
        )
    }
}

public struct NetEaseLyricResponse: Decodable, Sendable {
    public let code: Int
    public let lrc: LRC?

    public struct LRC: Decodable, Sendable {
        public let lyric: String
    }

    public var lines: [LyricLine] {
        LyricParser.parse(lrc?.lyric ?? "")
    }
}
```

- [ ] **Step 5: Run the tests and verify they pass**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NetEaseDTOTests
```

Expected: NetEase DTO decoding tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/NetEase/NetEaseDTO.swift Tests/CloudLyricBarCoreTests/Fixtures Tests/CloudLyricBarCoreTests/NetEaseDTOTests.swift
git commit -m "feat: decode NetEase API responses"
```

## Task 5: API Client Protocol and URLSession Implementation

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/NetEase/NetEaseAPIClient.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/NetEaseAPIClientTests.swift`

- [ ] **Step 1: Write failing API client tests with a fake transport**

```swift
// Tests/CloudLyricBarCoreTests/NetEaseAPIClientTests.swift
import XCTest
@testable import CloudLyricBarCore

final class NetEaseAPIClientTests: XCTestCase {
    func testSearchBuildsExpectedRequestAndDecodesSongs() async throws {
        let transport = FakeHTTPTransport(data: fixtureData("search"))
        let client = URLSessionNetEaseAPIClient(baseURL: URL(string: "https://music.example")!, transport: transport)

        let songs = try await client.searchSongs(keyword: "一路向北")

        XCTAssertEqual(transport.lastRequest?.url?.path, "/search")
        XCTAssertEqual(transport.lastRequest?.url?.query?.contains("keywords=%E4%B8%80%E8%B7%AF%E5%90%91%E5%8C%97"), true)
        XCTAssertEqual(songs.first?.title, "一路向北")
    }

    func testFetchLyricsDecodesLines() async throws {
        let transport = FakeHTTPTransport(data: fixtureData("lyric"))
        let client = URLSessionNetEaseAPIClient(baseURL: URL(string: "https://music.example")!, transport: transport)

        let lines = try await client.fetchLyrics(songID: "1901371647")

        XCTAssertEqual(transport.lastRequest?.url?.path, "/lyric")
        XCTAssertEqual(lines.map(\.text), ["第一句歌词", "第二句歌词"])
    }

    private func fixtureData(_ name: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }
}

final class FakeHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let data: Data
    private(set) var lastRequest: URLRequest?

    init(data: Data) {
        self.data = data
    }

    func data(for request: URLRequest) async throws -> Data {
        lastRequest = request
        return data
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NetEaseAPIClientTests
```

Expected: compilation fails because `HTTPTransport`, `NetEaseAPIClient`, and `URLSessionNetEaseAPIClient` are not defined.

- [ ] **Step 3: Implement the client protocol and URLSession transport**

```swift
// Sources/CloudLyricBarCore/NetEase/NetEaseAPIClient.swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> Data
}

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NetEaseAPIError.badStatus(http.statusCode)
        }
        return data
    }
}

public protocol NetEaseAPIClient: Sendable {
    func userPlaylists(userID: String) async throws -> [Playlist]
    func searchSongs(keyword: String) async throws -> [Song]
    func fetchLyrics(songID: String) async throws -> [LyricLine]
}

public enum NetEaseAPIError: Error, Equatable {
    case invalidURL
    case badStatus(Int)
}

public struct URLSessionNetEaseAPIClient: NetEaseAPIClient {
    private let baseURL: URL
    private let transport: HTTPTransport
    private let decoder = JSONDecoder()

    public init(baseURL: URL, transport: HTTPTransport = URLSessionHTTPTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func userPlaylists(userID: String) async throws -> [Playlist] {
        let data = try await transport.data(for: request(path: "/user/playlist", query: ["uid": userID]))
        return try decoder.decode(NetEasePlaylistResponse.self, from: data).playlists.map(\.domain)
    }

    public func searchSongs(keyword: String) async throws -> [Song] {
        let data = try await transport.data(for: request(path: "/search", query: ["keywords": keyword, "type": "1"]))
        return try decoder.decode(NetEaseSearchResponse.self, from: data).songs.map(\.domain)
    }

    public func fetchLyrics(songID: String) async throws -> [LyricLine] {
        let data = try await transport.data(for: request(path: "/lyric", query: ["id": songID]))
        return try decoder.decode(NetEaseLyricResponse.self, from: data).lines
    }

    private func request(path: String, query: [String: String]) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw NetEaseAPIError.invalidURL
        }

        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else {
            throw NetEaseAPIError.invalidURL
        }

        return URLRequest(url: url)
    }
}
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NetEaseAPIClientTests
```

Expected: API client tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/NetEase/NetEaseAPIClient.swift Tests/CloudLyricBarCoreTests/NetEaseAPIClientTests.swift
git commit -m "feat: add NetEase API client boundary"
```

## Task 6: Session Store and QR Login State

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Auth/SessionStore.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Auth/NetEaseAuthService.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/NetEaseAuthServiceTests.swift`

- [ ] **Step 1: Write failing auth tests**

```swift
// Tests/CloudLyricBarCoreTests/NetEaseAuthServiceTests.swift
import XCTest
@testable import CloudLyricBarCore

final class NetEaseAuthServiceTests: XCTestCase {
    func testLoadsExistingSessionFromStore() async throws {
        let store = InMemorySessionStore(session: NetEaseSession(userID: "42", cookie: "MUSIC_U=abc"))
        let service = NetEaseAuthService(store: store, qrProvider: FakeQRProvider(result: .waiting))

        let state = await service.currentState()

        XCTAssertEqual(state, .authenticated(userID: "42"))
    }

    func testQRSuccessPersistsSession() async throws {
        let store = InMemorySessionStore()
        let service = NetEaseAuthService(
            store: store,
            qrProvider: FakeQRProvider(result: .confirmed(NetEaseSession(userID: "42", cookie: "MUSIC_U=abc")))
        )

        let state = try await service.pollQRCode()

        XCTAssertEqual(state, .authenticated(userID: "42"))
        XCTAssertEqual(try await store.load(), NetEaseSession(userID: "42", cookie: "MUSIC_U=abc"))
    }
}

struct FakeQRProvider: QRLoginProviding {
    let result: QRLoginPollResult

    func poll() async throws -> QRLoginPollResult {
        result
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NetEaseAuthServiceTests
```

Expected: compilation fails because auth types are not defined.

- [ ] **Step 3: Implement session storage protocols**

```swift
// Sources/CloudLyricBarCore/Auth/SessionStore.swift
import Foundation
import Security

public struct NetEaseSession: Codable, Equatable, Sendable {
    public let userID: String
    public let cookie: String

    public init(userID: String, cookie: String) {
        self.userID = userID
        self.cookie = cookie
    }
}

public protocol SessionStore: Sendable {
    func load() async throws -> NetEaseSession?
    func save(_ session: NetEaseSession) async throws
    func clear() async throws
}

public actor InMemorySessionStore: SessionStore {
    private var session: NetEaseSession?

    public init(session: NetEaseSession? = nil) {
        self.session = session
    }

    public func load() async throws -> NetEaseSession? {
        session
    }

    public func save(_ session: NetEaseSession) async throws {
        self.session = session
    }

    public func clear() async throws {
        session = nil
    }
}

public struct KeychainSessionStore: SessionStore {
    private let service = "CloudLyricBar.NetEaseSession"
    private let account = "default"

    public init() {}

    public func load() async throws -> NetEaseSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.unhandledStatus(status)
        }
        return try JSONDecoder().decode(NetEaseSession.self, from: data)
    }

    public func save(_ session: NetEaseSession) async throws {
        let data = try JSONEncoder().encode(session)
        try await clear()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    public func clear() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum KeychainError: Error, Equatable {
    case unhandledStatus(OSStatus)
}
```

- [ ] **Step 4: Implement QR login state service**

```swift
// Sources/CloudLyricBarCore/Auth/NetEaseAuthService.swift
import Foundation

public enum AuthState: Equatable, Sendable {
    case signedOut
    case waitingForScan
    case authenticated(userID: String)
    case failed(String)
}

public enum QRLoginPollResult: Equatable, Sendable {
    case waiting
    case expired
    case confirmed(NetEaseSession)
}

public protocol QRLoginProviding: Sendable {
    func poll() async throws -> QRLoginPollResult
}

public actor NetEaseAuthService {
    private let store: SessionStore
    private let qrProvider: QRLoginProviding

    public init(store: SessionStore, qrProvider: QRLoginProviding) {
        self.store = store
        self.qrProvider = qrProvider
    }

    public func currentState() async -> AuthState {
        do {
            if let session = try await store.load() {
                return .authenticated(userID: session.userID)
            }
            return .signedOut
        } catch {
            return .failed("无法读取登录状态")
        }
    }

    public func pollQRCode() async throws -> AuthState {
        switch try await qrProvider.poll() {
        case .waiting:
            return .waitingForScan
        case .expired:
            return .failed("二维码已过期")
        case .confirmed(let session):
            try await store.save(session)
            return .authenticated(userID: session.userID)
        }
    }
}
```

- [ ] **Step 5: Run the tests and verify they pass**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NetEaseAuthServiceTests
```

Expected: auth tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/Auth Tests/CloudLyricBarCoreTests/NetEaseAuthServiceTests.swift
git commit -m "feat: add NetEase session and QR login state"
```

## Task 7: Real QR Login Provider

**Files:**
- Modify: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Auth/NetEaseAuthService.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Auth/NetEaseQRLoginProvider.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/NetEaseQRLoginProviderTests.swift`

- [ ] **Step 1: Write failing QR provider tests**

```swift
// Tests/CloudLyricBarCoreTests/NetEaseQRLoginProviderTests.swift
import XCTest
@testable import CloudLyricBarCore

final class NetEaseQRLoginProviderTests: XCTestCase {
    func testCreatesQRCodeURLFromKey() async throws {
        let transport = QueueHTTPTransport(responses: [
            #"{"code":200,"data":{"unikey":"abc-key"}}"#.data(using: .utf8)!,
            #"{"code":200,"data":{"qrurl":"https://music.163.com/login?codekey=abc-key"}}"#.data(using: .utf8)!
        ])
        let provider = NetEaseQRLoginProvider(baseURL: URL(string: "https://music.example")!, transport: transport)

        let qr = try await provider.createQRCode()

        XCTAssertEqual(qr.key, "abc-key")
        XCTAssertEqual(qr.url.absoluteString, "https://music.163.com/login?codekey=abc-key")
        XCTAssertEqual(transport.requests.map { $0.url!.path }, ["/login/qr/key", "/login/qr/create"])
    }

    func testPollConfirmedReturnsSession() async throws {
        let transport = QueueHTTPTransport(responses: [
            #"{"code":803,"cookie":"MUSIC_U=abc;","account":{"id":42}}"#.data(using: .utf8)!
        ])
        let provider = NetEaseQRLoginProvider(baseURL: URL(string: "https://music.example")!, transport: transport)

        let result = try await provider.poll(key: "abc-key")

        XCTAssertEqual(result, .confirmed(NetEaseSession(userID: "42", cookie: "MUSIC_U=abc;")))
        XCTAssertEqual(transport.requests.first?.url?.path, "/login/qr/check")
    }
}

final class QueueHTTPTransport: HTTPTransport, @unchecked Sendable {
    private var responses: [Data]
    private(set) var requests: [URLRequest] = []

    init(responses: [Data]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> Data {
        requests.append(request)
        return responses.removeFirst()
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NetEaseQRLoginProviderTests
```

Expected: compilation fails because `NetEaseQRLoginProvider`, `QRCodeLogin`, and `poll(key:)` are not defined.

- [ ] **Step 3: Extend QR login protocol**

Modify `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Auth/NetEaseAuthService.swift`:

```swift
public struct QRCodeLogin: Equatable, Sendable {
    public let key: String
    public let url: URL

    public init(key: String, url: URL) {
        self.key = key
        self.url = url
    }
}

public protocol QRLoginProviding: Sendable {
    func createQRCode() async throws -> QRCodeLogin
    func poll(key: String) async throws -> QRLoginPollResult
}
```

Update `NetEaseAuthService` polling to accept a key:

```swift
public func createQRCode() async throws -> QRCodeLogin {
    try await qrProvider.createQRCode()
}

public func pollQRCode(key: String) async throws -> AuthState {
    switch try await qrProvider.poll(key: key) {
    case .waiting:
        return .waitingForScan
    case .expired:
        return .failed("二维码已过期")
    case .confirmed(let session):
        try await store.save(session)
        return .authenticated(userID: session.userID)
    }
}
```

Update `FakeQRProvider` in `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/NetEaseAuthServiceTests.swift`:

```swift
struct FakeQRProvider: QRLoginProviding {
    let result: QRLoginPollResult

    func createQRCode() async throws -> QRCodeLogin {
        QRCodeLogin(key: "test-key", url: URL(string: "https://music.example/qr")!)
    }

    func poll(key: String) async throws -> QRLoginPollResult {
        result
    }
}
```

Replace calls to `pollQRCode()` in auth tests with:

```swift
let state = try await service.pollQRCode(key: "test-key")
```

- [ ] **Step 4: Implement the real QR provider**

```swift
// Sources/CloudLyricBarCore/Auth/NetEaseQRLoginProvider.swift
import Foundation

public struct NetEaseQRLoginProvider: QRLoginProviding {
    private let baseURL: URL
    private let transport: HTTPTransport
    private let decoder = JSONDecoder()

    public init(baseURL: URL, transport: HTTPTransport = URLSessionHTTPTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func createQRCode() async throws -> QRCodeLogin {
        let keyData = try await transport.data(for: request(path: "/login/qr/key", query: ["timestamp": nonce()]))
        let keyResponse = try decoder.decode(QRKeyResponse.self, from: keyData)
        let key = keyResponse.data.unikey

        let qrData = try await transport.data(for: request(path: "/login/qr/create", query: [
            "key": key,
            "qrimg": "false",
            "timestamp": nonce()
        ]))
        let qrResponse = try decoder.decode(QRCreateResponse.self, from: qrData)
        guard let url = URL(string: qrResponse.data.qrurl) else {
            throw NetEaseAPIError.invalidURL
        }

        return QRCodeLogin(key: key, url: url)
    }

    public func poll(key: String) async throws -> QRLoginPollResult {
        let data = try await transport.data(for: request(path: "/login/qr/check", query: [
            "key": key,
            "timestamp": nonce()
        ]))
        let response = try decoder.decode(QRCheckResponse.self, from: data)

        switch response.code {
        case 800:
            return .expired
        case 801, 802:
            return .waiting
        case 803:
            guard let cookie = response.cookie, let userID = response.account?.id else {
                return .expired
            }
            return .confirmed(NetEaseSession(userID: String(userID), cookie: cookie))
        default:
            return .waiting
        }
    }

    private func request(path: String, query: [String: String]) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw NetEaseAPIError.invalidURL
        }
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw NetEaseAPIError.invalidURL }
        return URLRequest(url: url)
    }

    private func nonce() -> String {
        String(Int(Date().timeIntervalSince1970 * 1000))
    }
}

private struct QRKeyResponse: Decodable {
    let code: Int
    let data: DataObject

    struct DataObject: Decodable {
        let unikey: String
    }
}

private struct QRCreateResponse: Decodable {
    let code: Int
    let data: DataObject

    struct DataObject: Decodable {
        let qrurl: String
    }
}

private struct QRCheckResponse: Decodable {
    let code: Int
    let cookie: String?
    let account: Account?

    struct Account: Decodable {
        let id: Int
    }
}
```

- [ ] **Step 5: Run auth and QR tests**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NetEaseAuthServiceTests
swift test --filter NetEaseQRLoginProviderTests
```

Expected: auth tests and QR provider tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/Auth Tests/CloudLyricBarCoreTests/NetEaseAuthServiceTests.swift Tests/CloudLyricBarCoreTests/NetEaseQRLoginProviderTests.swift
git commit -m "feat: add real NetEase QR login provider"
```

## Task 8: Playback Control Fallback Order

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Playback/PlaybackControlService.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/PlaybackControlServiceTests.swift`

- [ ] **Step 1: Write failing playback control tests**

```swift
// Tests/CloudLyricBarCoreTests/PlaybackControlServiceTests.swift
import XCTest
@testable import CloudLyricBarCore

final class PlaybackControlServiceTests: XCTestCase {
    func testUsesFirstStrategyThatCanHandleCommand() async throws {
        let first = FakePlaybackStrategy(canHandle: false)
        let second = FakePlaybackStrategy(canHandle: true)
        let service = PlaybackControlService(strategies: [first, second])

        try await service.send(.playPause)

        XCTAssertEqual(await first.commands, [])
        XCTAssertEqual(await second.commands, [.playPause])
    }

    func testThrowsWhenNoStrategyCanHandleCommand() async {
        let service = PlaybackControlService(strategies: [FakePlaybackStrategy(canHandle: false)])

        do {
            try await service.send(.next)
            XCTFail("Expected noAvailableStrategy")
        } catch {
            XCTAssertEqual(error as? PlaybackControlError, .noAvailableStrategy)
        }
    }
}

actor FakePlaybackStrategy: PlaybackControlStrategy {
    let canHandle: Bool
    private(set) var commands: [PlaybackCommand] = []

    init(canHandle: Bool) {
        self.canHandle = canHandle
    }

    func canSend(_ command: PlaybackCommand) async -> Bool {
        canHandle
    }

    func send(_ command: PlaybackCommand) async throws {
        commands.append(command)
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter PlaybackControlServiceTests
```

Expected: compilation fails because playback control types are not defined.

- [ ] **Step 3: Implement playback control service**

```swift
// Sources/CloudLyricBarCore/Playback/PlaybackControlService.swift
import Foundation

public enum PlaybackCommand: Equatable, Sendable {
    case playPause
    case previous
    case next
    case openSong(id: String)
}

public enum PlaybackControlError: Error, Equatable {
    case noAvailableStrategy
}

public protocol PlaybackControlStrategy: Sendable {
    func canSend(_ command: PlaybackCommand) async -> Bool
    func send(_ command: PlaybackCommand) async throws
}

public actor PlaybackControlService {
    private let strategies: [PlaybackControlStrategy]

    public init(strategies: [PlaybackControlStrategy]) {
        self.strategies = strategies
    }

    public func send(_ command: PlaybackCommand) async throws {
        for strategy in strategies {
            if await strategy.canSend(command) {
                try await strategy.send(command)
                return
            }
        }

        throw PlaybackControlError.noAvailableStrategy
    }
}

public struct NetEaseDeepLinkStrategy: PlaybackControlStrategy {
    private let opener: @Sendable (URL) -> Void

    public init(opener: @escaping @Sendable (URL) -> Void) {
        self.opener = opener
    }

    public func canSend(_ command: PlaybackCommand) async -> Bool {
        if case .openSong = command { return true }
        return false
    }

    public func send(_ command: PlaybackCommand) async throws {
        guard case .openSong(let id) = command,
              let url = URL(string: "orpheus://song/\(id)")
        else {
            throw PlaybackControlError.noAvailableStrategy
        }

        opener(url)
    }
}
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter PlaybackControlServiceTests
```

Expected: playback fallback tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/Playback/PlaybackControlService.swift Tests/CloudLyricBarCoreTests/PlaybackControlServiceTests.swift
git commit -m "feat: add playback control fallback service"
```

## Task 9: Permissions and Accessibility Playback Strategy

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Permissions/PermissionCoordinator.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/AccessibilityPlaybackStrategy.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/PermissionCoordinatorTests.swift`

- [ ] **Step 1: Write failing permission tests**

```swift
// Tests/CloudLyricBarCoreTests/PermissionCoordinatorTests.swift
import XCTest
@testable import CloudLyricBarCore

final class PermissionCoordinatorTests: XCTestCase {
    func testDoesNotRequestPermissionBeforeFeatureNeedsIt() async {
        let probe = FakePermissionProbe(trusted: false)
        let coordinator = PermissionCoordinator(probe: probe)

        let state = await coordinator.currentAccessibilityState()

        XCTAssertEqual(state, .notTrusted)
        XCTAssertEqual(await probe.requestCount, 0)
    }

    func testRequestsAccessibilityOnlyWhenAsked() async {
        let probe = FakePermissionProbe(trusted: false)
        let coordinator = PermissionCoordinator(probe: probe)

        await coordinator.requestAccessibility()

        XCTAssertEqual(await probe.requestCount, 1)
    }
}

actor FakePermissionProbe: AccessibilityPermissionProbing {
    private let trusted: Bool
    private(set) var requestCount = 0

    init(trusted: Bool) {
        self.trusted = trusted
    }

    func isTrusted() async -> Bool {
        trusted
    }

    func requestTrustPrompt() async {
        requestCount += 1
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter PermissionCoordinatorTests
```

Expected: compilation fails because permission coordinator types are not defined.

- [ ] **Step 3: Implement permission coordinator**

```swift
// Sources/CloudLyricBarCore/Permissions/PermissionCoordinator.swift
import Foundation

public enum AccessibilityPermissionState: Equatable, Sendable {
    case trusted
    case notTrusted
}

public protocol AccessibilityPermissionProbing: Sendable {
    func isTrusted() async -> Bool
    func requestTrustPrompt() async
}

public actor PermissionCoordinator {
    private let probe: AccessibilityPermissionProbing

    public init(probe: AccessibilityPermissionProbing) {
        self.probe = probe
    }

    public func currentAccessibilityState() async -> AccessibilityPermissionState {
        await probe.isTrusted() ? .trusted : .notTrusted
    }

    public func requestAccessibility() async {
        await probe.requestTrustPrompt()
    }
}
```

- [ ] **Step 4: Implement macOS accessibility strategy in the app target**

```swift
// Sources/CloudLyricBarApp/AccessibilityPlaybackStrategy.swift
import AppKit
import ApplicationServices
import CloudLyricBarCore

struct MacAccessibilityPermissionProbe: AccessibilityPermissionProbing {
    func isTrusted() async -> Bool {
        AXIsProcessTrusted()
    }

    func requestTrustPrompt() async {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

struct AccessibilityPlaybackStrategy: PlaybackControlStrategy {
    func canSend(_ command: PlaybackCommand) async -> Bool {
        AXIsProcessTrusted() && command != .openSong(id: "")
    }

    func send(_ command: PlaybackCommand) async throws {
        switch command {
        case .playPause:
            sendKey(keyCode: 49)
        case .previous, .next, .openSong:
            throw PlaybackControlError.noAvailableStrategy
        }
    }

    private func sendKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
```

- [ ] **Step 5: Run tests and build**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter PermissionCoordinatorTests
swift build
```

Expected: permission tests pass and the app target builds.

- [ ] **Step 6: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/Permissions Sources/CloudLyricBarApp/AccessibilityPlaybackStrategy.swift Tests/CloudLyricBarCoreTests/PermissionCoordinatorTests.swift
git commit -m "feat: add permission-gated accessibility control"
```

## Task 10: Now Playing Snapshot and Timer Fallback

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/NowPlaying/NowPlayingService.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/NowPlayingServiceTests.swift`

- [ ] **Step 1: Write failing now-playing tests**

```swift
// Tests/CloudLyricBarCoreTests/NowPlayingServiceTests.swift
import XCTest
@testable import CloudLyricBarCore

final class NowPlayingServiceTests: XCTestCase {
    func testEstimatorAdvancesPositionWhilePlaying() {
        let song = Song(id: "1", title: "测试歌", artist: "测试歌手")
        let baseDate = Date(timeIntervalSince1970: 100)
        let snapshot = NowPlayingSnapshot(song: song, playback: .playing, position: 10, capturedAt: baseDate)

        let estimated = TimerPositionEstimator.estimate(from: snapshot, at: Date(timeIntervalSince1970: 104.25))

        XCTAssertEqual(estimated.position, 14.25, accuracy: 0.001)
    }

    func testEstimatorDoesNotAdvanceWhenPaused() {
        let song = Song(id: "1", title: "测试歌", artist: "测试歌手")
        let baseDate = Date(timeIntervalSince1970: 100)
        let snapshot = NowPlayingSnapshot(song: song, playback: .paused, position: 10, capturedAt: baseDate)

        let estimated = TimerPositionEstimator.estimate(from: snapshot, at: Date(timeIntervalSince1970: 104.25))

        XCTAssertEqual(estimated.position, 10, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NowPlayingServiceTests
```

Expected: compilation fails because `TimerPositionEstimator` is not defined.

- [ ] **Step 3: Implement now-playing protocol and timer estimator**

```swift
// Sources/CloudLyricBarCore/NowPlaying/NowPlayingService.swift
import Foundation

public protocol NowPlayingProviding: Sendable {
    func snapshot() async -> NowPlayingSnapshot
}

public enum TimerPositionEstimator {
    public static func estimate(from snapshot: NowPlayingSnapshot, at date: Date = Date()) -> NowPlayingSnapshot {
        guard snapshot.playback == .playing, let position = snapshot.position else {
            return snapshot
        }

        let elapsed = max(0, date.timeIntervalSince(snapshot.capturedAt))
        return NowPlayingSnapshot(
            song: snapshot.song,
            playback: snapshot.playback,
            position: position + elapsed,
            capturedAt: date
        )
    }
}

public actor SnapshotNowPlayingService: NowPlayingProviding {
    private var latest: NowPlayingSnapshot

    public init(initial: NowPlayingSnapshot = NowPlayingSnapshot(song: nil, playback: .stopped, position: nil)) {
        self.latest = initial
    }

    public func update(_ snapshot: NowPlayingSnapshot) {
        latest = snapshot
    }

    public func snapshot() async -> NowPlayingSnapshot {
        TimerPositionEstimator.estimate(from: latest)
    }
}
```

- [ ] **Step 4: Run the test and verify it passes**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter NowPlayingServiceTests
```

Expected: now-playing tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/NowPlaying/NowPlayingService.swift Tests/CloudLyricBarCoreTests/NowPlayingServiceTests.swift
git commit -m "feat: add now-playing timer fallback"
```

## Task 11: View Model for Menu Bar and Popover State

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/App/CloudLyricBarViewModel.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/CloudLyricBarViewModelTests.swift`

- [ ] **Step 1: Write failing view model tests**

```swift
// Tests/CloudLyricBarCoreTests/CloudLyricBarViewModelTests.swift
import XCTest
@testable import CloudLyricBarCore

@MainActor
final class CloudLyricBarViewModelTests: XCTestCase {
    func testRefreshLyricsUpdatesMenuBarTitle() async throws {
        let api = FakeNetEaseAPIClient(lines: [
            LyricLine(startTime: 0, text: "第一句"),
            LyricLine(startTime: 10, text: "第二句")
        ])
        let nowPlaying = NowPlayingSnapshot(
            song: Song(id: "1", title: "测试歌", artist: "测试歌手"),
            playback: .playing,
            position: 12
        )
        let model = CloudLyricBarViewModel(apiClient: api)

        await model.apply(nowPlaying: nowPlaying, isClientRunning: true)

        XCTAssertEqual(model.menuBarTitle, "♪ 第二句")
        XCTAssertEqual(model.lyricContext.current?.text, "第二句")
    }
}

struct FakeNetEaseAPIClient: NetEaseAPIClient {
    let lines: [LyricLine]

    func userPlaylists(userID: String) async throws -> [Playlist] { [] }
    func searchSongs(keyword: String) async throws -> [Song] { [] }
    func fetchLyrics(songID: String) async throws -> [LyricLine] { lines }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter CloudLyricBarViewModelTests
```

Expected: compilation fails because `CloudLyricBarViewModel` is not defined.

- [ ] **Step 3: Implement the view model**

```swift
// Sources/CloudLyricBarCore/App/CloudLyricBarViewModel.swift
import Foundation

@MainActor
public final class CloudLyricBarViewModel: ObservableObject {
    @Published public private(set) var menuBarTitle: String = "♪"
    @Published public private(set) var lyricContext = LyricContext(previous: nil, current: nil, next: nil)
    @Published public private(set) var currentSong: Song?
    @Published public private(set) var playback: PlaybackState = .stopped
    @Published public private(set) var playlists: [Playlist] = []
    @Published public private(set) var searchResults: [Song] = []
    @Published public private(set) var message: String?

    private let apiClient: NetEaseAPIClient
    private var cachedLyrics: [String: [LyricLine]] = [:]

    public init(apiClient: NetEaseAPIClient) {
        self.apiClient = apiClient
    }

    public func apply(nowPlaying: NowPlayingSnapshot, isClientRunning: Bool) async {
        currentSong = nowPlaying.song
        playback = nowPlaying.playback

        var lines: [LyricLine] = []
        if let song = nowPlaying.song {
            do {
                lines = try await lyrics(for: song.id)
            } catch {
                message = "歌词加载失败"
            }
        }

        lyricContext = LyricSyncEngine.context(at: nowPlaying.position ?? 0, in: lines)
        let display = MenuBarDisplayState(
            playback: nowPlaying.playback,
            lyricText: lyricContext.current?.text,
            fallbackTitle: nowPlaying.song?.title,
            isClientRunning: isClientRunning
        )
        menuBarTitle = display.title
    }

    public func loadPlaylists(userID: String) async {
        do {
            playlists = try await apiClient.userPlaylists(userID: userID)
            message = nil
        } catch {
            message = "歌单加载失败"
        }
    }

    public func search(keyword: String) async {
        guard !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        do {
            searchResults = try await apiClient.searchSongs(keyword: keyword)
            message = nil
        } catch {
            message = "搜索失败"
        }
    }

    private func lyrics(for songID: String) async throws -> [LyricLine] {
        if let cached = cachedLyrics[songID] {
            return cached
        }

        let lines = try await apiClient.fetchLyrics(songID: songID)
        cachedLyrics[songID] = lines
        return lines
    }
}
```

- [ ] **Step 4: Run the test and verify it passes**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter CloudLyricBarViewModelTests
```

Expected: view model test passes.

- [ ] **Step 5: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore/App/CloudLyricBarViewModel.swift Tests/CloudLyricBarCoreTests/CloudLyricBarViewModelTests.swift
git commit -m "feat: add CloudLyricBar app view model"
```

## Task 12: Native Menu Bar Shell

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/main.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/AppDelegate.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/StatusBarController.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/PopoverController.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/Views/PopoverView.swift`

- [ ] **Step 1: Add executable entry point**

```swift
// Sources/CloudLyricBarApp/main.swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 2: Add app delegate and dependency wiring**

```swift
// Sources/CloudLyricBarApp/AppDelegate.swift
import AppKit
import CloudLyricBarCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let api = URLSessionNetEaseAPIClient(baseURL: URL(string: "http://localhost:3000")!)
        let viewModel = CloudLyricBarViewModel(apiClient: api)
        let popoverController = PopoverController(viewModel: viewModel)
        statusBarController = StatusBarController(viewModel: viewModel, popoverController: popoverController)
    }
}
```

- [ ] **Step 3: Add popover controller**

```swift
// Sources/CloudLyricBarApp/PopoverController.swift
import AppKit
import CloudLyricBarCore
import SwiftUI

@MainActor
final class PopoverController {
    private let popover: NSPopover

    init(viewModel: CloudLyricBarViewModel) {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.contentViewController = NSHostingController(rootView: PopoverView(viewModel: viewModel))
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

- [ ] **Step 4: Add status bar controller**

```swift
// Sources/CloudLyricBarApp/StatusBarController.swift
import AppKit
import CloudLyricBarCore
import Combine

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popoverController: PopoverController
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: CloudLyricBarViewModel, popoverController: PopoverController) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: 220)
        self.popoverController = popoverController

        if let button = statusItem.button {
            button.title = viewModel.menuBarTitle
            button.target = self
            button.action = #selector(togglePopover)
        }

        viewModel.$menuBarTitle
            .receive(on: RunLoop.main)
            .sink { [weak self] title in
                self?.statusItem.button?.title = title
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        popoverController.toggle(relativeTo: button)
    }
}
```

- [ ] **Step 5: Add compact popover UI**

```swift
// Sources/CloudLyricBarApp/Views/PopoverView.swift
import CloudLyricBarCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: CloudLyricBarViewModel
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentSong?.title ?? "未播放")
                        .font(.headline)
                        .lineLimit(1)
                    Text(viewModel.currentSong?.artist ?? "打开网易云音乐后开始同步")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack {
                Button(action: {}) { Image(systemName: "backward.fill") }
                Button(action: {}) { Image(systemName: viewModel.playback == .playing ? "pause.fill" : "play.fill") }
                Button(action: {}) { Image(systemName: "forward.fill") }
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.lyricContext.previous?.text ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(viewModel.lyricContext.current?.text ?? "暂无同步歌词")
                    .font(.body)
                    .lineLimit(2)
                Text(viewModel.lyricContext.next?.text ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            TextField("搜索歌曲、歌手或专辑", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await viewModel.search(keyword: searchText) }
                }

            List {
                Section("搜索结果") {
                    ForEach(viewModel.searchResults) { song in
                        VStack(alignment: .leading) {
                            Text(song.title).lineLimit(1)
                            Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }

                Section("我的歌单") {
                    ForEach(viewModel.playlists) { playlist in
                        HStack {
                            Text(playlist.name).lineLimit(1)
                            Spacer()
                            Text("\(playlist.trackCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let message = viewModel.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 360, height: 520)
    }
}
```

- [ ] **Step 6: Build the executable**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift build
```

Expected: build succeeds.

- [ ] **Step 7: Launch the app manually**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift run CloudLyricBarApp
```

Expected: a `♪` item appears in the right side of the macOS menu bar; clicking it opens the popover.

- [ ] **Step 8: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarApp
git commit -m "feat: add native menu bar shell"
```

## Task 13: Integrate Controls, Search Selection, and App States

**Files:**
- Modify: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/App/CloudLyricBarViewModel.swift`
- Modify: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/AppDelegate.swift`
- Modify: `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/Views/PopoverView.swift`
- Create: `/Users/danhyolk/CloudLyricBar/Tests/CloudLyricBarCoreTests/CloudLyricBarActionsTests.swift`

- [ ] **Step 1: Write failing action tests**

```swift
// Tests/CloudLyricBarCoreTests/CloudLyricBarActionsTests.swift
import XCTest
@testable import CloudLyricBarCore

@MainActor
final class CloudLyricBarActionsTests: XCTestCase {
    func testSelectingSongSendsOpenSongCommand() async throws {
        let playback = RecordingPlaybackControl()
        let model = CloudLyricBarViewModel(apiClient: FakeNetEaseAPIClient(lines: []), playbackControl: playback)
        let song = Song(id: "1901371647", title: "一路向北", artist: "周杰伦")

        await model.play(song)

        XCTAssertEqual(await playback.commands, [.openSong(id: "1901371647")])
    }
}

actor RecordingPlaybackControl: PlaybackControlling {
    private(set) var commands: [PlaybackCommand] = []

    func send(_ command: PlaybackCommand) async throws {
        commands.append(command)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test --filter CloudLyricBarActionsTests
```

Expected: compilation fails because `PlaybackControlling`, the new view model initializer, and `play(_:)` are not defined.

- [ ] **Step 3: Add playback-control abstraction and view model actions**

Modify `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/Playback/PlaybackControlService.swift` by adding:

```swift
public protocol PlaybackControlling: Sendable {
    func send(_ command: PlaybackCommand) async throws
}

extension PlaybackControlService: PlaybackControlling {}
```

Modify `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarCore/App/CloudLyricBarViewModel.swift`:

```swift
// Add this property.
private let playbackControl: PlaybackControlling?

// Replace the initializer with this initializer.
public init(apiClient: NetEaseAPIClient, playbackControl: PlaybackControlling? = nil) {
    self.apiClient = apiClient
    self.playbackControl = playbackControl
}

// Add these methods inside CloudLyricBarViewModel.
public func play(_ song: Song) async {
    do {
        try await playbackControl?.send(.openSong(id: song.id))
        message = nil
    } catch {
        message = "无法让网易云播放这首歌"
    }
}

public func sendPlaybackCommand(_ command: PlaybackCommand) async {
    do {
        try await playbackControl?.send(command)
        message = nil
    } catch {
        message = "播放控制失败"
    }
}
```

- [ ] **Step 4: Wire playback control in the app delegate**

Modify `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/AppDelegate.swift`:

```swift
let playback = PlaybackControlService(strategies: [
    NetEaseDeepLinkStrategy { url in
        NSWorkspace.shared.open(url)
    }
])
let viewModel = CloudLyricBarViewModel(apiClient: api, playbackControl: playback)
```

- [ ] **Step 5: Connect popover buttons and row selection**

Modify the buttons in `/Users/danhyolk/CloudLyricBar/Sources/CloudLyricBarApp/Views/PopoverView.swift`:

```swift
Button(action: { Task { await viewModel.sendPlaybackCommand(.previous) } }) {
    Image(systemName: "backward.fill")
}
Button(action: { Task { await viewModel.sendPlaybackCommand(.playPause) } }) {
    Image(systemName: viewModel.playback == .playing ? "pause.fill" : "play.fill")
}
Button(action: { Task { await viewModel.sendPlaybackCommand(.next) } }) {
    Image(systemName: "forward.fill")
}
```

Modify each search result row:

```swift
Button(action: { Task { await viewModel.play(song) } }) {
    VStack(alignment: .leading) {
        Text(song.title).lineLimit(1)
        Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
    }
}
.buttonStyle(.plain)
```

- [ ] **Step 6: Run tests and build**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test
swift build
```

Expected: all tests pass and the app builds.

- [ ] **Step 7: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add Sources/CloudLyricBarCore Sources/CloudLyricBarApp Tests/CloudLyricBarCoreTests/CloudLyricBarActionsTests.swift
git commit -m "feat: wire playback actions into popover"
```

## Task 14: Manual Verification and Risk Notes

**Files:**
- Create: `/Users/danhyolk/CloudLyricBar/docs/manual-test.md`

- [ ] **Step 1: Write the manual verification checklist**

```markdown
# CloudLyricBar Manual Test Checklist

## Menu Bar

- Launch with `swift run CloudLyricBarApp`.
- Confirm a compact music item appears in the right side of the macOS menu bar.
- Click the menu bar item and confirm the popover opens below it.
- Click outside the popover and confirm it closes.

## Lyrics

- Use unit-tested sample lyrics to verify current, previous, and next lines in the popover.
- Verify long lyrics scroll in the pure marquee test.
- Confirm missing lyrics display `暂无同步歌词`.

## NetEase Client Handoff

- Install and launch the official NetEase Cloud Music Mac client.
- Trigger song selection from a search result.
- Confirm the official client receives the song deep link if the installed client supports it.
- If deep link playback fails, use the permission settings entry to request Accessibility permission and verify the app reports whether accessibility control is available.

## Login and Library

- Run a local NetEase API service at `http://localhost:3000`.
- Use QR login flow through the configured NetEase API-compatible service.
- Confirm playlists load after login.
- Confirm search returns songs for a known keyword.

## Permission Behavior

- Confirm the app launches without requesting Accessibility permission.
- Confirm no permission prompt appears until a feature requires it.
```

- [ ] **Step 2: Run automated verification**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test
swift build
```

Expected: all tests pass and the app builds.

- [ ] **Step 3: Run manual smoke test**

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift run CloudLyricBarApp
```

Expected: menu bar item appears, popover opens, and the app does not request permissions on launch.

- [ ] **Step 4: Commit**

```bash
cd /Users/danhyolk/CloudLyricBar
git add docs/manual-test.md
git commit -m "docs: add manual verification checklist"
```

## Spec Coverage Check

- Menu bar synced lyrics: Tasks 1, 2, 3, 10, 11.
- Long lyric horizontal scrolling: Task 3.
- Click-to-open native popover: Task 12.
- Current song, controls, lyrics, search, playlists in panel: Tasks 11, 12, 13.
- QR login and Keychain session: Tasks 6 and 7.
- Playlist and search API layer: Tasks 4, 5, 11, 13.
- Song selection handoff to NetEase client: Tasks 8 and 13.
- Permission-gated accessibility path: Task 9.
- No direct audio playback: enforced by architecture and playback handoff strategy.
- Timer-based progress estimation: Task 10.
- Missing lyric, closed client, denied permission, and playback unavailable states: Tasks 1, 9, 10, 11, 12, 13, 14 establish state surfaces and verification.

## Final Verification

Run:

```bash
cd /Users/danhyolk/CloudLyricBar
swift test
swift build
git status --short
```

Expected:

- `swift test` succeeds.
- `swift build` succeeds.
- `git status --short` is empty after the final commit.
