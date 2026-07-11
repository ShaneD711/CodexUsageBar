# CodexUsageBar Unnotarized Preview Release Design

## Overview

CodexUsageBar will publish its first downloadable build as `v0.1.0 Unnotarized Preview` through GitHub Releases. The release is intended for early technical users who understand that macOS will require a one-time manual security override.

The release remains outside the Mac App Store and does not require an Apple Developer Program membership. It is not signed with a Developer ID certificate and is not notarized by Apple.

## Goals

- Provide a reproducible Apple Silicon release build that users can download without installing Xcode.
- Package a valid macOS application bundle as a ZIP archive.
- Apply an ad hoc signature to seal the bundle while clearly avoiding any claim of Apple trust or notarization.
- Publish a SHA-256 checksum alongside the archive.
- Document installation, manual Gatekeeper override, removal, privacy, and support limitations in English and Chinese.
- Add an MIT License so the repository is explicitly open source.

## Non-Goals

- Mac App Store distribution.
- Developer ID signing or Apple notarization.
- Intel Mac support.
- A DMG or PKG installer.
- Automatic GitHub Actions releases.
- Automatic updates.

## Supported Environment

- Version: `0.1.0`
- Product label: `Unnotarized Preview`
- macOS: 14 or later
- Architecture: Apple Silicon (`arm64`) only
- Prerequisite: ChatGPT/Codex installed and signed in on the same Mac
- License: MIT

## Release Artifacts

The release packaging script will generate these ignored local artifacts under `dist/release/`:

```text
CodexUsageBar-v0.1.0-macos-arm64.zip
CodexUsageBar-v0.1.0-macos-arm64.zip.sha256
```

The ZIP archive will contain `CodexUsageBar.app`. The checksum file will contain the SHA-256 digest and archive filename. The unpacked app is assembled and signed in a temporary staging directory so Finder or file-provider metadata cannot alter the bundle before packaging.

## Packaging Flow

A new `script/package_release.sh` command will accept the version as an argument:

```bash
./script/package_release.sh 0.1.0
```

The script will:

1. Validate that the version matches a numeric `major.minor.patch` format.
2. Run the Swift test suite.
3. Build the executable in release mode for `arm64`.
4. Create a clean `CodexUsageBar.app` bundle in a temporary staging directory.
5. Copy the release executable and tracked icon into the bundle.
6. Generate `Info.plist` with the bundle identifier, application name, minimum macOS version, menu-bar-only behavior, short version, and build version.
7. Apply an ad hoc signature to the complete application bundle.
8. Verify the bundle signature and executable architecture.
9. Create the ZIP while preserving the application structure and executable permissions but excluding unnecessary extended attributes.
10. Extract the ZIP and verify the packaged signature again.
11. Generate the SHA-256 checksum file.

The existing `script/build_and_run.sh` remains the development build-and-launch entrypoint and will not become the release packager.

## Signing and Trust Model

The preview bundle will use an ad hoc signature only. This seals the current bundle contents but does not identify the publisher to Apple and does not satisfy Gatekeeper as an identified developer.

Documentation and release notes must state:

- The app is not signed with Apple Developer ID.
- The app is not notarized by Apple.
- macOS will likely block the first launch.
- Users must decide whether they trust the GitHub repository and checksum before manually allowing the app.

No documentation may describe the preview as signed, verified, trusted, or approved by Apple.

## Installation Flow

The documented user flow will be:

1. Download the ZIP and checksum from the GitHub Release.
2. Optionally verify the SHA-256 checksum.
3. Extract `CodexUsageBar.app`.
4. Move the app to `/Applications`.
5. Attempt to open it once.
6. Open `System Settings > Privacy & Security` and select `Open Anyway` for CodexUsageBar.
7. Confirm the warning and enter the Mac login password if requested.
8. Find CodexUsageBar in the macOS menu bar.

The documentation will note that managed company or school Macs may prevent this override and that a newly downloaded version may require approval again.

## Documentation Changes

- Add the MIT `LICENSE` file.
- Add download and installation sections to `README.md` and `README.zh-CN.md`.
- Add checksum verification instructions using `shasum -a 256 -c`.
- Add an uninstall section that removes `CodexUsageBar.app` and optionally clears its `UserDefaults` cache with `defaults delete com.shaned.CodexUsageBar`.
- Add a visible unnotarized preview warning.
- Move the current changelog entries into a dated `0.1.0` release section.
- Include manual GitHub Release title and notes for the repository owner.

## Validation

Before upload, the release must pass:

- `swift test`
- Release build success
- `file` or `lipo` confirms `arm64`
- `plutil -lint` validates `Info.plist`
- `codesign --verify --deep --strict` succeeds for the ad hoc signature
- The app extracted from the ZIP also passes strict signature verification
- The ZIP contains no `__MACOSX` or `._` AppleDouble metadata entries
- The ZIP expands to exactly one usable `CodexUsageBar.app`
- The checksum verifies against the generated ZIP
- The packaged app launches on the development Mac and reads Codex usage

Gatekeeper acceptance is explicitly not a success criterion because the preview is not Developer ID signed or notarized.

## Manual GitHub Release

After the implementation is committed and pushed, the repository owner will:

1. Create tag `v0.1.0` from the verified release commit.
2. Create a GitHub Release named `CodexUsageBar v0.1.0 - Unnotarized Preview`.
3. Upload the ZIP and SHA-256 files.
4. Paste the prepared release notes.
5. Mark the release as a pre-release.

The build artifacts remain excluded from Git; only the source, scripts, license, and documentation are committed.
