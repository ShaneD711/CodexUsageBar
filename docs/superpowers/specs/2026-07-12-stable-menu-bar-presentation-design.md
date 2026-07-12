# Stable Menu-Bar Presentation

## Scope

CodexUsageBar will provide two menu-bar display modes while keeping the app menu-bar-only and lightweight. The label must not change width when percentages, reset times, loading state, or stale state change within the selected mode.

The feature does not add a settings window, additional usage sources, or codexU-style multi-level appearance presets.

## Display Modes

- **Standard** is the default and preserves the current product behavior: `81% 16:35`.
- **Compact** shows only the remaining percentage: `81%`.

The selected mode is persisted in `UserDefaults`. An unknown stored value falls back to Standard.

The existing More menu contains a `Menu Bar Display` picker with Standard and Compact options. Changing the option updates the real menu-bar label immediately.

## Availability Model

`UsageAvailability` is derived from the store's snapshot, freshness, refresh activity, and stable failure category. It distinguishes loading, fresh data, stale data, signed-out state, missing Codex, incompatible responses, and temporary unavailability.

A present snapshot always wins over a refresh failure and remains fresh or stale. `isRefreshing` and `UsageFailure` remain separate so availability does not absorb transport details, phases, or server codes. The menu bar, popover empty state, refresh-button availability, and diagnostics consume the same business state.

## Refresh Generation

Refreshes follow a latest-request-wins policy. Every manual, scheduled, or wake-triggered refresh increments a lightweight generation and cancels the previous active read. Success, failure, cancellation cleanup, cache writes, and refresh-indicator updates are committed only when the request generation still matches the store's latest generation.

`stop()` increments the generation and cancels the active read, preventing late results from writing after shutdown. Superseded cancellation is not exposed as a user-facing failure. Session-level generations remain out of scope until a long-lived app-server connection or notification stream is introduced.

## Shared Presentation Model

The status item follows one lightweight pipeline:

`UsageStore -> UsageAvailability -> MenuBarPresentationBuilder -> MenuBarPresentation -> MenuBarLabelView`

The builder derives a complete presentation from the latest snapshot, stale state, selected mode, and localization. `MenuBarPresentation` is the label's only rendering input and contains:

- final display text;
- stale-warning visibility;
- tooltip;
- accessibility label;
- selected mode.

The view only draws the text and applies the supplied tooltip and accessibility label. It does not interpret quota values or assemble state copy. Any future settings preview must consume the same presentation type instead of rebuilding display strings.

## Missing and Stale Data

- Missing data is represented explicitly and is never converted to zero.
- Standard mode shows `--% --`.
- Compact mode shows `--%`.
- A refresh failure preserves the latest successful snapshot through the existing store behavior.
- Stale data keeps its last values and shows the warning symbol.

## Stable Width

The presentation builder supplies a minimal fixed label width for each layout:

- Compact uses one centered width sized for percentages through `100%` and the stale marker;
- Standard uses a centered short-time width for common 24-hour output and a wider bucket for longer 12-hour output;
- display text contains no invisible left or right placeholders, keeping the visible content optically centered.

Digits use monospaced digit spacing. The fixed content width is intentionally minimal, with macOS adding its native status-item padding around it. Switching modes intentionally changes the menu-bar item's width, but normal refreshes and value changes within one mode do not.

The reset-time region must accommodate the normal short-time output of the user's automatically updating system locale, including common 12-hour and 24-hour forms. Long output is truncated rather than resizing the menu-bar item.

## Localization

The mode picker uses the existing Simplified Chinese and English localization system. Displayed dates and times continue to follow the system region rather than the UI language.

## Tests

Automated tests cover:

- Standard as the default mode;
- invalid persisted values falling back to Standard;
- Standard and Compact strings for available data;
- `--% --` and `--%` for missing data;
- missing data never becoming `0%`;
- stale values remaining visible while the warning is enabled;
- stable rendered widths across percentage and warning-state changes;
- localized tooltip and accessibility output from the presentation builder;
- stable availability mapping with cached-snapshot priority;
- diagnostics reporting availability alongside the underlying failure category, phase, and code;
- latest refresh results winning over late success or failure from superseded generations;
- active refresh cancellation and `stop()` invalidation;
- both display modes using the same presentation model.

Visual verification checks that changing percentages, reset times, and stale state does not move adjacent menu-bar content within the selected mode.
