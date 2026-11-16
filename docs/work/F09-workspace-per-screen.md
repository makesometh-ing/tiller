# F09: One workspace for each screen

Status: **Done**

## Request

> By the way, we're also going to allow separate and disparate layouts PER monitor. this is out of the box and a default feature. a layout i decide on one monitor will not and cannot be applied to another monitor (there will be a command to duplicate a layout to another monitor later on, but not now, but this should be kept in mind so its architected well from the start with easy to change and extendable code)

> I meant singleton per screen

Source: [requirements-as-written.md, section 5](../requirements-as-written.md).

## What exists

- Each screen has exactly one workspace with its own layout.
- The workspaces are stored in a dictionary with the display UUID as the key. The display UUID stays the same after a screen is disconnected and connected again.
- A layout key changes only the workspace of the screen with the focused window.

## Decisions

- macOS Spaces aren't used. Tiller doesn't move windows off-screen.

## Proof

Unit test `workspacesOfTwoScreensAreIndependent` in `WorkspaceTests.swift`. The end-to-end runs used one screen, because the Mac has one screen.

## Open items

- The command to copy a layout to another screen isn't built.
- Other multi-screen gaps are in [F27](F27-multiple-screens.md).
