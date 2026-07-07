# CloudLyricBar

CloudLyricBar is a macOS menu bar lyric display tool. It reads the song that is currently playing on your Mac, matches lyrics through a NetEase Cloud Music API-compatible service, and shows the current lyric line directly in the macOS menu bar.

中文说明在前，English documentation follows below.

---

## 中文

CloudLyricBar 是一个 macOS 菜单栏歌词工具。它会读取你电脑上正在播放的音乐，把当前歌词显示在 Mac 顶部菜单栏里；点击菜单栏文字后，会展开一个小控制面板，显示歌曲封面、标题、歌手、上一句/当前句/下一句歌词，并提供播放控制和退出按钮。

### 功能

- 在 macOS 菜单栏显示当前歌词
- 长歌词会在菜单栏内横向滚动，并在滚到末尾后停住
- 点击菜单栏歌词展开固定尺寸的小面板
- 展开面板显示：
  - 歌曲封面
  - 歌名和歌手
  - 上一首、播放/暂停、下一首
  - 上一句、当前句、下一句歌词
  - 退出按钮
- 点击屏幕空白处自动收起面板
- 支持读取系统正在播放的媒体信息
- 支持网易云音乐、Apple Music、Spotify 等会向 macOS 暴露“正在播放”信息的播放器
- 打包后的 App 会自动启动内置的网易云 API 服务，不需要用户手动运行 Node 或 npx

### 支持的软件

CloudLyricBar 通过 macOS 的系统媒体信息读取正在播放的歌曲。因此，只要播放器把当前歌曲信息暴露给系统，就有机会被识别。

已按设计支持：

- NetEase Cloud Music / 网易云音乐
- Apple Music
- Spotify

实际歌词匹配主要依赖网易云音乐的曲库。如果 Apple Music 或 Spotify 正在播放的歌曲能在网易云曲库中匹配到，就可以显示歌词；匹配不到时会显示无同步歌词或加载失败提示。

### 系统要求

- macOS 14 或更新版本
- 如果从源码运行：Swift 6 工具链
- 如果使用打包后的 App：不需要手动安装 Node.js

### 直接使用

打包后的应用位于：

```text
dist/CloudLyricBar.app
```

双击打开即可。它是菜单栏 App，不会显示普通窗口。启动后请看 Mac 顶部菜单栏。

如果要退出，点击菜单栏歌词展开面板，然后点击右下角的“退出”。

### 从源码运行

进入项目目录：

```zsh
cd CloudLyricBar
```

运行调试版本：

```zsh
swift run --disable-sandbox CloudLyricBarApp
```

源码运行时，App 会尝试使用本机已有的 Node/npx 启动网易云 API 服务。如果你只想双击使用，请优先运行打包脚本生成完整 App。

### 打包 App

```zsh
./scripts/package-app.sh
```

这个脚本会：

1. 下载项目私有的 Node runtime
2. 安装 `NeteaseCloudMusicApi`
3. 构建 release 版本
4. 生成 `dist/CloudLyricBar.app`

打包完成后，双击 `dist/CloudLyricBar.app` 使用。

### 测试

```zsh
swift run --disable-sandbox CloudLyricBarCoreTests
```

### 权限说明

CloudLyricBar 会尽量通过系统媒体接口控制播放。某些播放器或某些情况下，上一首/下一首/播放暂停可能需要 macOS 辅助功能权限。

如果播放控制不可用，请到：

```text
系统设置 -> 隐私与安全性 -> 辅助功能
```

允许 CloudLyricBar。

### 已知限制

- 歌词匹配依赖网易云曲库，不保证所有歌曲都有同步歌词
- Apple Music 和 Spotify 的歌词不是直接从它们自己的歌词系统读取，而是用当前歌曲信息去匹配网易云歌词
- 未签名的本地构建 App 第一次打开时，macOS 可能会弹出安全提示
- 本项目不是网易云音乐、Apple Music 或 Spotify 的官方项目

### 项目结构

```text
Sources/CloudLyricBarApp      macOS 菜单栏 App、弹窗、媒体读取和播放控制
Sources/CloudLyricBarCore     歌词同步、菜单栏滚动、网易云 API、状态逻辑
Tests/CloudLyricBarCoreTests  核心逻辑测试
Resources                     App 图标资源
scripts/package-app.sh        打包脚本
```

### 免责声明

本项目仅用于个人学习和本地使用。项目中对第三方音乐服务的名称引用仅用于说明兼容性。本项目与网易云音乐、Apple Music、Spotify 没有关联，也不是它们的官方客户端或官方插件。

---

## English

CloudLyricBar is a macOS menu bar lyric companion. It reads the media currently playing on your Mac, resolves synchronized lyrics through a NetEase Cloud Music API-compatible service, and displays the active lyric line in the macOS menu bar.

### Features

- Shows the current lyric line in the macOS menu bar
- Scrolls long lyric lines horizontally and stops at the readable end
- Opens a compact popover when the menu bar item is clicked
- The popover shows:
  - Album artwork
  - Song title and artist
  - Previous, play/pause, and next controls
  - Previous, current, and next lyric lines
  - Quit button
- Closes the popover when you click outside it
- Reads the current system now-playing media
- Works with players that publish now-playing information to macOS
- The packaged app includes its own Node runtime and NetEase API service, so end users do not need to run Node or npx manually

### Supported Players

CloudLyricBar reads now-playing metadata from macOS. Any player that exposes its current track to the system may work.

Designed targets include:

- NetEase Cloud Music
- Apple Music
- Spotify

Lyrics are resolved mainly through the NetEase Cloud Music catalog. If a song from Apple Music or Spotify can be matched in that catalog, synchronized lyrics can be displayed. If it cannot be matched, the app may show a missing lyric or loading failure message.

### Requirements

- macOS 14 or later
- Swift 6 toolchain when running from source
- No manual Node.js installation is required when using the packaged app

### Use The Packaged App

The packaged app is generated at:

```text
dist/CloudLyricBar.app
```

Open it by double-clicking the app. CloudLyricBar is a menu bar app, so it does not open a regular window. After launch, look at the top macOS menu bar.

To quit, click the lyric in the menu bar to open the popover, then click the quit button.

### Run From Source

Enter the project directory:

```zsh
cd CloudLyricBar
```

Run the debug build:

```zsh
swift run --disable-sandbox CloudLyricBarApp
```

When running from source, the app attempts to use local Node/npx to start the NetEase API service. For normal double-click usage, build the packaged app instead.

### Package The App

```zsh
./scripts/package-app.sh
```

The packaging script will:

1. Download a private Node runtime for the app
2. Install `NeteaseCloudMusicApi`
3. Build the release executable
4. Generate `dist/CloudLyricBar.app`

After packaging, open `dist/CloudLyricBar.app`.

### Tests

```zsh
swift run --disable-sandbox CloudLyricBarCoreTests
```

### Permissions

CloudLyricBar first tries to control playback through system media controls. In some cases, previous/next/play-pause control may require macOS Accessibility permission.

If playback control does not work, allow CloudLyricBar in:

```text
System Settings -> Privacy & Security -> Accessibility
```

### Known Limitations

- Lyric matching depends on the NetEase Cloud Music catalog
- Apple Music and Spotify lyrics are not read directly from their own lyric systems
- Locally built unsigned apps may trigger macOS security prompts on first launch
- This project is not an official NetEase Cloud Music, Apple Music, or Spotify project

### Project Layout

```text
Sources/CloudLyricBarApp      macOS menu bar app, popover, media reading, playback control
Sources/CloudLyricBarCore     lyric sync, menu bar marquee, NetEase API, app state logic
Tests/CloudLyricBarCoreTests  core logic tests
Resources                     app icon resources
scripts/package-app.sh        packaging script
```

### Disclaimer

This project is intended for personal learning and local use. Third-party music service names are used only to describe compatibility. CloudLyricBar is not affiliated with NetEase Cloud Music, Apple Music, or Spotify.
