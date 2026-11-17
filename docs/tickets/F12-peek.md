# F12: Peek: the P key

## Request

> the other thing we will need to support is also "peek full screen" - in any layout that isn't pre-set layout 1, we can "pop" a screen into full screen mode (not macOs full screen mode) but to the size of the workspace. I think aerospace does this. pressing the same key again will return the screen back to its container.

> we will do this, too

> agree

Source: [requirements-as-written.md, sections 6 and 8](../requirements-as-written.md).

## What exists

Nothing is built.

## What to build

The behaviour is described in [PRD.md, section 7 "Windows"](../PRD.md#7-windows).

## Acceptance criteria

- [ ] `P` in the Vertical Split layout fills the workspace with the focused window.
- [ ] `P` again puts the window back at its carousel frame.
- [ ] `J`, `K`, `H` or `L` during peek returns the window to its container.
- [ ] `P` in the Full Screen layout doesn't move a window.
- [ ] The window pill and the key bar show `P`, in the light and the dark appearance.

## Proof needed

A `tiller-proof` run with screenshots before peek, during peek and after peek, and the log with the latency of each step.
