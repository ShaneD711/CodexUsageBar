# Usage Window Duration Labeling Design

[English](2026-07-12-window-duration-labeling-design.md) | [简体中文](2026-07-12-window-duration-labeling-design.zh-CN.md)

Date: 2026-07-12

## Problem

The UI previously labeled `primary` as five hours and `secondary` as one week. If the API changes order or duration, quota values could remain correct while their titles become wrong. The menu bar and reset formatting also implicitly assumed primary was the short window.

## Design

- `RateLimitSnapshot.windows` exposes every currently parsed window as an array without changing the Codable storage schema.
- The popover iterates over `windows` and does not derive titles from primary/secondary position.
- 300 minutes displays as five hours and 10,080 minutes displays as one week.
- Other whole-day durations display days, other whole-hour durations display hours, and remaining values display minutes.
- English output handles singular and plural units; minute fallback uses compact `min`.
- The menu bar prefers a 300-minute window and falls back to primary when none exists, preserving compatibility.
- Windows shorter than 24 hours display a reset time; windows of 24 hours or more display a reset date.

## Boundary

The current app-server response model explicitly exposes only primary and secondary. This design correctly labels, orders, and displays every currently parsed window and prepares the UI for a future array model, but it does not guess an undefined third-window field.

## Tests

- Cover known five-hour and one-week titles.
- Cover eight-hour, fourteen-day, and ninety-minute fallbacks.
- Cover English singular and plural units.
- Cover menu-bar selection when primary/secondary order is reversed.
- Cover primary fallback for unknown durations.
- Cover time formatting for short windows and date formatting for long windows.
