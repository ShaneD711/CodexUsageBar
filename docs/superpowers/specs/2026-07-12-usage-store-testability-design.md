# UsageStore Testability Design

[English](2026-07-12-usage-store-testability-design.md) | [简体中文](2026-07-12-usage-store-testability-design.zh-CN.md)

Date: 2026-07-12

## Problem

`UsageStore` accepted a client and cache but still depended on concrete types, while its initializer immediately created background tasks and a system wake observer. Tests could not conveniently script failure/success sequences, blocked reads, concurrent refreshes, or cache states. `CachedUsageStore` also always used `UserDefaults.standard`, preventing isolated corrupted-cache tests.

## Design

- `CodexUsageReading` defines one asynchronous snapshot read.
- `UsageSnapshotCaching` defines synchronous snapshot loading and saving on the main actor, constraining UserDefaults access to one isolation domain.
- `CodexAppServerClient` and `CachedUsageStore` implement those protocols.
- `UsageStore` depends on the protocols and lets tests disable automatic startup and call `start/stop` explicitly.
- Executable resolution for diagnostics is injectable so tests do not inspect the developer's machine.
- `CachedUsageStore` accepts a specific `UserDefaults` instance and key.
- `CancellationError` does not populate `lastFailure`.

## Process Cancellation

`CodexAppServerClient` creates a thread-safe process controller for each read. Cancelling the parent task terminates that app-server child process; the closed pipe releases the blocked reader and the client ultimately throws `CancellationError`.

## Tests

- Cached data is visible immediately and replaced by a successful background refresh.
- A failed refresh preserves cached data and sets the failure category.
- A successful retry clears the failure and saves the new snapshot.
- Concurrent refresh calls invoke the reader only once.
- Store cancellation does not create a user-facing failure.
- Corrupted cache data returns nil.
- A real child process exiting early returns `connectionClosed` immediately.
- Continuous notifications still obey the total deadline.
- Cancelling a read terminates the real child process.

Early EOF represents a stopped service and maps to `service-stopped`; `unsupported-response` is reserved for a received response whose schema cannot be parsed.
