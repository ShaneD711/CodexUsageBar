# CodexUsageBar MVP Design Specification

[English](2026-07-11-codex-usage-menu-bar-design.md) | [简体中文](2026-07-11-codex-usage-menu-bar-design.zh-CN.md)

Date: 2026-07-11

## Product Goal

Build a focused macOS menu bar app that lets Codex users check remaining usage as easily as they check their Mac battery.

The app removes a repetitive workflow: opening Codex, navigating through the sidebar or profile settings, and locating the usage section whenever the user wants to check their limits.

## MVP Scope

The MVP supports Codex only and does not include a dashboard window.

The menu bar displays:

```text
75% 16:57
```

- `75%`: Remaining usage in the five-hour Codex window.
- `16:57`: Reset time for the five-hour window.

Clicking the menu bar item opens:

```text
Codex

Usage Remaining
5 hours    75%   16:57
1 week     97%   Jul 18

Updated just now
```

The app prioritizes glanceability. Clicking is optional and only reveals weekly usage and refresh status.

## Explicit Non-Goals

The MVP does not include:

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

The app communicates with the local Codex app-server over stdio using JSON-RPC:

1. Start `codex app-server`.
2. Send `initialize` with `capabilities.experimentalApi = true`.
3. Send `initialized`.
4. Call `account/rateLimits/read`.

Prefer `rateLimitsByLimitId.codex`. Fall back to `rateLimits` when that entry is unavailable.

Window mapping:

- `primary`: Five-hour window.
- `secondary`: Weekly window.

Display mapping:

- Remaining percentage = `100 - usedPercent`.
- Reset time = formatted `resetsAt`.
- Window name = derived from `windowDurationMins`.

## Refresh Strategy

Refresh usage at these times:

- Once at launch.
- Whenever the popover opens.
- Every five minutes in the background.
- Immediately after the Mac wakes from sleep.
- When the user manually clicks refresh.

The menu bar value must not flicker during refresh. Keep displaying the last successful snapshot until new data is available.

If the last successful snapshot is more than ten minutes old, keep the cached value visible but add a warning icon in the menu bar. The popover must state that the data may be stale and show when it was last updated.

## Failure States

Failure states must be clear without interrupting the user.

When Codex cannot be found:

```text
--% --
```

Popover message: `Codex was not found. Install ChatGPT/Codex first.`

When Codex is not signed in:

```text
--% --
```

Popover message: `Codex is not signed in. Open Codex and sign in.`

When refresh fails but cached data exists:

```text
75% ⚠︎ 16:57
```

Popover message: `Data may be stale · Updated 12 minutes ago. The latest refresh failed.`

When refresh fails and no cached data exists:

```text
--% --
```

Popover message: `Unable to read Codex usage.`

## Privacy Model

The MVP runs locally.

The app should:

- Start or connect to the local Codex app-server.
- Request account rate limit data only.
- Cache only the last successful display snapshot when needed.

The app must not:

- Read authentication tokens.
- Call private ChatGPT web endpoints directly.
- Upload usage data.
- Read session transcripts.
- Parse prompts or tool content.

## Open Source Positioning

Project description:

```text
A lightweight local macOS menu bar app for checking Codex usage at a glance.
```

Required disclaimer:

```text
CodexUsageBar is an unofficial local utility and is not affiliated with OpenAI. It uses the local Codex app-server protocol, which may change in future Codex releases.
```

## Success Criteria

The MVP succeeds when:

- Users can see five-hour remaining usage and reset time without opening Codex.
- Clicking the menu bar item shows both the five-hour and weekly windows.
- The app does not read `auth.json`.
- The app remains focused and does not become a usage analytics dashboard.
- Failure states are understandable and preserve the last successful data when possible.
