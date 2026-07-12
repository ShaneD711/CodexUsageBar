# CodexUsageBar GitHub Actions CI Design

[English](2026-07-12-github-actions-ci-design.md) | [简体中文](2026-07-12-github-actions-ci-design.zh-CN.md)

Date: 2026-07-12

## Goal

Provide an automated check independent of the developer's Mac for every push to `main` and every pull request, preventing code with build failures, failing tests, or invalid shell syntax from entering the main branch unnoticed.

## Workflow

A single `.github/workflows/ci.yml` workflow runs on the stable Apple Silicon `macos-15` GitHub-hosted runner and performs these steps:

1. Check out the source with the official `actions/checkout` action.
2. Print Swift and Xcode versions for runner-change diagnostics.
3. Validate development and release shell scripts with `bash -n`.
4. Run all unit tests with `swift test`.
5. Verify the release configuration with `swift build --configuration release --arch arm64`.

The workflow also supports manual dispatch. Concurrency cancellation stops an older unfinished run when a newer commit arrives on the same branch.

## Permissions and Boundaries

- Grant only `contents: read`.
- Use no repository secrets.
- Do not sign in to Codex or read real account usage.
- Do not sign, package, upload artifacts, create tags, or publish GitHub Releases.
- Do not run menu-bar UI automation.

## Success Criteria

- Pushes and pull requests display a CI check result.
- Any failed test, script validation, or release build fails the workflow.
- Local and CI runs use the same Swift test sources.
- The README displays the current CI status.
