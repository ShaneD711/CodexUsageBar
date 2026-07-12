# Changelog

All notable changes to CodexUsageBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add GitHub Actions CI for shell validation, Swift tests, and arm64 release builds on pushes and pull requests.

## [0.1.1] - 2026-07-12

### Added

- Add Simplified Chinese and English UI that follows the preferred macOS language.
- Add distinct messages for missing Codex, signed-out accounts, timeouts, unsupported responses, launch failures, and service errors.
- Show the app version and add commands to reveal the running app copy and copy privacy-safe diagnostics.
- Add automated coverage for localization, executable resolution, error mapping, diagnostics privacy, and repository version format.

### Changed

- Make Chinese the default README, add direct release downloads and real usage screenshots, and focus the project introduction on the repeated Codex usage-checking workflow.
- Use the root `VERSION` file as the version source for development and release application bundles.
- Replace the two-line icon header with a compact, single-line usage title.
- Align popover typography, control sizes, and section spacing with native macOS semantic styles.

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

- Keep the five-hour remaining percentage and reset time together in the menu bar so macOS does not compress the time out of view.
