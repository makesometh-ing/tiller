---
name: linear-prime
description: Load current Linear project context. Run at session start to orient on active work, blockers, and priorities. Use when beginning a session, after compaction, or when you need to re-establish project context.
---

# Prime — Linear Project Context

## Current State

### In Progress

!`linear issue list -s started`

### Unstarted (Ready to Work)

!`linear issue list`

### Current Branch Issue

!`linear issue view 2>/dev/null || echo "Not on an issue branch. List issues to find out waht's next"`

## Workflow Rules

- **All task tracking goes through Linear.** Do not use TodoWrite, TaskCreate, or markdown plans.
- **Create before coding.** If no Linear issue exists for what you're about to do, create one first with `linear issue create`.
- **Start before working.** Run `linear issue start <ID>` to claim an issue — this creates a branch and marks it in-progress.
- **Commit messages reference issue IDs.** Format: `ENG-123: description of change`.
- **File discovered work immediately.** If you notice a bug, tech debt, or follow-up while working on something else, create a new Linear issue for it right away. Don't hold it in memory.

## Essential Commands

### Finding Work

- `linear issue list` — Your unstarted assigned issues
- `linear issue list -s started` — Your in-progress work
- `linear issue list -A` — All assignees (team view)
- `linear issue view` — Current branch's issue details
- `linear issue view -w` — Open current issue in browser

### Creating & Updating

- `linear issue create` — Interactive issue creation
- `linear issue create -t "Title" -d "Description"` — Non-interactive creation
- `linear issue start <ID>` — Start issue, create/switch to branch
- `linear issue update` — Update current issue
- `linear issue comment add` — Add comment to current issue

### Project Context

- `linear issue list -A -s started` — Everything in flight across the team
- `linear project list` — Active projects
- `linear project view` — Project details

### Direct API (escape hatch)

For queries the CLI doesn't cover, use the GraphQL API directly:

```bash
linear schema -o /tmp/linear-schema.graphql
curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $(linear auth token)" \
  -d '{"query": "{ viewer { assignedIssues(first: 20) { nodes { identifier title state { name } priority } } } }"}'
```

## Session Close Protocol

Before ending any session, complete ALL of the following:

1. **Update Linear** — Close finished issues, update in-progress items with comments on what was done and what remains
2. **File new issues** — Create Linear issues for discovered work, bugs, follow-ups
3. **Quality gates** (if code changed) — Run tests, linters, builds
4. **Push**:

   ```bash
   git add <files>
   git commit -m "<LINEAR-ID>: description"
   git pull --rebase
   git push
   ```

5. **Verify** — `git status` must show up to date with origin. Linear must reflect actual state.
6. **Hand off** — State what was done, what's next, and any blockers for the next session.

Work is NOT done until `git push` succeeds. Never stop before pushing.
