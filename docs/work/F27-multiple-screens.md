# F27: Multiple screens

Status: **Not done**

## Request

> a layout i decide on one monitor will not and cannot be applied to another monitor (there will be a command to duplicate a layout to another monitor later on, but not now, but this should be kept in mind so its architected well from the start with easy to change and extendable code)

Source: [requirements-as-written.md, section 5](../requirements-as-written.md).

## What exists

- One workspace for each screen is built. See [F09](F09-workspace-per-screen.md).
- The audit found these gaps:
  - A workspace isn't removed when its screen is disconnected.
  - The workspace frame isn't updated when the resolution, the Dock or the menu bar changes. The new frame is used at the next layout key.
  - A window moved to another screen stays in the workspace of its old screen.
  - The key bar and the key list open on the main screen only.
  - Overlay panels of a disconnected screen aren't removed.

## Proof

Not tested end to end. Your Mac has one screen.

## Open items

- Fix the gaps.
- Build the command to copy a layout to another screen.
