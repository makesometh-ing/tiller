# F33: Move a window to another container

## Request

> and one thing we never addressed - how do we move windows between containers? there needs to be a way to do this reliably, too. Assuming that moving a window to a new container will make it the "focused" window in the new container. we also shouldn't then focus the new container, since the use likely wants to shift other windows about.

> fine with me

Source: [requirements-as-written.md, section 15](../requirements-as-written.md).

## What exists

There isn't an action to move a window to another container.

## What to build

The behaviour is described in [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode).

## Acceptance criteria

- [ ] `⇧J` in the Vertical Split layout moves the focused window from container 1 to container 2.
- [ ] The moved window is in front of the carousel of container 2.
- [ ] Focus is on the next window of container 1.
- [ ] A move into an empty container works.
- [ ] `⇧J` and `⇧K` have an "Exit after" checkbox on the Shortcuts page. It is off by default. Leader key mode continues after the move.
- [ ] The latency of each move is logged. The screen recording shows if the move causes flicker.

## Proof needed

A `tiller-proof` run with screenshots after each move, a screen recording, and the log.
