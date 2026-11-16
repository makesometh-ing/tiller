# F12: Peek: the P key

Status: **Not done**

## Request

> the other thing we will need to support is also "peek full screen" - in any layout that isn't pre-set layout 1, we can "pop" a screen into full screen mode (not macOs full screen mode) but to the size of the workspace. I think aerospace does this. pressing the same key again will return the screen back to its container.

> we will do this, too

> agree

Source: [requirements-as-written.md, sections 6 and 8](../requirements-as-written.md).

## What exists

Nothing is built.

## Decisions

- `P` in leader key mode fills the workspace with the focused window and keeps the workspace margin.
- `P` again returns the window to its container.
- A focus change to another tiled window also returns the window to its container, as in AeroSpace.
- Peek isn't used in the Full Screen layout.

## Open items

- Build peek. Add `P` to the window pill and the key bar when peek exists.
