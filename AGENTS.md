# Agent Instructions

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
linear issue start <ID>        # Start issue, create branch
linear issue create            # Create new issue
linear issue update            # Update current issue
```

For full workflow context and current issue state: `/prime`

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

5. **Update Linear** — Close finished issues, update in-progress items with comments summarising what was done and what remains
6. **File new issues** — Create Linear issues for discovered work, bugs, follow-ups. Link relations where relevant
7. **Verify** — PR is merged into `main`, local `main` is up to date, Linear reflects actual state
8. **Hand off** — Provide context for next session: what was done, what's next, any blockers

**CRITICAL RULES:**

- Work is NOT complete until the PR is merged into `main`
- NEVER stop before the PR is created and set to merge — that leaves work stranded on a branch
- NEVER say "ready to push when you are" — YOU must push, create the PR, and merge
- If push or merge fails, resolve and retry until it succeeds
- Commit messages MUST reference the Linear issue ID (e.g. `TILLER-27: fix auth token refresh`)
- Do NOT use TodoWrite, TaskCreate, or markdown files for task tracking — use Linear

## Bugs and Ad-Hoc Work

When bugs or new requirements are discovered during a session (e.g. from user testing, code review, or while working on another issue):

1. **Create a Linear issue first** — Before writing any code, file the bug/task in Linear with a clear description, reproduction steps, and acceptance criteria
2. **Start the issue** — Use `linear issue start <ID>` to create a branch and move it to In Progress
3. **Then implement** — Follow the normal git workflow (branch → commit → PR → merge)

Never fix bugs or implement new work without a corresponding Linear issue. All work must be tracked.

## Project documentation

Project documentation is always available in `docs/`. This includes:

- PRDs
- Diagrams
- Mock ups
- Technical specifications

### Sticking to requirements

**Before beginning work on an issue**, re-read the PRD to verify if the PRD has changed since the issue was created or if the issue does not capture all relevant info from the documentation. If there is missing information, notify the user and offer to update the issue before starting work.
