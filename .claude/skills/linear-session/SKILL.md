---
name: linear-session
description: "Invoke this skill whenever the user needs to answer 'what should I work on?' or 'where are we in the project?' — covering: session starts, recovering after context compaction, picking next work after finishing a task, checking what's in progress or coming up, viewing or prioritizing the issue board, or choosing between competing tasks. Also use when the user wants to triage, file, or review bugs. This skill loads live Linear board state and workflow rules needed to make correct work-sequencing decisions."
---

# Linear Session — Project Context & Issue Lifecycle

## Current State

### In Progress

!`linear issue list -s started`

### Upcoming (Backlog, Triage & Unstarted)

!`linear issue list -s backlog -s triage -s unstarted -A`

### Current Branch Issue

!`linear issue view`

## What to Work on Next

After loading context above, decide what to work on:

1. **If on a feature branch with an in-progress issue** — continue that work
2. **If on main with no active issue** — pick the highest-priority unstarted issue from the list above
3. **If the user has a specific request** — find or create the matching issue first (see Starting Work below)

## Starting Work

NEVER start work until you have a Linear issue and have started it:

1. **Check the PRD** — Re-read the PRD in `docs/` to verify the issue captures all relevant requirements. If misaligned, notify the user and offer to update the issue before starting.
2. **Create issue if needed** — If no issue exists, create one first:
   ```bash
   linear issue create -t "Title" -d "Description"
   ```
3. **Start the issue** — This creates a branch and moves the issue to In Progress:
   ```bash
   linear issue start <ID>
   ```

## Bugs and Ad-Hoc Work

When bugs or new requirements are discovered during a session:

1. **Create a Linear issue first** — Before writing any code, file the bug/task with a clear description, reproduction steps, and acceptance/verification criteria
2. **Start the issue** — `linear issue start <ID>` to create a branch and move to In Progress
3. **Then implement** — Follow the normal workflow (branch → commit → PR → merge)

Never fix bugs or implement new work without a corresponding Linear issue.

## Issue Triage Rules

### Needs Triage

Issues marked "Needs triage" require user confirmation before work begins:

1. List issues with "Needs triage" label
2. Read issue title and description
3. Ask the user to confirm details and remove ambiguity
4. Pull relevant requirements from PRD
5. Update the issue with clear description, reproduction steps, and acceptance criteria

### Unconfirmed

Issues marked "Unconfirmed" are off-limits unless the user explicitly asks for help confirming them. Never list them as ready for work. If the user asks for help:

1. Read issue title and description
2. Ask the user to confirm details and remove ambiguity
3. Investigate and find root cause together
4. If confirmed as needing a fix, update the issue with description, repro steps, and criteria
5. End the session and follow `/linear-landing` handoff procedures

## Quick Reference

```bash
linear issue list -s backlog -s triage -s unstarted -A  # All actionable issues
linear issue list -s started   # In-progress work
linear issue list -A           # All assignees
linear issue view              # Current branch's issue
linear issue view -w           # Open current issue in browser
linear issue start <ID>        # Start issue, create branch
linear issue create            # Create new issue (interactive)
linear issue create -t "Title" -d "Description"  # Non-interactive
linear issue update            # Update current issue
linear issue comment add       # Add comment to current issue
linear project list            # Active projects
linear project view            # Project details
```

## Configuration

Linear CLI is configured via `.linear.toml` in the project root. Do not modify this file. Run `linear config` if reconfiguration is needed.

### Direct API (escape hatch)

For queries the CLI doesn't cover, use the GraphQL API directly:

```bash
linear schema -o /tmp/linear-schema.graphql
curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $(linear auth token)" \
  -d '{"query": "{ viewer { assignedIssues(first: 20) { nodes { identifier title state { name } priority } } } }"}'
```
