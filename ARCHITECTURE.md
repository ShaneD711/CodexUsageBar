# Architecture

CodexUsageBar is a small macOS menu bar utility. Its product boundary is to show the current Codex usage windows with minimal interaction.

## System Flow

```text
Codex executable
  -> app-server over stdio
  -> CodexAppServerClient
  -> RateLimitSnapshot
  -> UsageStore
  -> UsageAvailability
  -> MenuBarPresentationBuilder
  -> MenuBarLabelView and UsagePopoverView
```

The app launches `codex app-server --stdio`, completes the required protocol initialization, checks account availability, and reads rate limits. It does not implement its own Codex authentication.

The protocol boundary is conservative. Unknown fields are ignored, but selected quota windows replace the current snapshot only after all required values pass exact type, range, and semantic validation. Weekly-only, short-window-only, reordered, and unknown-duration responses normalize into the same non-optional-primary domain model.

## Responsibilities

- `CodexAppServerClient` owns process launch, strict JSON-RPC framing, the shared request deadline, structured account and rate-limit parsing, and child-process cancellation.
- `UsageStore` owns the latest snapshot, local cache, refresh scheduling, wake refreshes, stale-state updates, and latest-generation-wins commits.
- `UsageAvailability` maps store facts into stable business states without absorbing transport error details.
- `UsageFailure` retains privacy-safe transport context: category, phase, optional server code, and optional stable response-change reason.
- `MenuBarPresentationBuilder` converts snapshot, availability, localization, and display mode into final status-item text, width, tooltip, and accessibility copy.
- SwiftUI views render presentation data and issue user commands. They do not parse app-server responses.
- Release scripts build and validate artifacts. They do not publish releases or mutate Git history.

## Refresh and Cache

The app refreshes at launch, when the popover opens, every five minutes, and after system wake. A new refresh cancels the previous active read and increments a generation. Only the latest generation may update state or cache.

The last successful `RateLimitSnapshot` is stored in `UserDefaults`. Failed refreshes preserve that snapshot. Decoded cache entries must pass the same semantic window invariants as fresh responses; invalid cache data is removed. Data older than ten minutes is marked stale but remains visible.

## Product Boundaries

The following are intentionally out of scope unless a future design explicitly changes the product:

- conversation, prompt, session, or project-file access;
- token-history dashboards or long-term analytics;
- remote telemetry, analytics, or cloud synchronization;
- alternate quota providers or account management;
- a large settings window or multi-level appearance system;
- a persistent app-server connection or notification stream.

Changes to data access, cache contents, diagnostics, networking, or distribution must also update [SECURITY.md](SECURITY.md), [DISTRIBUTION.md](DISTRIBUTION.md), and relevant tests.
