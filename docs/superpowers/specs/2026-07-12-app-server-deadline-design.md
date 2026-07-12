# Codex app-server Request Deadline Design

[English](2026-07-12-app-server-deadline-design.md) | [简体中文](2026-07-12-app-server-deadline-design.zh-CN.md)

Date: 2026-07-12

## Problem

The previous implementation created a fresh 15-second timeout for every stdout line. A stream of unrelated JSON-RPC notifications could therefore extend a request indefinitely, while initialization and rate-limit reads could each consume a full timeout. When stdout closed with an empty buffer, the reader could not immediately distinguish EOF from temporary inactivity, causing an exited service to be reported as a timeout.

## Design

- Create one 15-second monotonic `DispatchTime` deadline after app-server starts.
- Share that deadline between initialization and `account/rateLimits/read` responses.
- Keep passing the original deadline while `readResponse` skips unrelated messages.
- Check the deadline before processing every line so a continuously nonempty buffer still terminates on time.
- Distinguish line data, waiting, and EOF inside the line reader.
- Return EOF immediately when stdout is closed and the buffer is empty.
- Map EOF to a dedicated `service-stopped` failure instead of timeout or unsupported response.

## Verification

- Verify unrelated notifications receive exactly the same deadline.
- Verify an expired deadline fails immediately even when messages remain buffered.
- Verify EOF maps to the service-stopped failure.
- Use a real `Pipe` to verify closing the write side returns EOF within 0.5 seconds.
- Keep all parser, error, localization, diagnostics, and version tests passing.
