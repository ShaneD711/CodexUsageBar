# Contributing

CodexUsageBar favors small, reviewable changes that preserve its menu-bar-only scope and local privacy boundary.

## Development

Requirements:

- macOS 14 or later;
- a current Xcode command-line toolchain;
- Swift Package Manager;
- ChatGPT/Codex installed and signed in for live usage testing.

Common commands:

```bash
swift test
swift build --configuration release --arch arm64
./script/build_and_run.sh --verify
```

## Change Boundaries

Contributions should stay focused on current usage visibility, reliability, accessibility, localization, packaging, and narrowly related maintenance.

Do not add conversation access, prompt access, long-term usage history, remote telemetry, analytics, cloud synchronization, or unrelated dashboard features without an accepted design that updates the product and security boundaries.

Reuse the existing layers:

- transport and parsing in Services;
- business state and cache policy in Stores and Models;
- final menu bar output in `MenuBarPresentationBuilder`;
- rendering and commands in Views.

Views must not parse raw app-server responses or infer errors from human-readable server messages.

## Tests and UI

- Add focused tests for changed behavior and broader tests for shared state or transport changes.
- Run `swift test` and an arm64 Release build before submitting.
- Keep menu bar widths stable within a display mode.
- Follow native macOS typography, spacing, controls, accessibility labels, and system locale formatting.
- Preserve Simplified Chinese and English UI behavior. Traditional Chinese currently falls back to English.

## Privacy and Documentation

Changes to app-server methods, local storage, diagnostics, networking, executable discovery, signing, packaging, or release automation must update the relevant long-term document:

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [SECURITY.md](SECURITY.md)
- [DISTRIBUTION.md](DISTRIBUTION.md)

Never include credentials, private keys, raw account responses, private diagnostics, or machine-specific absolute paths in commits or tests.

## Git and Releases

- Do not commit `.build`, `dist`, app bundles, ZIP archives, or checksums.
- Keep unrelated working-tree changes intact.
- Use descriptive commits and submit a focused pull request.
- Update `VERSION`, release README links, and the dated changelog only during release preparation.
- Release scripts must not push, tag, or create GitHub Releases.
- Run `./script/release_check.sh X.Y.Z` before publishing a release.

## Pull Request Checklist

- The change stays within the documented product boundary.
- Tests cover the new or changed behavior.
- `swift test` and the Release build pass.
- User-visible copy is localized where required.
- Security and privacy implications were reviewed.
- Long-term documents were updated when their contracts changed.
- No generated artifacts, secrets, or local paths are included.

