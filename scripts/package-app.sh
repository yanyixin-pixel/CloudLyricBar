#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CloudLyricBar"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
VENDOR_DIR="$ROOT_DIR/.build/vendor"
API_DIR="$VENDOR_DIR/NeteaseCloudMusicApi"
NODE_VERSION="v20.15.1"

case "$(uname -m)" in
  arm64) NODE_ARCH="darwin-arm64" ;;
  x86_64) NODE_ARCH="darwin-x64" ;;
  *) echo "Unsupported Mac architecture: $(uname -m)" >&2; exit 1 ;;
esac

NODE_DIR="$VENDOR_DIR/node-$NODE_VERSION-$NODE_ARCH"
NODE_TARBALL="$VENDOR_DIR/node-$NODE_VERSION-$NODE_ARCH.tar.gz"
NODE_URL="https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-$NODE_ARCH.tar.gz"

mkdir -p "$VENDOR_DIR"

if [ ! -x "$NODE_DIR/bin/node" ]; then
  echo "Downloading private Node runtime..."
  curl -L "$NODE_URL" -o "$NODE_TARBALL"
  tar -xzf "$NODE_TARBALL" -C "$VENDOR_DIR"
fi

if [ ! -f "$API_DIR/app.js" ]; then
  echo "Installing NetEase Cloud Music API..."
  rm -rf "$API_DIR"
  mkdir -p "$API_DIR"
  PATH="$NODE_DIR/bin:$PATH" npm install --prefix "$API_DIR" NeteaseCloudMusicApi@latest --omit=dev
  cat > "$API_DIR/app.js" <<'JS'
require('./node_modules/NeteaseCloudMusicApi/app.js')
JS
fi

echo "Building CloudLyricBar..."
swift build --disable-sandbox -c release --product CloudLyricBarApp

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/CloudLyricBarApp" "$MACOS_DIR/$APP_NAME"
cp -R "$NODE_DIR" "$RESOURCES_DIR/node"
cp -R "$API_DIR" "$RESOURCES_DIR/NeteaseCloudMusicApi"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>local.cloudlyricbar.app</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "Packaged: $APP_DIR"
