# Agent Instructions

## Coding Principles

These principles apply to all code written in this project. Follow them without exception.

- **Minimize lines of code.** Every line is surface area for bugs. Delete what you can, simplify what you can't.
- **Use modern Swift and latest APIs.** Before implementing, verify you're not using deprecated or outdated APIs — check current documentation based on the query date, not your knowledge cutoff.
- **Favour composition and testability.** Inject dependencies via init. Keep logic in pure functions/types that can be tested without system dependencies (AX, CGEventTap, NSScreen).
- **Favour locality of behaviour.** Keep related code together. Prefer straightforward inline logic over abstractions that scatter understanding across files.
- **No premature abstraction.** Don't create helpers, utilities, or wrappers for one-time operations. Three similar lines is better than a premature abstraction.
- **No over-engineering.** Don't add features, configurability, error handling, or validation beyond what the issue requires. Only validate at system boundaries (user input, external APIs).
- **No singletons in new code.** Existing `.shared` instances are accepted debt. New code takes dependencies via init.
- **Concurrency: be boring.** Favour `@MainActor` boundaries with clear state ownership. Avoid clever concurrency. If in doubt, marshal to main.
- **Fail visibly, recover silently.** AX calls fail often — log the failure, skip the window, move on. Never crash on an AX error. Never swallow errors silently in debug — use the structured logging system.
- **Test the state machine, not the system.** CGEventTap, AX APIs, and NSScreen are untestable in unit tests. The integration layer should be a thin shell around pure, testable logic.

## Issue Tracking

This project uses **Linear** for all issue tracking. Do NOT use TodoWrite, TaskCreate, or markdown files for task tracking — use Linear.

- **Session start / after compaction**: Run `/linear-session` to load project context, orient on work, and review issue lifecycle rules.
- **Session end / work complete**: Run `/linear-landing` to execute the mandatory completion protocol.

All work happens on feature branches and lands in `main` via pull requests. Commit messages MUST reference the Linear issue ID (e.g. `TILLER-27: fix auth token refresh`).

## Project Documentation

Project documentation is in `docs/`. This includes PRDs, diagrams, mock ups, and technical specifications.
