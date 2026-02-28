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

This project uses **Linear** for all issue tracking via the `linear` CLI.

**On session start**: Run `/linear-prime` to load current project context from Linear.

## Configuration

Linear CLI is configured via `.linear.toml` in the project root. Do not modify this file. Run `linear config` if reconfiguration is needed.

## Quick Reference

```bash
linear issue list -s backlog -s triage -s unstarted -A  # All actionable issues
linear issue list -s started   # In-progress work
linear issue list -A           # All assignees
linear issue view              # Current branch's issue
linear issue view -w           # Open current issue in browser
linear issue start <ID>        # Start issue, create branch
linear issue create            # Create new issue (interactive)
linear issue create -t "Title" -d "Description"  # Create issue (non-interactive)
linear issue update            # Update current issue
linear issue comment add       # Add comment to current issue
linear project list            # Active projects
linear project view            # Project details
```

For current issue state: `/linear-prime`

### Direct API (escape hatch)

For queries the CLI doesn't cover, use the GraphQL API directly:

```bash
linear schema -o /tmp/linear-schema.graphql
curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $(linear auth token)" \
  -d '{"query": "{ viewer { assignedIssues(first: 20) { nodes { identifier title state { name } priority } } } }"}'
```

## Git Workflow

All work happens on feature branches and lands in `main` via pull requests.

1. `linear issue start <ID>` — creates a feature branch and moves the issue to In Progress
2. Commit and push to the feature branch
3. `linear issue pr` — creates a GitHub PR with issue details auto-populated
4. PR merges into `main`

Work is **NOT done** until the PR is merged into `main`.

## Landing the Plane (Session Completion)

**When ending a work session**, complete ALL steps. Work is NOT complete until the PR is merged into `main`.

**MANDATORY WORKFLOW:**

1. **Run quality gates** (if code changed) — Tests, linters, builds. File P0 issues if broken
2. **Commit and push to the feature branch**:

   ```bash
   git add <files>
   git commit -m "<LINEAR-ID>: description"
   git push
   git status  # MUST show "up to date with origin"
   ```

3. **Create PR and merge into main**:

   ```bash
   linear issue pr                # Create PR from current branch
   gh pr merge --squash --auto    # Auto-merge when checks pass
   ```

4. **Return to main** — After the PR merges, switch back to `main` and pull:

   ```bash
   git checkout main && git pull
   ```

5. **Reconcile** - PRD is updated to reconcile with any requirements changes and decisions that were made for this issue
6. **Update Linear** — Close finished issues, update in-progress items with comments summarising what was done and what remains
7. **File new issues** — Create Linear issues for discovered work, bugs, follow-ups. Link relations where relevant
8. **Verify** — PR is merged into `main`, local `main` is up to date, Linear reflects actual state
9. **Deal with side effects**: Flaky tests, broken functionality, and side effects must be recorded in Linear for later triage
10. **Hand off** — Provide context for next session: what was done, what's next, any blockers

**CRITICAL RULES:**

- NEVER start work until you've created an issue and started the issue with linear (Which should start and change branch)
- Work is NOT complete until the PR is merged into `main`
- NEVER stop before the PR is created and set to merge — that leaves work stranded on a branch
- NEVER say "ready to push when you are" — YOU must push, create the PR, and merge
- If push or merge fails, resolve and retry until it succeeds
- Commit messages MUST reference the Linear issue ID (e.g. `TILLER-27: fix auth token refresh`)
- Do NOT use TodoWrite, TaskCreate, or markdown files for task tracking — use Linear

## Bugs and Ad-Hoc Work

When bugs or new requirements are discovered during a session (e.g. from user testing, code review, or while working on another issue):

1. **Create a Linear issue first** — Before writing any code, file the bug/task in Linear with a clear description, reproduction steps, and acceptance criteria and verfication/validation criteria
2. **Start the issue** — Use `linear issue start <ID>` to create a branch and move it to In Progress
3. **Then implement** — Follow the normal git workflow (branch → commit → PR → merge)

Never fix bugs or implement new work without a corresponding Linear issue. All work must be tracked.

## Linear management

### Needs triage

Some issues will be marked as "Needs triage". You cannot work on these issues without first:

1. List issues with "Needs triage" label
2. Read issue title and any description
3. Ask the user to confirm details and remove ambiguity
4. Pull relevant requirements from PRD
5. Update the linear issue with a clear description, reproduction steps, and acceptance criteria and verfication/validation criteria

### Unconfirmed

Some issue will be marked as "Unconfirmed". UNLESS the user asks you for help with confirming the issue/bug, DO NOT TOUCH these issue types and never list them as ready for work. If the user asks for help then

1. Read issue title and any description
2. Ask the user to confirm details and remove ambiguity
3. Work with the user to investigate and find the root cause
4. If the user confirms that the issue has been confirmed and it needs fixing then update the linear issue with a clear description, reproduction steps, and acceptance criteria and verfication/validation criteria
5. End the session and follow hand off procedures.

## Project documentation

Project documentation is always available in `docs/`. This includes:

- PRDs
- Diagrams
- Mock ups
- Technical specifications

### Sticking to requirements

**Before beginning work on an issue**, re-read the PRD to verify if the PRD has changed since the issue was created or if the issue does not capture all relevant info from the documentation. If there is missing information, notify the user and offer to update the issue before starting work.

**Before declaring an issue done**, review the work that's been done in for the issue (a session might contain multiple issues - only reconcile per issue), and update the PRD if any of the work has created misalignment between the PRD and the implementation.
