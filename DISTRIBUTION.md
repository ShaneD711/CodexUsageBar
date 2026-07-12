# Distribution

CodexUsageBar currently ships as an Apple Silicon ZIP archive for macOS 14 or later.

## Current Trust Model

- Release architecture: `arm64` only.
- Archive: `CodexUsageBar-vX.Y.Z-macos-arm64.zip`.
- Checksum: matching `.zip.sha256` file.
- Signature: ad hoc.
- Apple notarization: not performed.

The current signature verifies bundle integrity after packaging, but it does not establish a Developer ID identity and does not satisfy Apple notarization or Gatekeeper distribution policy.

## Scripts

- `script/build_and_run.sh` builds and launches a local development bundle.
- `script/package_release.sh X.Y.Z` runs tests, builds arm64 Release code, creates the app bundle, applies the ad hoc signature, creates the ZIP, extracts it for verification, and writes the checksum.
- `script/release_check.sh X.Y.Z` performs strict release-candidate checks around Git state, metadata, tag availability, packaging, versions, architecture, signing, extraction, and SHA-256.

These scripts must not push commits, create or overwrite tags, or create a GitHub Release.

## Release Preparation

1. Finish implementation and run normal CI.
2. Update `VERSION` only during release preparation.
3. Move release notes from `Unreleased` into a dated `CHANGELOG.md` section.
4. Update both README download and checksum links to the new version.
5. Commit all release-preparation changes so the work tree is clean.
6. Run `./script/release_check.sh X.Y.Z`.
7. Review the reported archive path and SHA-256.
8. Manually create the immutable tag and GitHub Release, then upload exactly the validated ZIP and checksum.

Never replace an existing remote tag or silently replace assets attached to an existing release.

## Developer ID and Notarization

Developer ID signing is not currently configured. When it is introduced, use a separate explicit release mode and add verification with `codesign`, `notarytool`, `stapler`, and `spctl`.

Signing identities must remain in the local Keychain. CI certificates, passwords, and notarization credentials must remain in GitHub Secrets or an equivalent secret store. Private keys and credentials must never be committed to the repository.

Do not claim an archive is notarized unless notarization succeeds, the ticket is stapled, and the final distributed artifact passes verification.

