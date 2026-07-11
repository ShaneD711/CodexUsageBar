# CodexUsageBar App Icon Design

[English](2026-07-11-app-icon-design.md) | [简体中文](2026-07-11-app-icon-design.zh-CN.md)

Date: 2026-07-11

## Goal

Replace the blank macOS application icon with a polished native-style icon that represents the two Codex usage windows without resembling a battery monitor or analytics dashboard.

This change affects the Finder icon, Get Info panel, and packaged application metadata. It does not change the menu bar label or add a symbol next to the usage percentage.

## Selected Direction

The selected visual direction is **Usage Window**, the third option from the Apple-native concept round.

The icon uses:

- A light gray-white macOS rounded-square plate.
- A graphite utility-window outline.
- Two compact status bars inside the window.
- A blue primary bar for the five-hour usage window.
- A neutral gray secondary bar for the weekly usage window.
- Two small graphite window controls.

The icon must not contain letters, numbers, percentages, battery shapes, gauges, or branding copied from OpenAI or Apple.

## Visual Tokens

- Plate: `#FBFBFC`.
- Plate border: `#D5D8DD`.
- Window outline: `#30343A`.
- Primary usage bar: `#2F7EE6`.
- Secondary usage bar: `#B0B5BC`.
- Outer area: transparent.

Shadows should be soft and restrained. The icon must remain readable in both light and dark Finder appearances.

## Asset Requirements

- Create a `1024 x 1024` master PNG.
- Preserve a transparent area outside the rounded-square plate.
- Generate standard macOS iconset sizes from the master image.
- Package the iconset as `AppIcon.icns`.
- Store the tracked final asset at `Sources/CodexUsageBar/Resources/AppIcon.icns`.

The repository should track the final `.icns` asset and the master PNG used to regenerate it.

## Build Integration

Update `script/build_and_run.sh` to:

1. Require `Sources/CodexUsageBar/Resources/AppIcon.icns`.
2. Fail with a clear message when the icon is missing.
3. Create `Contents/Resources` in the staged application bundle.
4. Copy the icon to `Contents/Resources/AppIcon.icns`.
5. Add `CFBundleIconFile = AppIcon` to `Contents/Info.plist`.

No application runtime code is required for icon loading.

## Failure Handling

The build must stop before launch when the source icon is missing or empty. This prevents a successful-looking build from producing another blank application icon.

The application remains runnable from Xcode and the existing build script after the icon is added.

## Verification

The implementation is complete when:

- `AppIcon.icns` exists inside the staged application bundle.
- `Info.plist` contains `CFBundleIconFile = AppIcon`.
- The icon is visible in Finder and Get Info.
- The 16 px and 32 px renderings still show a recognizable window outline and two status bars.
- `swift test` continues to pass.
- `./script/build_and_run.sh --verify` builds and launches the application.
- The menu bar remains text-first and unchanged.
