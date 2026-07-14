# Security

CodexUsageBar is designed to expose a narrow, local view of Codex usage. This document describes the current data and trust boundaries.

## App-Server Access

The app starts `codex app-server --stdio` and performs the required `initialize` / `initialized` exchange. Its only application-data requests are:

- `account/read`, with token refresh disabled, to determine whether an account is available;
- `account/rateLimits/read`, to obtain current Codex rate-limit windows.

Account response fields are not retained. The app does not directly read `~/.codex/auth.json`, sessions, prompts, conversations, project files, or Codex history.

Responses that fail envelope, type, range, or semantic validation are not stored. The app keeps the last previously validated snapshot instead of persisting partially parsed or ambiguous data.

## Local Storage

The last successful snapshot is encoded in `UserDefaults` under `lastSuccessfulRateLimitSnapshot`. It contains:

- primary and optional secondary window usage percentages;
- window durations in minutes;
- reset timestamps;
- the local fetch timestamp.

The selected menu bar display mode is stored separately. No account profile, token, prompt, conversation, or raw app-server response is cached.

## Diagnostics

Copied diagnostics may contain:

- app version, macOS version, and CPU architecture;
- Codex executable source and a path with the home-directory prefix replaced by `~`;
- stable availability and last-refresh time;
- failure category, app-server phase, and optional JSON-RPC error code.

Diagnostics omit quota values, account data, tokens, raw server messages, `error.data`, prompts, and conversations.

## Test Fixtures

Protocol fixtures under `Tests/CodexUsageBarTests/Fixtures` preserve representative response structure with synthetic values. They must not contain real account identifiers, email addresses, tokens, raw server error text, personal quota values, prompts, sessions, or conversations. Fixture capture from a user's live account is not automated.

## Network Boundary

CodexUsageBar has no automatic update checker, telemetry client, analytics SDK, or direct HTTP API client. The Codex process it launches may use Codex's own network and authenticated account state. That behavior belongs to Codex, not to a separate CodexUsageBar service.

## Distribution Trust

Current preview archives are ad hoc signed and are not notarized by Apple. Verify the SHA-256 asset and follow [DISTRIBUTION.md](DISTRIBUTION.md). Do not treat an ad hoc signature as proof of publisher identity.

## Reporting a Vulnerability

Do not disclose tokens, account data, private paths, or exploit details in a public issue.

Use GitHub private vulnerability reporting at `https://github.com/ShaneD711/CodexUsageBar/security/advisories/new` when available. If the repository does not expose that form, open a minimal public issue requesting a private contact channel without including vulnerability details.

Security fixes are provided on a best-effort basis for the latest release.
