#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-v0.0.1}"
APP_NAME="CloudLyricBar"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/$APP_NAME-$VERSION-macOS"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION-macOS.zip"

"$ROOT_DIR/scripts/package-app.sh"

rm -rf "$RELEASE_DIR" "$ZIP_PATH"
mkdir -p "$RELEASE_DIR"
cp -R "$DIST_DIR/$APP_NAME.app" "$RELEASE_DIR/$APP_NAME.app"

cat > "$RELEASE_DIR/Open CloudLyricBar.command" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/CloudLyricBar.app"

if [ ! -d "$APP" ]; then
  osascript -e 'display dialog "CloudLyricBar.app was not found next to this launcher." buttons {"OK"} default button "OK" with icon caution' >/dev/null
  exit 1
fi

xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
chmod +x "$APP/Contents/MacOS/CloudLyricBar" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
open "$APP"
SH
chmod +x "$RELEASE_DIR/Open CloudLyricBar.command"

cat > "$RELEASE_DIR/README-FIRST.txt" <<'TXT'
CloudLyricBar first launch
==========================

中文：
1. 双击 “Open CloudLyricBar.command”。
2. 它会移除 CloudLyricBar.app 的下载隔离属性，然后打开 App。
3. 如果 macOS 拦截这个 command 文件，请右键点击它，选择“打开”。
4. CloudLyricBar 是菜单栏 App，启动后请看 Mac 顶部菜单栏。

English:
1. Double-click “Open CloudLyricBar.command”.
2. It removes the download quarantine attribute from CloudLyricBar.app, then opens the app.
3. If macOS blocks the command file, right-click it and choose Open.
4. CloudLyricBar is a menu bar app, so look at the top macOS menu bar after launch.

Why this is needed:
This release is ad-hoc signed but not Apple Developer ID notarized yet. macOS may block apps downloaded from the internet until the quarantine attribute is removed.
TXT

(
  cd "$DIST_DIR"
  ditto -c -k --norsrc --keepParent "$APP_NAME-$VERSION-macOS" "$ZIP_PATH"
)

echo "Packaged release: $ZIP_PATH"
