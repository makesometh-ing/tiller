---
name: linear-landing
description: "Use this skill when code is ready to travel from local branch to merged main. The user's intent is completion — they're done coding and want the work shipped. Common signals: 'ship it', 'land this', 'time to merge', 'wrap up', 'tests are green let's go', 'push and create a PR', 'done for the day', or any statement that implementation is finished and needs to go through the delivery pipeline. This skill owns push, PR, merge, Linear update, and optional handoff. Do not use for backup-only pushes (not ready to PR), standalone Linear issue management, debugging, or planning the next thing to work on."
---

# Landing the Plane — Session Completion

Work is NOT complete until the PR is merged into `main`. Complete ALL steps below.

## Step 1: Quality Gates

If code changed during this session, run tests, linters, and builds. If any gate fails, file a P0 issue in Linear.

## Step 2: Commit and Push

```bash
git add <files>
git commit -m "<LINEAR-ID>: description"
git push
git status  # MUST show "up to date with origin"
```

## Step 3: Create PR and Merge

```bash
linear issue pr                # Create PR from current branch
gh pr merge --squash --auto    # Auto-merge when checks pass
```

## Step 4: Return to Main

After the PR merges:

```bash
git checkout main && git pull
```

## Step 5: Reconcile PRD

Review the work done for each issue in this session. Update `docs/PRD.md` if any work created misalignment between the PRD and the implementation.

## Step 6: Update Linear

Close finished issues. Update in-progress items with comments summarising what was done and what remains.

## Step 7: File New Issues

Create Linear issues for discovered work, bugs, and follow-ups. Link relations where relevant.

## Step 8: Verify

Confirm all of:
- PR is merged into `main`
- Local `main` is up to date
- Linear reflects actual state

## Step 9: Deal with Side Effects

Flaky tests, broken functionality, and side effects must be recorded in Linear for later triage.

## Step 10: Next Cycle

After landing, the default is to **continue working** — not to stop. Run `/linear-session` to load the updated project context and pick the next issue.

Only hand off and end the session if the user explicitly says they're done for the day. In that case, provide context for the next session:
- What was done
- What is next
- Any blockers

## Critical Rules

- Work is NOT complete until the PR is merged into `main`
- NEVER stop before the PR is created and set to merge — that leaves work stranded on a branch
- NEVER say "ready to push when you are" — YOU must push, create the PR, and merge
- If push or merge fails, resolve and retry until it succeeds
- Commit messages MUST reference the Linear issue ID (e.g. `TILLER-27: fix auth token refresh`)
- Do NOT use TodoWrite, TaskCreate, or markdown files for task tracking — use Linear
