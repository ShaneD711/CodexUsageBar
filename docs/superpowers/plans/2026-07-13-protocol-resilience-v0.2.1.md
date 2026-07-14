# Protocol Resilience v0.2.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Codex usage parsing conservative and resilient so only semantically verified quota snapshots replace the last successful data.

**Architecture:** Keep process transport, domain state, and UI state separate. Add strict JSON-RPC envelope validation, custom account and quota payload parsers, shared `RateLimitSnapshot` semantic validation, and privacy-safe structured failure reasons while preserving the existing latest-generation-wins refresh flow.

**Tech Stack:** Swift 5.10, Foundation, Swift Concurrency, SwiftPM, XCTest, JSONSerialization.

---

### Task 1: Domain invariants and overflow-safe remaining usage

**Files:**
- Modify: `Sources/CodexUsageBar/Models/RateLimitSnapshot.swift`
- Test: `Tests/CodexUsageBarTests/RateLimitResponseParserTests.swift`

- [ ] Add tests proving percentages above 100 return zero without integer-conversion traps and invalid cached-window semantics are rejected.
- [ ] Run `swift test --filter RateLimitSnapshot` and confirm the new tests fail.
- [ ] Add shared window/snapshot semantic validation and clamp before converting `Double` to `Int`.
- [ ] Re-run the focused tests and confirm they pass.

### Task 2: Strict JSON-RPC envelope and structured transport errors

**Files:**
- Modify: `Sources/CodexUsageBar/Services/CodexAppServerClient.swift`
- Test: `Tests/CodexUsageBarTests/CodexAppServerDeadlineTests.swift`
- Test: `Tests/CodexUsageBarTests/CodexAppServerProcessTests.swift`

- [ ] Add tests for malformed JSON, non-object lines, malformed IDs, conflicting result/error keys, null results, unrelated responses, notifications, incompatible method errors, temporary server errors, EOF, deadline, and cancellation.
- [ ] Run the two focused test classes and confirm strict-envelope tests fail.
- [ ] Add `ResponseChangeReason`, phase-aware `incompatible` and `responseChanged` errors, and strict envelope classification in `readResponse`.
- [ ] Re-run the focused tests and confirm immediate failure, code retention, deadline, EOF, and cancellation behavior pass.

### Task 3: Conservative account and rate-limit payload parsing

**Files:**
- Modify: `Sources/CodexUsageBar/Services/CodexAppServerClient.swift`
- Test: `Tests/CodexUsageBarTests/RateLimitResponseParserTests.swift`
- Create: `Tests/CodexUsageBarTests/AccountResponseParserTests.swift`

- [ ] Add table tests for every account-state combination from the approved design.
- [ ] Add quota-selection tests for exact key, internal ID, ambiguity, top-level fallback, no fallback after selecting a damaged higher-priority set, primary-only, secondary-only, dual windows, swapped durations, and unknown durations.
- [ ] Add exact numeric coercion tests for JSON numbers and strings, booleans, invalid syntax, fractions, negative values, overflow, milliseconds, and distant-future bounds.
- [ ] Run the focused parser tests and confirm the new cases fail.
- [ ] Replace Codable DTO inference with small JSON object helpers that preserve missing/null/type distinctions and enforce the approved reason precedence.
- [ ] Normalize valid source windows into the existing required-primary domain model and re-run focused tests.

### Task 4: Cache protection and stable user states

**Files:**
- Modify: `Sources/CodexUsageBar/Stores/CachedUsageStore.swift`
- Modify: `Sources/CodexUsageBar/Models/UsageFailure.swift`
- Modify: `Sources/CodexUsageBar/Models/UsageAvailability.swift`
- Modify: `Sources/CodexUsageBar/Support/AppLocalization.swift`
- Modify: `Sources/CodexUsageBar/Support/AppSupport.swift`
- Test: `Tests/CodexUsageBarTests/CachedUsageStoreTests.swift`
- Test: `Tests/CodexUsageBarTests/UsageFailureTests.swift`
- Test: `Tests/CodexUsageBarTests/UsageAvailabilityTests.swift`
- Test: `Tests/CodexUsageBarTests/AppLocalizationTests.swift`
- Test: `Tests/CodexUsageBarTests/AppSupportTests.swift`

- [ ] Add tests that semantically invalid decodable cache entries are deleted, valid entries load, and response-change diagnostics contain only category, phase, code, and reason.
- [ ] Add tests distinguishing incompatible protocol, changed response shape, and temporary unavailability with and without a cached snapshot.
- [ ] Run focused tests and confirm failures.
- [ ] Map structured client errors into stable failure categories and availability states, localize the new response-changed state, and append the safe reason to diagnostics.
- [ ] Validate decoded cache through the shared domain invariant and delete rejected data.
- [ ] Re-run focused tests and confirm all state and privacy assertions pass.

### Task 5: Anonymized protocol fixtures and compatibility matrix

**Files:**
- Modify: `Package.swift`
- Create: `Tests/CodexUsageBarTests/Fixtures/account-signed-in.json`
- Create: `Tests/CodexUsageBarTests/Fixtures/account-signed-out.json`
- Create: `Tests/CodexUsageBarTests/Fixtures/rate-limits-dual-window.json`
- Create: `Tests/CodexUsageBarTests/Fixtures/rate-limits-weekly-only.json`
- Create: `Tests/CodexUsageBarTests/Fixtures/rate-limits-top-level.json`
- Create: `Tests/CodexUsageBarTests/Fixtures/rate-limits-unknown-fields.json`
- Create: `Tests/CodexUsageBarTests/ProtocolFixtureTests.swift`

- [ ] Configure `.process("Fixtures")` and add a fixture loader using `Bundle.module`.
- [ ] Add anonymized structure-preserving account and rate-limit fixtures with synthetic values only.
- [ ] Add fixture tests plus a plan-name matrix covering Free, Go, Plus, Pro, Pro Lite, Team, Business, Enterprise, Edu, and unknown without using plan names for quota selection.
- [ ] Run `swift test --filter ProtocolFixtureTests` and confirm all fixtures parse.

### Task 6: Store regression coverage

**Files:**
- Modify: `Tests/CodexUsageBarTests/UsageStoreBehaviorTests.swift`

- [ ] Add a failed-parse outcome test proving the old snapshot and cache remain unchanged while `lastFailure` records the response reason.
- [ ] Add a subsequent-success test proving the snapshot/cache are replaced and the failure is cleared.
- [ ] Run `swift test --filter UsageStoreBehaviorTests` and confirm all refresh-generation and cache-preservation tests pass.

### Task 7: Version and maintenance documentation

**Files:**
- Modify: `VERSION`
- Modify: `CHANGELOG.md`
- Modify: `ARCHITECTURE.md`
- Modify: `SECURITY.md`
- Create: `docs/releases/v0.2.1.md`

- [ ] Set the single version source to `0.2.1` and add concise release notes.
- [ ] Document conservative parsing, semantic cache validation, fixture anonymization, and non-persistence of rejected responses.
- [ ] Keep README user-facing and unchanged unless a release link requires a later publishing update.
- [ ] Run repository version consistency tests.

### Task 8: Full verification and review

**Files:**
- Review all modified files.

- [ ] Run `swift test` and require zero failures.
- [ ] Run `swift build -c release --arch arm64` and require a successful release build.
- [ ] Run `bash -n scripts/*.sh` and the non-publishing release check appropriate for the untagged version.
- [ ] Run `git diff --check`, inspect `git status --short`, and review the complete diff for raw account data, server messages, real quota values, generated artifacts, and unrelated changes.
- [ ] Present the exact manual `git add`, `git commit`, and `git push` steps to the user; do not commit or publish automatically.
