# V1-01: Put new windows in a container, and remove closed windows

Work file: [F13](../work/F13-new-windows.md)

## Problem

A window that opens after a layout is applied stays outside every container until the next layout key. A closed window stays in its container until the next action.

## What to build

- Tiller reads the Accessibility notifications for a created window, a closed window and a minimized window.
- A new tiled window goes into the focused container, after the focused window. It becomes the focused window.
- A new floating window doesn't change a container. It doesn't change the focus.
- A closed window is removed from its container at once. The other windows of the carousel are arranged again.
- A minimized window, or a window of a hidden app, is removed from its carousel. Its container and ring position are recorded.
- When that window comes back, it goes back into the same container, at the same ring position. It becomes the focused window of that container. If that container doesn't exist, the window goes into the focused container.

## Acceptance criteria

- [ ] A test window opened after a layout key goes into the focused container, after the focused window.
- [ ] The fixed-size test window opened after a layout key doesn't change a container.
- [ ] A closed test window is removed from its carousel at once.
- [ ] A minimized test window is removed from its carousel at once.
- [ ] An unminimized test window goes back into its container, at its ring position.
- [ ] A hidden app and an app shown again give the same result as a minimized and an unminimized window.
- [ ] Each change is logged with its latency.

## Proof

A `tiller-proof` run that opens, closes and minimizes test windows after a layout key: screenshots after each step and the log.
