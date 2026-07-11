# CodexUsageBar Unnotarized Preview Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a reproducible, ad hoc signed, unnotarized `v0.1.0` Apple Silicon ZIP release with a checksum, MIT License, bilingual installation documentation, and manual GitHub Release notes.

**Architecture:** Keep development launching in `script/build_and_run.sh` and add an isolated `script/package_release.sh` for release-mode packaging. The release script owns bundle assembly, version metadata, ad hoc signing, architecture verification, ZIP creation, and checksum generation; documentation owns the explicit Gatekeeper warning and manual installation flow.

**Tech Stack:** Swift 5.10, Swift Package Manager, Bash, macOS `codesign`, `plutil`, `lipo`, `ditto`, and `shasum`.

---

### Task 1: Add the MIT License

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Create the license file**

Use the standard MIT text with this copyright line:

```text
MIT License

Copyright (c) 2026 ShaneD711

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Verify the repository exposes the license**

Run:

```bash
head -3 LICENSE
git status --short
```

Expected: the output starts with `MIT License`, names `ShaneD711`, and shows `?? LICENSE`.

- [ ] **Step 3: Leave the change uncommitted**

Do not run `git commit`; the repository owner will commit and push after final review.

### Task 2: Add the Release Packager

**Files:**
- Create: `script/package_release.sh`
- Preserve: `script/build_and_run.sh`

- [ ] **Step 1: Create the packaging script**

Use this project-specific implementation:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexUsageBar"
BUNDLE_ID="com.shaned.CodexUsageBar"
MIN_SYSTEM_VERSION="14.0"
ARCHITECTURE="arm64"
VERSION="${1:-}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 <major.minor.patch>" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
SOURCE_ICON="$ROOT_DIR/Sources/CodexUsageBar/Resources/AppIcon.icns"
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
```

- [ ] **Step 2: Make the script executable**

Run:

```bash
chmod +x script/package_release.sh
```

Expected: `test -x script/package_release.sh` exits with status `0`.

- [ ] **Step 3: Validate shell syntax**

Run:

```bash
bash -n script/package_release.sh
```

Expected: no output and exit status `0`.

- [ ] **Step 4: Verify invalid versions fail before building**

Run:

```bash
./script/package_release.sh 0.1
```

Expected: exit status `2` and `usage: ... <major.minor.patch>` on stderr.

### Task 3: Document Download, Installation, and Removal

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`

- [ ] **Step 1: Add the English preview warning and installation section**

Insert before `## Requirements`:

```markdown
## Download and Install

The `v0.1.0` download is an **unnotarized Apple Silicon preview** for macOS 14 or later. It is not signed with an Apple Developer ID and has not been notarized by Apple.

1. Open [GitHub Releases](https://github.com/ShaneD711/CodexUsageBar/releases) and download `CodexUsageBar-v0.1.0-macos-arm64.zip`.
2. Extract the ZIP and move `CodexUsageBar.app` to `/Applications`.
3. Try to open CodexUsageBar once.
4. Open `System Settings > Privacy & Security`, find the blocked CodexUsageBar message, and click `Open Anyway`.
5. Confirm the warning and enter your Mac password if requested.

Company- or school-managed Macs may prevent this override. A newly downloaded version may need to be approved again.

### Verify the Download

Download the `.zip` and `.sha256` files into the same folder, then run:

```bash
shasum -a 256 -c CodexUsageBar-v0.1.0-macos-arm64.zip.sha256
```

Expected output:

```text
CodexUsageBar-v0.1.0-macos-arm64.zip: OK
```

### Uninstall

Quit CodexUsageBar and move `/Applications/CodexUsageBar.app` to the Trash. To also clear its last cached usage snapshot, run:

```bash
defaults delete com.shaned.CodexUsageBar
```
```

Also add links to both release design documents under `Design documents`, and add `MIT` to a new `## License` section before the disclaimer.

- [ ] **Step 2: Add the equivalent Chinese sections**

Use the same commands and filenames. The warning must say `v0.1.0` is an `未经 Apple 公证的 Apple Silicon 预览版`, and the Gatekeeper action must be documented as `系统设置 > 隐私与安全性 > 仍要打开`.

- [ ] **Step 3: Check bilingual consistency**

Run:

```bash
rg -n "v0.1.0|arm64|sha256|Open Anyway|仍要打开|MIT" README.md README.en.md
```

Expected: both files contain the version, architecture, checksum, override, and license information.

### Task 4: Prepare the Changelog and Release Notes

**Files:**
- Modify: `CHANGELOG.md`
- Create: `docs/releases/v0.1.0.md`

- [ ] **Step 1: Turn the changelog into a release record**

Keep an empty `## [Unreleased]` section, then add:

```markdown
## [0.1.0] - 2026-07-11

### Added

- Display five-hour remaining usage and reset time directly in the macOS menu bar.
- Show five-hour and weekly usage in the popover.
- Refresh usage at launch, when the popover opens, every five minutes, and after Mac wake.
- Preserve the last successful snapshot and warn when it is older than ten minutes.
- Read rate limits locally through `codex app-server` without reading `~/.codex/auth.json`.
- Add the CodexUsageBar application icon.
- Add an Apple Silicon release packager, SHA-256 checksum, and MIT License.

### Fixed

- Keep the five-hour percentage and reset time together so macOS does not compress the time out of view.
```

- [ ] **Step 2: Add manual GitHub Release notes**

Create `docs/releases/v0.1.0.md` with:

```markdown
# CodexUsageBar v0.1.0 - Unnotarized Preview

CodexUsageBar is a lightweight macOS menu bar utility for checking the remaining Codex five-hour and weekly usage windows at a glance.

## Download

Download `CodexUsageBar-v0.1.0-macos-arm64.zip` and the matching `.sha256` file below.

## Requirements

- macOS 14 or later
- Apple Silicon Mac
- ChatGPT/Codex installed and signed in

## Security Notice

This preview is ad hoc signed, not signed with Apple Developer ID, and not notarized by Apple. macOS will likely block the first launch. Follow the README installation instructions to review the warning and use `System Settings > Privacy & Security > Open Anyway` only if you trust this repository and the checksum.

## Highlights

- Five-hour remaining percentage and reset time in the menu bar
- Five-hour and weekly details in the popover
- Five-minute automatic refresh and wake-from-sleep refresh
- Stale-data warnings while preserving the last successful snapshot
- Local-only access through `codex app-server`

## SHA-256

Verify the download with:

```bash
shasum -a 256 -c CodexUsageBar-v0.1.0-macos-arm64.zip.sha256
```
```

- [ ] **Step 3: Verify the release documentation**

Run:

```bash
rg -n "0.1.0|Unnotarized|Apple Silicon|Open Anyway|SHA-256" CHANGELOG.md docs/releases/v0.1.0.md
```

Expected: release scope and warning are present with no claim of Apple approval.

### Task 5: Build and Validate the Preview Artifact

**Files:**
- Generated, ignored: `dist/release/CodexUsageBar-v0.1.0-macos-arm64.zip`
- Generated, ignored: `dist/release/CodexUsageBar-v0.1.0-macos-arm64.zip.sha256`

- [ ] **Step 1: Run the release packager**

Run:

```bash
./script/package_release.sh 0.1.0
```

Expected: all tests pass, signing verification succeeds, and both upload artifacts are printed.

- [ ] **Step 2: Inspect version, architecture, and signature**

Extract the ZIP to a temporary directory, then inspect it:

```bash
VERIFY_DIR="$(mktemp -d)"
ditto --norsrc -x -k dist/release/CodexUsageBar-v0.1.0-macos-arm64.zip "$VERIFY_DIR"
plutil -p "$VERIFY_DIR/CodexUsageBar.app/Contents/Info.plist"
lipo -archs "$VERIFY_DIR/CodexUsageBar.app/Contents/MacOS/CodexUsageBar"
codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/CodexUsageBar.app"
codesign -dvvv "$VERIFY_DIR/CodexUsageBar.app" 2>&1
```

Expected: version `0.1.0`, architecture `arm64`, `Signature=adhoc`, and no `TeamIdentifier`.

- [ ] **Step 3: Inspect the archive contents**

Run:

```bash
unzip -l dist/release/CodexUsageBar-v0.1.0-macos-arm64.zip
```

Expected: one `CodexUsageBar.app` containing `Contents/Info.plist`, `Contents/MacOS/CodexUsageBar`, and `Contents/Resources/AppIcon.icns`.

- [ ] **Step 4: Launch the packaged app**

Run:

```bash
pkill -x CodexUsageBar 2>/dev/null || true
open -n "$VERIFY_DIR/CodexUsageBar.app"
sleep 1
pgrep -fl CodexUsageBar
```

Expected: the process path points to the extracted `CodexUsageBar.app/Contents/MacOS/CodexUsageBar`.

- [ ] **Step 5: Perform final repository checks**

Run:

```bash
git diff --check
git status --short
```

Expected: only source-controlled license, script, documentation, and plan/spec files are listed; `dist/` artifacts remain ignored.

- [ ] **Step 6: Hand off commit and release instructions**

Do not commit, tag, push, or create the GitHub Release. Provide the repository owner with:

```text
Summary: release: prepare v0.1.0 unnotarized preview
```

After the owner commits and pushes, they create tag `v0.1.0`, create a pre-release named `CodexUsageBar v0.1.0 - Unnotarized Preview`, and upload the ZIP and `.sha256` files.
