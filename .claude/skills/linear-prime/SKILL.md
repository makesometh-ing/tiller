---
name: linear-prime
description: Load current Linear project context. Run at session start to orient on active work, blockers, and priorities. Use after compaction to re-establish project context.
---

# Prime — Linear Project Context

Workflow rules, command reference, and session protocol are in AGENTS.md.

## In Progress

!`linear issue list -s started`

## Upcoming (Backlog, Triage & Unstarted)

!`linear issue list -s backlog -s triage -s unstarted -A`

## Current Branch Issue

!`linear issue view`
