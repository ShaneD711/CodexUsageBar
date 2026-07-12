# CodexUsageBar

[简体中文](README.md) | [English](README.en.md)

A lightweight, local macOS menu bar app that makes checking remaining Codex usage as easy as checking your battery.

## Download

**[Download v0.1.1 for macOS Apple Silicon](https://github.com/ShaneD711/CodexUsageBar/releases/download/v0.1.1/CodexUsageBar-v0.1.1-macos-arm64.zip)**

[SHA-256 checksum](https://github.com/ShaneD711/CodexUsageBar/releases/download/v0.1.1/CodexUsageBar-v0.1.1-macos-arm64.zip.sha256) · [View all releases](https://github.com/ShaneD711/CodexUsageBar/releases)

> `v0.1.1` is an unnotarized preview for Apple Silicon Macs running macOS 14 or later. The first launch requires manual approval in System Settings > Privacy & Security.

## Why This App Exists

Checking remaining usage in Codex requires opening the sidebar, clicking the username at the bottom, and then opening Usage Remaining. For users who monitor token consumption frequently, repeating this flow interrupts work and can amplify usage anxiety.

CodexUsageBar puts the five-hour remaining percentage and reset time directly in the Mac menu bar. You can stay focused and check usage with a glance.

## See It in Action

### Usage at a Glance

The menu bar shows the five-hour remaining percentage and reset time without opening Codex settings.

<img src="docs/images/menu-bar-usage.png" alt="CodexUsageBar remaining usage in the menu bar" width="132">

### Full Usage Details

Click the menu bar item to see both the five-hour and weekly usage windows.

<img src="docs/images/usage-popover.png" alt="CodexUsageBar usage details popover" width="320">

## Features

- Shows the five-hour remaining percentage and reset time in the menu bar.
- Shows five-hour and weekly remaining usage in the popover.
- Refreshes at launch, when the popover opens, every five minutes, and after Mac wake.
- Keeps the last successful snapshot when refresh fails and warns after ten minutes.
- Follows the macOS language in Simplified Chinese or English and distinguishes missing, signed-out, and timed-out states.
- Uses a compact single-line header with native macOS typography, control sizing, and layout spacing.
- Reveals the running app copy in Finder and copies diagnostics without account or quota data.
- Reads and caches usage locally without uploading usage or conversation data.

## Install

1. Download and extract `CodexUsageBar-v0.1.1-macos-arm64.zip`.
2. Move `CodexUsageBar.app` to `/Applications`.
3. Try to open CodexUsageBar once.
4. Open `System Settings > Privacy & Security`, find CodexUsageBar, and click `Open Anyway`.
5. Confirm the warning, then find CodexUsageBar in the macOS menu bar.

Company- or school-managed Macs may prevent this override. A newly downloaded version may need approval again. Read [Apple's guidance for opening an app from an unknown developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) before deciding whether to continue.

### Verify the Download

Place the ZIP and checksum file in the same folder, then run:

```bash
shasum -a 256 -c CodexUsageBar-v0.1.1-macos-arm64.zip.sha256
```

Expected output:

```text
CodexUsageBar-v0.1.1-macos-arm64.zip: OK
```

### Uninstall

Quit CodexUsageBar and move `/Applications/CodexUsageBar.app` to the Trash. To also clear its local cache, run:

```bash
defaults delete com.shaned.CodexUsageBar
```

## Development

Requirements: macOS 14 or later, Xcode 16 or later, and ChatGPT/Codex installed and signed in.

The project uses Swift, SwiftUI, and Swift Package Manager with no third-party dependencies.

```bash
# Build and launch the development app
./script/build_and_run.sh

# Run tests
swift test

# Create a release archive (version comes from VERSION)
./script/package_release.sh
```

## Privacy

CodexUsageBar only requests and caches remaining usage on the local Mac. It does not inspect conversation content, read `~/.codex/auth.json`, or upload usage data.

## License

CodexUsageBar is available under the [MIT License](LICENSE).

## Disclaimer

CodexUsageBar is an unofficial local utility and is not affiliated with OpenAI. Codex's local interface may change in future releases.
