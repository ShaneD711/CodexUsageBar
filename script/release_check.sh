#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexUsageBar"
ARCHITECTURE="arm64"
EXPECTED_VERSION="${1:-}"

if (( $# != 1 )); then
  echo "usage: $0 <expected-version>" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
RELEASE_DIR="$ROOT_DIR/dist/release"
TAG_NAME="v$EXPECTED_VERSION"
ARCHIVE_NAME="$APP_NAME-$TAG_NAME-macos-$ARCHITECTURE.zip"
CHECKSUM_NAME="$ARCHIVE_NAME.sha256"
ARCHIVE_PATH="$RELEASE_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="$RELEASE_DIR/$CHECKSUM_NAME"

fail() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

for command_name in git swift plutil codesign lipo file shasum ditto grep awk; do
  require_command "$command_name"
done

cd "$ROOT_DIR"

for document in ARCHITECTURE.md SECURITY.md DISTRIBUTION.md CONTRIBUTING.md; do
  [[ -s "$document" ]] || fail "required project document is missing: $document"
done

VERSION="$(tr -d '[:space:]' <"$VERSION_FILE")"
[[ "$EXPECTED_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail "expected version must use semantic version format"
[[ "$VERSION" == "$EXPECTED_VERSION" ]] \
  || fail "expected version $EXPECTED_VERSION does not match VERSION ($VERSION)"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail "repository is not a Git work tree"

if [[ -n "$(git ls-files 'dist/**' '*.app' '*.dmg' '*.zip')" ]]; then
  fail "build or release artifacts must not be tracked by Git"
fi
git check-ignore -q "$ARCHIVE_PATH" \
  || fail "release archive path is not ignored by Git"

if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
  fail "Git work tree must be clean before release validation"
fi

if git rev-parse -q --verify "refs/tags/$TAG_NAME" >/dev/null; then
  fail "local tag already exists: $TAG_NAME"
fi

set +e
REMOTE_TAG_OUTPUT="$(git ls-remote --exit-code --tags origin "refs/tags/$TAG_NAME" 2>&1)"
REMOTE_TAG_STATUS=$?
set -e

case "$REMOTE_TAG_STATUS" in
  0)
    fail "remote tag already exists: $TAG_NAME"
    ;;
  2)
    ;;
  *)
    echo "$REMOTE_TAG_OUTPUT" >&2
    fail "could not verify remote tag availability"
    ;;
esac

for readme in README.md README.en.md; do
  grep -Fq "releases/download/$TAG_NAME/$ARCHIVE_NAME" "$readme" \
    || fail "$readme does not link to $ARCHIVE_NAME"
  grep -Fq "releases/download/$TAG_NAME/$CHECKSUM_NAME" "$readme" \
    || fail "$readme does not link to $CHECKSUM_NAME"
done

grep -Fq "未经 Apple 公证" README.md \
  || fail "README.md must state that the preview is not notarized"
grep -Fq "not notarized" README.en.md \
  || fail "README.en.md must state that the preview is not notarized"

grep -Eq "^## \\[$EXPECTED_VERSION\\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md \
  || fail "CHANGELOG.md does not contain a dated $EXPECTED_VERSION release section"

"$ROOT_DIR/script/package_release.sh" "$EXPECTED_VERSION"

[[ -s "$ARCHIVE_PATH" ]] || fail "release archive was not created"
[[ -s "$CHECKSUM_PATH" ]] || fail "checksum file was not created"

(
  cd "$RELEASE_DIR"
  shasum -a 256 -c "$CHECKSUM_NAME"
)

CHECKSUM_HASH="$(awk 'NR == 1 { print $1 }' "$CHECKSUM_PATH")"
[[ "$CHECKSUM_HASH" =~ ^[0-9a-f]{64}$ ]] \
  || fail "checksum file does not contain a SHA-256 digest"
[[ "$(awk 'NR == 1 { print $2 }' "$CHECKSUM_PATH")" == "$ARCHIVE_NAME" ]] \
  || fail "checksum file references the wrong archive"

VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codexusagebar-release-check.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR"' EXIT
ditto --norsrc -x -k "$ARCHIVE_PATH" "$VERIFY_DIR"

EXTRACTED_APP="$VERIFY_DIR/$APP_NAME.app"
INFO_PLIST="$EXTRACTED_APP/Contents/Info.plist"
APP_BINARY="$EXTRACTED_APP/Contents/MacOS/$APP_NAME"

[[ -d "$EXTRACTED_APP" ]] || fail "archive does not contain $APP_NAME.app"
[[ -x "$APP_BINARY" ]] || fail "archive does not contain an executable app binary"
plutil -lint "$INFO_PLIST"

SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
[[ "$SHORT_VERSION" == "$EXPECTED_VERSION" ]] \
  || fail "CFBundleShortVersionString is $SHORT_VERSION, expected $EXPECTED_VERSION"
[[ "$BUNDLE_VERSION" == "$EXPECTED_VERSION" ]] \
  || fail "CFBundleVersion is $BUNDLE_VERSION, expected $EXPECTED_VERSION"

[[ "$(lipo -archs "$APP_BINARY")" == "$ARCHITECTURE" ]] \
  || fail "extracted binary is not exactly $ARCHITECTURE"
file "$APP_BINARY" | grep -Fq "Mach-O 64-bit executable arm64" \
  || fail "extracted binary is not an arm64 Mach-O executable"

codesign --verify --deep --strict --verbose=2 "$EXTRACTED_APP"
SIGNING_INFO="$(codesign -dvvv "$EXTRACTED_APP" 2>&1)"
grep -Fq "Signature=adhoc" <<<"$SIGNING_INFO" \
  || fail "preview app is not ad hoc signed as expected"

echo
echo "release validation passed"
echo "version: $EXPECTED_VERSION"
echo "architecture: $ARCHITECTURE"
echo "signing: ad hoc (not notarized)"
echo "archive: $ARCHIVE_PATH"
echo "checksum: $CHECKSUM_PATH"
echo "sha256: $CHECKSUM_HASH"
