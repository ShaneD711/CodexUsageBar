# Codex Protocol Resilience Design

[English](2026-07-13-protocol-resilience-design.md) | [简体中文](2026-07-13-protocol-resilience-design.zh-CN.md)

## Purpose

CodexUsageBar must prefer an explicitly stale, previously verified snapshot over a fresh value whose meaning is uncertain. Protocol compatibility is therefore a correctness boundary, not a best-effort convenience.

This is the P0 correctness scope for `v0.2.1`. It hardens the existing `account/read` and `account/rateLimits/read` flow without expanding the product's data-access scope.

## Principles

- Ignore unknown fields at every envelope and payload level.
- Accept harmless scalar representation changes only when conversion is exact and unambiguous.
- Never invent a missing percentage, duration, reset time, account state, or quota window.
- Reject the selected rate-limit snapshot when any present window contains an invalid critical field.
- Preserve the last successful snapshot whenever launch, transport, account, server, or parsing fails.
- Keep raw account data, server messages, and response bodies out of application state and diagnostics.

## Protocol Inputs

The application continues to send only:

1. `initialize`
2. `initialized`
3. `account/read`
4. `account/rateLimits/read`

The client uses one monotonic request deadline across the entire exchange. No additional account, session, prompt, conversation, or token-history endpoint is introduced.

## Account Validation

The account parser reads only whether `result` exists, whether `account` is a JSON object, and, when no account object exists, whether `requiresOpenaiAuth` is a valid Boolean.

| `account` JSON state | `requiresOpenaiAuth` | Result |
| --- | --- | --- |
| Any object, including `{}` | Any representation or absent | Continue |
| `null` or field absent | `true` | Not logged in |
| `null` or field absent | `false` | Continue for a provider that does not require OpenAI auth |
| `null` or field absent | Missing or invalid type | Response changed |
| String, number, Boolean, or array | Any value | Response changed |

Unknown account types and fields are accepted because the application does not use email, plan, workspace, or credential details. An empty object still means an account object exists. When an account object exists, an unrelated change to `requiresOpenaiAuth` does not block quota reading. This requires custom minimal decoding rather than the current `AccountMarker` DTO.

## Rate-Limit Selection

The parser selects the Codex quota bucket in this order:

1. `rateLimitsByLimitId["codex"]`;
2. a `rateLimitsByLimitId` entry whose internal `limitId` equals `codex`;
3. the backward-compatible top-level `rateLimits` object.

`limitId` matches only the exact JSON string `"codex"`; no case folding or scalar conversion is permitted. If two or more mapped objects internally claim `limitId == "codex"`, the response is rejected as `ambiguousCodexLimits` rather than depending on dictionary order.

Fallback occurs only when the higher-priority candidate does not exist. Once a candidate is selected, any validation failure rejects the complete response; the parser must not bypass a damaged explicit Codex bucket by reading the lower-priority top-level object.

The parser never assumes that an arbitrary single bucket belongs to Codex. If no Codex or backward-compatible bucket is available, the response is rejected.

`primary` and `secondary` are transport positions, not fixed names or domain invariants. The parser validates each present transport window, collects complete windows in `[primary, secondary]` source order, and requires a non-empty result. It then normalizes that ordered collection into the existing domain model: the first collected window becomes `RateLimitSnapshot.primary`, and the second becomes its optional `secondary`. A transport response containing only `secondary` therefore promotes that valid window to the domain `primary` without making the domain fields optional.

The following window layouts are valid:

- five-hour plus weekly;
- weekly only;
- five-hour only;
- reversed short and long windows;
- one or two previously unknown positive durations.

## Critical Window Fields

A window field is absent when its key is missing or its value is `null`. Either state is allowed. A JSON object means the window is present and must pass complete validation. An array, string, number, or Boolean in the window position is rejected as `invalidCriticalType`. An empty object is present but missing critical fields. `noUsableWindow` applies only when both transport positions are absent or null.

Each present window requires:

- `usedPercent`: a finite, non-negative number;
- `windowDurationMins`: a positive whole number representable as `Int`;
- `resetsAt`: a positive whole-number Unix timestamp no later than `Date.distantFuture.timeIntervalSince1970`.

These fields accept a JSON number or a string matching this JSON-number grammar:

```regex
-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?
```

The strings `"300"`, `"300.0"`, and `"3e2"` are accepted when the target field requires the exact integer 300. `"+300"`, `" 300 "`, `"03"`, `"300_000"`, `"NaN"`, and `"Infinity"` are rejected. Parsing uses `Decimal` before integer validation so binary floating-point rounding cannot turn a fractional or overflowing value into an integer. JSON Booleans are detected before `NSNumber` handling and are never treated as 0 or 1.

`windowDurationMins` and `resetsAt` must be exact whole numbers before conversion. The reset-time upper bound rejects millisecond timestamps accidentally interpreted as seconds and guarantees a representable `Date`. `usedPercent` may be fractional but must become a finite, non-negative `Double`.

`usedPercent` may exceed 100 when the upstream service reports overuse. `remainingPercent` must compare the `Double` remainder with the `0...100` boundaries before converting it to `Int`; this avoids trapping on values such as `Double.greatestFiniteMagnitude`.

If a present window has a missing or invalid critical field, the complete selected snapshot is rejected. The client does not silently drop that window because doing so could hide a real quota boundary.

## JSON-RPC Envelope Rules

The line reader applies these rules before payload parsing.

The client may ignore:

- a valid JSON notification object with no `id` and a string `method`;
- a valid JSON response for a different integer request ID;
- known or unknown notification methods.

The client immediately reports `responseChanged(phase:reason:)` with `malformedEnvelope` when stdout contains:

- a non-JSON line;
- a top-level JSON value that is not an object;
- an object that is neither a notification nor a response;
- any response whose `id` is not an integer;
- the current response with both `result` and `error`;
- the current response with neither `result` nor `error`;
- the current response whose `error` is not an object with an integer `code`.

Only responses matching the active `initialize`, `account/read`, or `account/rateLimits/read` request are mapped as request failures. `initialized` is a notification and has no matching response.

## Failure Model

Safe structured parsing context is added without retaining raw payloads:

```swift
enum ResponseChangeReason: String {
    case malformedEnvelope
    case missingResult
    case missingCodexLimits
    case ambiguousCodexLimits
    case missingCriticalField
    case invalidCriticalType
    case invalidCriticalValue
    case noUsableWindow
}
```

Reason precedence is fixed:

1. invalid RPC envelope -> `malformedEnvelope`;
2. valid success envelope with `"result": null` -> `missingResult`;
3. no Codex bucket and no top-level fallback -> `missingCodexLimits`;
4. multiple internal Codex buckets -> `ambiguousCodexLimits`;
5. both window positions absent or null -> `noUsableWindow`;
6. a present window lacks a critical field -> `missingCriticalField`;
7. a critical field has an unsupported JSON type -> `invalidCriticalType`;
8. a recognized scalar has an invalid value -> `invalidCriticalValue`.

The stable user-facing failure categories are:

- Codex executable not found;
- not logged in;
- incompatible Codex version;
- request timed out;
- Codex service stopped;
- response format changed;
- launch failed;
- service temporarily unavailable.

JSON-RPC `method not found` (`-32601`) and `invalid params` (`-32602`) on the fixed protocol exchange are classified as incompatible Codex versions. Other JSON-RPC server failures remain temporarily unavailable and retain only their numeric code.

`CodexAppServerError` replaces the broad invalid-response case with `incompatible(code:phase:)` and `responseChanged(phase:reason:)`. `UsageFailure.Category` gains matching stable `incompatible` and `responseChanged` values plus an optional `responseChangeReason`. Malformed JSON, missing required semantic data, and invalid critical values are response-format changes.

Diagnostics may include category, phase, numeric server code, and reason. They never include field names, raw messages, response fragments, account data, percentages, or reset times.

## Availability and Cache

`UsageAvailability` gains a response-changed state separate from incompatible-version and temporarily-unavailable states. Availability answers what can currently be displayed; `UsageFailure` records why the latest refresh failed. These concepts remain separate.

When no snapshot exists, the popover shows the exact stable failure category. When a previous snapshot exists, that snapshot remains visible, freshness continues to be calculated from its original `fetchedAt`, and the popover shows the specific refresh failure alongside the stale warning when applicable.

A failed parse never writes to `UserDefaults` and never clears the last successful snapshot.

Decoded cache data is not trusted solely because it conforms to `Codable`. `RateLimitSnapshot` owns a shared semantic invariant that validates every window's finite non-negative usage, positive duration, representable positive reset timestamp, and the overflow-safe remaining calculation. A cached snapshot must pass the same domain invariant before display. Invalid cache data is removed from `UserDefaults` and treated as absent.

## Response Fixtures

Sanitized JSON fixtures live under `Tests/CodexUsageBarTests/Fixtures` and are loaded through `Bundle.module`. `Package.swift` must declare `.process("Fixtures")` on the test target. The fixtures preserve real envelope and field shape while replacing account identifiers, email addresses, percentages, timestamps, and other user-specific values.

Required fixtures include:

- a historical five-hour plus weekly response;
- the current weekly-only response;
- the backward-compatible top-level response;
- signed-in and signed-out account responses;
- responses with additional unknown fields.

Synthetic table-driven cases cover plan identifiers including Free, Go, Plus, Pro, Pro Lite, Team, Business, Enterprise, Edu, and unknown. Plan values do not select or modify quota windows.

Fixtures must contain no raw server error messages, tokens, account IDs, real email addresses, or values copied directly from a user's quota.

## Tests

Automated coverage includes:

- every account-validation row in the table above;
- exact-key and internal-ID Codex selection, ambiguous internal IDs, no fallback from a damaged selected bucket, and top-level fallback only when higher-priority candidates are absent;
- weekly-only, short-only, secondary-only promotion, dual, reversed, and unknown-duration windows;
- ignored unknown fields;
- the complete accepted and rejected numeric-string grammar;
- missing, malformed, ambiguous, negative, fractional, and overflowing critical values;
- `usedPercent` values of 101, 1,000,000, and `Double.greatestFiniteMagnitude` returning zero remaining without trapping;
- second-versus-millisecond reset timestamps and the representable date upper bound;
- malformed RPC lines and current-ID envelope conflicts failing immediately instead of timing out;
- method-not-found and invalid-params version incompatibility;
- temporary server errors, timeout, EOF, cancellation, and launch failure;
- parse failure preserving the cached snapshot and failure context;
- semantically invalid decodable cache data being removed and ignored;
- a later valid response replacing the cache and clearing the failure;
- diagnostics containing only safe category, phase, code, and reason fields.

## Documentation

`ARCHITECTURE.md` documents the conservative parser boundary. `SECURITY.md` documents sanitized fixture rules and confirms that failed raw responses are not persisted. The user-facing README remains concise and does not expose protocol implementation details.

## Out of Scope

- direct OpenAI HTTP API calls;
- reading `auth.json`, sessions, prompts, conversations, or project data;
- displaying plan names or account identity;
- partial display of a malformed quota snapshot;
- automatic fixture capture from a user's live account;
- a persistent app-server connection or notification subscription.

## Acceptance Criteria

The `v0.2.1` work is complete when all supported response shapes produce the expected normalized windows; oversized percentages cannot trap; malformed envelopes fail immediately; ambiguous critical changes and invalid caches never become displayed data; every requested failure is distinguishable without raw data; fixtures are configured and demonstrably sanitized; and the complete Swift test and arm64 release build pass.
