#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexUsageBar"
BUNDLE_ID="com.shaned.CodexUsageBar"
MIN_SYSTEM_VERSION="14.0"
ARCHITECTURE="arm64"
REQUESTED_VERSION="${1:-}"

if (( $# > 1 )); then
  echo "usage: $0 [expected-version]" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
RELEASE_DIR="$ROOT_DIR/dist/release"
SOURCE_ICON="$ROOT_DIR/Sources/CodexUsageBar/Resources/AppIcon.icns"

VERSION="$(tr -d '[:space:]' <"$VERSION_FILE")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: invalid version in $VERSION_FILE" >&2
  exit 1
fi

if [[ -n "$REQUESTED_VERSION" && "$REQUESTED_VERSION" != "$VERSION" ]]; then
  echo "error: requested version $REQUESTED_VERSION does not match VERSION ($VERSION)" >&2
  exit 2
fi

ARCHIVE_NAME="$APP_NAME-v$VERSION-macos-$ARCHITECTURE.zip"
CHECKSUM_NAME="$ARCHIVE_NAME.sha256"
ARCHIVE_PATH="$RELEASE_DIR/$ARCHIVE_NAME"

if [[ ! -s "$SOURCE_ICON" ]]; then
  echo "error: missing app icon at $SOURCE_ICON" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codexusagebar-package.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"
swift test
swift build --configuration release --arch "$ARCHITECTURE"
BUILD_BINARY="$(swift build --configuration release --arch "$ARCHITECTURE" --show-bin-path)/$APP_NAME"

rm -rf "$RELEASE_DIR/$APP_NAME.app" "$ARCHIVE_PATH" "$RELEASE_DIR/$CHECKSUM_NAME"
mkdir -p "$RELEASE_DIR" "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$SOURCE_ICON" "$APP_RESOURCES/AppIcon.icns"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

xattr -cr "$APP_BUNDLE"
plutil -lint "$INFO_PLIST"
codesign --force --sign - --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$(lipo -archs "$APP_BINARY")" != "$ARCHITECTURE" ]]; then
  echo "error: expected $ARCHITECTURE release binary" >&2
  exit 1
fi

COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

VERIFY_DIR="$STAGING_DIR/verify"
mkdir -p "$VERIFY_DIR"
COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc -x -k "$ARCHIVE_PATH" "$VERIFY_DIR"
codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/$APP_NAME.app"

zipinfo -1 "$ARCHIVE_PATH" >"$VERIFY_DIR/archive-entries.txt"
if grep -Eq '^__MACOSX/|(^|/)\._' "$VERIFY_DIR/archive-entries.txt"; then
  echo "error: archive contains unexpected AppleDouble metadata" >&2
  exit 1
fi

(
  cd "$RELEASE_DIR"
  shasum -a 256 "$ARCHIVE_NAME" >"$CHECKSUM_NAME"
  shasum -a 256 -c "$CHECKSUM_NAME"
)

echo "release archive: $ARCHIVE_PATH"
echo "checksum: $RELEASE_DIR/$CHECKSUM_NAME"
