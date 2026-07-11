# CodexUsageBar

[English](README.md) | [简体中文](README.zh-CN.md)

A lightweight, local, and focused macOS menu bar app for checking Codex usage at a glance.

## Core Idea

CodexUsageBar makes checking Codex usage as easy as checking your Mac battery.

The MVP displays the five-hour usage window directly in the menu bar:

```text
75% 16:57
```

- `75%`: Remaining usage in the five-hour Codex window.
- `16:57`: Reset time for the five-hour window.

Clicking the menu bar item shows both usage windows:

```text
Usage Remaining
5 hours    75%   16:57
1 week     97%   Jul 18
```

## MVP Scope

The first version includes:

- Codex support only.
- Five-hour remaining usage and reset time in the menu bar.
- Five-hour and weekly usage in the popover.
- Refresh status and clear failure states.
- Local data access through Codex app-server.

The first version intentionally excludes:

- Total token analytics.
- Token activity heatmaps.
- Plugin rankings.
- Skill usage analytics.
- Daily task dashboards.
- Claude Code support.
- Account switching.
- A full dashboard window.
- Cloud synchronization.
- Reading `~/.codex/auth.json`.
- Uploading usage data.

## Data Source

CodexUsageBar uses the local Codex app-server JSON-RPC protocol:

```text
codex app-server
account/rateLimits/read
```

The app only reads rate limit data and does not upload usage data.

## Current Status

The first runnable MVP is complete:

- The menu bar displays five-hour remaining usage and reset time.
- The popover displays five-hour and weekly usage.
- Usage refreshes at launch, when the popover opens, and every five minutes.
- Usage refreshes immediately after the Mac wakes from sleep.
- The last successful snapshot remains visible when a refresh fails.
- Snapshots older than ten minutes display a warning in the menu bar and popover.
- JSON-RPC response parsing is covered by tests.

Design documents:

- [MVP design specification](docs/superpowers/specs/2026-07-11-codex-usage-menu-bar-design.md)
- [MVP 设计文档](docs/superpowers/specs/2026-07-11-codex-usage-menu-bar-design.zh-CN.md)

## Requirements

- macOS 14 or later.
- Xcode 16 or later.
- ChatGPT/Codex installed and signed in on the same Mac.

The project uses Swift, SwiftUI, and Swift Package Manager with no third-party dependencies.

## Run with Xcode

1. Open Xcode.
2. Select `File > Open`.
3. Open `Package.swift` from the project root.
4. Select the `CodexUsageBar` scheme and `My Mac` as the destination.
5. Click Run or press `Command + R`.

The app has no main window or Dock icon. After launch, find it in the macOS menu bar.

## Run from Terminal

Build, create a local `.app` bundle, and launch it:

```bash
./script/build_and_run.sh
```

Run tests:

```bash
swift test
```

The local app bundle is created at:

```text
dist/CodexUsageBar.app
```

## App Icon

The tracked icon assets are located at:

```text
Sources/CodexUsageBar/Resources/AppIcon.png
Sources/CodexUsageBar/Resources/AppIcon.icns
```

Regenerate both files from the code-defined design:

```bash
swift script/generate_app_icon.swift
```

The build script stops with a clear error when `AppIcon.icns` is missing, preventing a blank application icon from being packaged.

## Privacy

CodexUsageBar only requests rate limit data through the local `codex app-server`. It does not read `~/.codex/auth.json`, inspect conversation content, or upload usage data.

## Disclaimer

CodexUsageBar is an unofficial local utility and is not affiliated with OpenAI. It uses the local Codex app-server protocol, which may change in future Codex releases.
