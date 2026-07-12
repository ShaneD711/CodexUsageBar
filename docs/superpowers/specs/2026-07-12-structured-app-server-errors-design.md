# Structured App-Server Errors and Locale Boundaries

## Scope

CodexUsageBar will stop classifying authentication failures by searching the server's English error message. The same change will make failure diagnostics phase-aware, narrow Simplified Chinese detection, and make all absolute dates and times follow the user's system region settings.

This work does not add Traditional Chinese translations, expose raw server messages, or change the menu-bar-only product scope.

## Structured Account Check

After a successful `initialize` exchange, the client sends `account/read` before `account/rateLimits/read`.

The account response is decoded as structured data:

- `account == null` and `requiresOpenaiAuth == true` means the user is not signed in.
- Any other valid account response permits the rate-limit request to continue.
- A malformed account response is an invalid response in the `account` phase.

The account check and rate-limit read share the existing monotonic request deadline. It does not create another full timeout window.

## Failure Model

`AppServerPhase` identifies where a failure occurred:

- `launch`
- `initialize`
- `account`
- `rate-limits`

`CodexAppServerError` carries only safe structured context:

- executable not found
- launch failed
- not logged in
- timed out with phase
- connection closed with phase
- invalid response with phase
- server error with optional JSON-RPC code and phase

JSON-RPC responses are decoded using `code`, `message`, and optional `data`, but only `code` is retained. The original `message` and `data` are never placed in application state, copied diagnostics, or tests as diagnostic output.

`UsageFailure` retains a stable user-facing category plus optional phase and server code. Existing localized error messages continue to switch on the stable category.

## Diagnostics

Copied diagnostics remain free of account details and quota values. When a failure exists, they include:

```text
Category: not-logged-in
Phase: account
Error code: none
```

Fields with no value use `none`. Raw server messages and `error.data` are omitted.

## Language and Region Formatting

Simplified Chinese is selected only for language identifiers whose normalized language/script/region combination clearly denotes Simplified Chinese:

- `zh-Hans`
- `zh-CN`
- `zh-SG`

Traditional Chinese identifiers such as `zh-Hant`, `zh-TW`, and `zh-HK` fall back to English until a complete Traditional Chinese localization is added.

UI copy follows `AppLanguage`. Absolute dates and times do not use an app-language locale; both the menu bar and popover use `Locale.autoupdatingCurrent`, preserving the user's region and 12/24-hour preferences.

## Tests

Automated tests cover:

- a structured signed-out account response;
- successful account validation followed by rate-limit parsing;
- JSON-RPC code retention without message retention;
- timeout, EOF, invalid response, and server failures in each relevant phase;
- diagnostics containing category, phase, and code but no server message;
- Simplified Chinese identifiers and Traditional Chinese fallback;
- menu-bar and popover formatting through the same system-locale default;
- all existing process cancellation, deadline, cache, and refresh behavior.

## Compatibility Boundary

The implementation depends only on fields present in the locally generated Codex app-server JSON Schema. If a future Codex version removes or changes `account/read`, the failure is reported as a phase-aware server or unsupported-response error rather than inferred from human-readable text.
