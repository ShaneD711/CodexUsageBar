# Changelog

All notable changes to CodexUsageBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-07-12

### Added

- Add Standard and Compact menu bar display modes, with the selected mode preserved across launches.
- Add explicit `--%` and `--` placeholders when usage data is unavailable instead of presenting missing data as zero.
- Add a stable availability model for loading, fresh, stale, signed-out, missing-Codex, incompatible, and temporarily unavailable states.
- Add refresh generations so only the latest manual, scheduled, or wake-triggered request can update application state.
- Add a strict, non-publishing release validation script for metadata, tags, packaging, architecture, signing, extraction, and checksums.
- Add concise architecture, security, distribution, and contribution contracts for long-term project maintenance.

### Changed

- Keep percentage, reset time, and warning regions at stable widths so routine refreshes do not shift neighboring menu bar items.
- Keep the last successful values visible when data becomes stale, alongside the existing warning indicator.
- Route menu bar text, stale state, tooltip, and accessibility copy through a shared presentation builder and model that can also power future previews.
- Use the same availability state for menu-bar descriptions, popover empty states, refresh behavior, and privacy-safe diagnostics.
- Replace dropped concurrent refresh attempts with latest-request-wins cancellation and generation checks.

### Fixed

- Render the status item as one fixed-width text label so macOS keeps the Standard reset time visible and does not move the stale warning ahead of the percentage.

## [0.1.2] - 2026-07-12

### Added

- Add GitHub Actions CI for shell validation, Swift tests, and arm64 release builds on pushes and pull requests.
- Add broader automated coverage for refresh behavior, process exit, timeouts, cancellation, and account state.
- Detect signed-out accounts from structured account state instead of English error wording.

### Changed

- Make usage-window labels adapt to the actual window duration and order.
- Improve privacy-safe diagnostics with a stable category, request stage, and optional error code.
- Simplify the Chinese and English READMEs around download, installation, visible features, privacy, and uninstalling.

### Fixed

- Enforce one 15-second deadline across the complete app-server request and report closed output immediately instead of waiting for a timeout.
- Terminate the active app-server process when its reading task is cancelled, without surfacing cancellation as a user-facing failure.
- Limit Simplified Chinese UI selection to `zh-Hans`, `zh-CN`, and `zh-SG`; Traditional Chinese locales fall back to English until translated.
- Format reset dates and times with the user's automatically updating system locale in both the menu bar and popover.

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
