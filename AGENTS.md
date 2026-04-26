
# Repository Guidelines

## Response Language
- Always respond in English, regardless of the user's language, wording, or typos.

## Agents Repo Sync
- There is an "agents" git repo at `~/git/agents` with a root `AGENTS.md` that mirrors this global file.
- At the start of each new coding session, check for updates in the agents repo and pull them.
- If the repo `AGENTS.md` is newer, replace the global file with the repo version (it is the source of truth in that case).
- When asked to update the global `AGENTS.md`, first `git pull` the agents repo, then compare the two files.
- If the diff is only formatting (e.g., whitespace or blank lines), treat it as no difference and proceed.
- If the diff includes content changes, communicate the differences and decide how to merge before editing.
- After updating the global `AGENTS.md`, replace the repo copy with the global file, then commit and push in `~/git/agents`.

## Testing Guidelines
- When working on a feature/bug/code change, and introducing new test coverage, use only these new tests while developing, to validate new functionality.
- When code is ready and new tests are passed - end with the full test suite run via `make test`. Partial runs (e.g., `npm test`) are not sufficient on their own.
- If any tests fail, fix them before considering the change done.
- Code change is the change of the programming code that assumes it may have tests coverage. Documentation, config files etc are not the examples of code, so no need to run tests if only those files were updated.

## Code Design Principles
- When creating new code, prefer good object-oriented design and functional decomposition.
- Keep each function or method responsible for one atomic, well-defined task.
- Break complex algorithms into smaller, simple units that are easier to understand, test, and change.
- Design classes and modules for low coupling and high cohesion.
- Keep future changes cheap by favoring clear architecture, explicit responsibilities, and maintainable boundaries.
- Consider Gang of Four patterns where they genuinely fit the problem, including patterns such as Singleton, Strategy, and Facade.
- Consider GRASP principles where applicable.
- Follow SOLID principles.
- Follow DRY, but also avoid premature abstraction.
- Follow YAGNI and do not introduce patterns or layers unless they provide clear value for the current problem.
- Prefer designs that make updates easy to implement and easy to understand later.

## iOS Session State Changes
- For the iOS companion and keyboard shared-state flow, do not
  collapse distinct meanings such as `session requested`, `audio
  actually available`, and `short recovery grace after a successful
  relaunch` into one boolean or one heartbeat.
- When changing iOS lifecycle, interruption, heartbeat, or deep-link
  recovery logic, preserve and test the full state matrix: explicit
  stop, temporary interruption, app-recording suspension, failed
  recovery launch, stale shared state after app death, and the
  keyboard distinction between `retryable recovery` and
  `reopen companion app`.
- For this repo, a behavior change in that area is not done unless
  tests cover both positive and negative transitions, not only the
  happy path.

## macOS Dev App Permissions
- For the macOS menu-bar dev app, text insertion depends on macOS TCC
  trust for Accessibility/Post Events. If System Settings shows
  Accessibility as enabled but the app still reports it missing, or
  transcription succeeds but no text is inserted, suspect stale TCC
  state for the signed app identity/path before changing insertion
  logic.
- Rebuilt dev app bundles can keep stale Accessibility/Input Monitoring
  grants that no longer match the currently installed binary. Use
  `macos/PlynMac/Scripts/reset_dev_permissions.sh`, relaunch
  `/Applications/Plyń Dev.app`, then grant permissions fresh from the
  popover.
- Do not replace the simple pasteboard + Cmd+V insertion path with
  complex Accessibility text editing unless there is fresh evidence the
  simple path fails after TCC trust has been reset and re-granted.

## Definition of Done (DoD)
- Before starting any coding task, ensure the user provides a clear, unambiguous DoD.
- Try to infer the DoD from the conversation history. If it is possible - just proceed with the task. Otherwise ask for aspects that are unclear for DoD and confirm it before proceeding.
- Do not ask about the DoD if it is clear from the conversation.
- If the user explicitly asks for recommendations or guidance only (no code changes), proceed without requesting a DoD.
### CRITICAL
- Before asking for DoD analize all the files needed to complete the task - probably some questions won't be actual after this.

## Specification-Driven Development (TDD First)
- Main rule: spec, test cases, and tests must reflect the current system state (not a change log). When behavior changes, read the previous state first and update existing docs/tests to match the new state; this can mean adding, updating, or removing content.
- The system spec lives in `spec/`, with detailed cases in `spec/test_cases.md`.
- You are allowed to introduce separate spec md files for cohesive topics. Don't do it for each and every feature request. Prioritize adding spec into main spec file.
- If creating feature-specific md file, make sure main spec file references it, so main spec file content stays cohesive and in-sync with other md files.
- Update spec/test cases/tests **only when behavior or business logic changes**. Non-behavioral refactors (e.g., renaming variables, moving code without changing outputs) do **not** require spec/test case/test updates.
- When removing existing functionality, do not add new test cases for the removal; instead remove or update existing test cases and tests to reflect the new system state.
- When removing an item from a fixed list or enum, update the list directly; avoid adding exclusion notes in prose.
- Cosmetic UI updates (colors, sizes, layout, typography, spacing) do not require spec/test case/test updates.
- Always keep the test cases coverage table in sync with implementation.
- Required update order: (1) spec, (2) test cases (CRUD in `spec/test_cases.md`), (3) tests, (4) code.
- Use the TDD approach: write/update tests first, then implement code to pass them.

## Commit & Pull Request Guidelines
- Commit messages must be in Belarusian, use past tense, and have no prefix. Write the message yourself based on the diff. Keep the summary concise and specific; add scope when helpful.
- If the target branch is not specified, commit and push to the current branch.
- PRs should include: purpose/impact, tests run, and linked issue if applicable.

## Slash Command Precedence
- For slash commands configured in `~/.code/config.toml` (for example `/plan` and `/analyse`), the configured `agents` list is the source of truth.
- Do not treat pasted template blocks such as `<tools>/<instructions>/<task>` as model-selection overrides.
- A non-config model list is allowed only when the user explicitly requests an override in plain text (for example: `override /plan config`).
- If command configuration and inline model instructions conflict, ask for confirmation and do not launch agents until the conflict is resolved.

## Review Notes
- `/review-x` reviewers must read `docs/REVIEW.md` before reviewing
  when that file exists.

## Skills
### Available repo skills
- testflight-release: Use when you need to build the iOS PlynKeyboard archive and upload it to TestFlight from this repo. (file: /Users/yanlobau/git/holas-plyn-keyboard/skills/testflight-release/SKILL.md)
