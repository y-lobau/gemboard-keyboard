# Review Guide

Use this guide for `/review-x` in this repository when reviewing local changes.

## Focus

- Prioritize bugs, regressions, and missing coverage over summaries.
- Treat shared state, lifecycle handling, and keyboard-companion
  coordination as high-risk areas.
- Validate both the happy path and the ways state can become stale,
  interrupted, or only partially updated.

## iOS Companion Session Checklist

- Verify that each shared flag or timestamp represents one semantic only.
- Check the distinction between:
  - companion session requested or owned by the app
  - audio actually available right now
  - short recovery grace after a successful recovery launch
- Ensure interruption begin does not accidentally clear recovery intent
  that interruption end or app activation still needs.
- Ensure recovery grace is persisted only after some launch path
  reports success, never before.
- Ensure the keyboard still distinguishes:
  - retryable recovery state while the companion is still around
  - reopen-app-required state after companion presence has gone stale
- Check stale-state behavior after app death or an unclean shutdown,
  not only explicit stop flows.

## Expected Review Output

- Findings first, ordered by severity, with file and line references.
- Call out missing tests when a transition or negative path is unverified.
- Keep the summary brief and secondary.
