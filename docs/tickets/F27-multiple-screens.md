# F27: Multiple screens

## Request

> a layout i decide on one monitor will not and cannot be applied to another monitor (there will be a command to duplicate a layout to another monitor later on, but not now, but this should be kept in mind so its architected well from the start with easy to change and extendable code)

Source: [requirements-as-written.md, section 5](../requirements-as-written.md).

## What exists

- One workspace for each screen is built, in [F09: One workspace for each screen](F09-workspace-per-screen.md).
- The audit of the project found these problems:
  - A workspace isn't removed when its screen is disconnected.
  - The workspace frame isn't updated when the resolution, the Dock or the menu bar changes. The new frame is used after the next layout key press.
  - A window moved to another screen stays in the workspace of its old screen.
  - The key bar and the key list open on the main screen only.
  - Overlay panels of a disconnected screen aren't removed.

## Proof

Multiple screens aren't tested end to end. Your Mac has only one screen.

## What to build

The behaviour is described in [PRD.md, section 8 "Screens"](../PRD.md#8-screens).

## Acceptance criteria

- [ ] With a second screen connected, each problem listed under "What exists" is fixed.
- [ ] A layout key on one screen doesn't move a window on the other screen.

## Proof needed

A `tiller-proof` run with a second screen connected to your Mac, for example an external display or an iPad with Sidecar: screenshots of both screens and the log.
