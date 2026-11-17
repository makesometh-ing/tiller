# Tickets

Each feature, bug and research item is one file in this folder. `F` is a feature, `B` is a bug and `R` is a research item. The behaviour of each feature is described in [PRD.md](../PRD.md). A ticket file doesn't copy the PRD.

A ticket file contains these sections, when they apply:

- Request: the owner's words, from [requirements-as-written.md](../requirements-as-written.md).
- Problem, Events and Fix: for a bug.
- What exists: the current behaviour and code.
- Proof: the proof bundle of the done work.
- Known gaps: open problems of a done ticket.
- What to build, Acceptance criteria and Proof needed: for an open ticket.

[tickets.jsonl](tickets.jsonl) is the only list of status, order and dependencies. Each line is one ticket:

- `id`, `title`, `type` and `file`.
- `status`: `done`, `todo`, or `blocked` when an answer from the owner is needed before the work starts.
- `order`: the build order of an open ticket. A ticket comes after each ticket in `depends_on`.
- `priority`: `P1` is needed for daily use on the owner's Mac. `P2` is a setting or a second screen. `P3` is needed for a public release. `P4` is after v1.
- `depends_on`: the tickets to build first.
- `blocked_by`: the approvals and answers needed from the owner.
