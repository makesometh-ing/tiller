# Agent Instructions

## Issue Tracking

This project uses **Linear** for all issue tracking via the `linear` CLI.

**On session start**: Run `/linear-prime` to load current project context from Linear.

## Configuration

Linear CLI is configured via `.linear.toml` in the project root. Do not modify this file. Run `linear config` if reconfiguration is needed.

## Quick Reference

```bash
linear issue list              # Your unstarted issues
linear issue list -s started   # In-progress work
linear issue list -A           # All assignees
linear issue view              # Current branch's issue
linear issue start <ID>        # Start issue, create branch
linear issue create            # Create new issue
linear issue update            # Update current issue
```

For full workflow context and current issue state: `/prime`

## Landing the Plane (Session Completion)

**When ending a work session**, complete ALL steps. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **Update Linear** — Close finished issues, update in-progress items with comments summarising what was done and what remains
2. **File new issues** — Create Linear issues for discovered work, bugs, follow-ups. Link relations where relevant
3. **Run quality gates** (if code changed) — Tests, linters, builds. File P0 issues if broken
4. **Push to remote**:

   ```bash
   git add <files>
   git commit -m "<LINEAR-ID>: description"
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```

5. **Verify** — All changes committed AND pushed, Linear reflects actual state
6. **Hand off** — Provide context for next session: what was done, what's next, any blockers

**CRITICAL RULES:**

- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing — that leaves work stranded locally
- NEVER say "ready to push when you are" — YOU must push
- If push fails, resolve and retry until it succeeds
- Commit messages MUST reference the Linear issue ID (e.g. `ENG-123: fix auth token refresh`)
- Do NOT use TodoWrite, TaskCreate, or markdown files for task tracking — use Linear
