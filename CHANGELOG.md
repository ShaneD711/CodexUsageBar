# Changelog

All notable changes to CodexUsageBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

