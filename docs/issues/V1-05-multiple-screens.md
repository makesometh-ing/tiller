# V1-05: Multiple screens: connect, disconnect and move windows

Work file: [F27](../work/F27-multiple-screens.md)

## What to build

- The workspace of a disconnected screen is removed. Its overlay panels are removed.
- The workspace frame is updated when the resolution, the Dock or the menu bar changes. The windows are arranged again at once.
- A tiled window moved to another screen is removed from the workspace of its old screen. It goes into the focused container of the new screen.
- The key bar and the key list open on the screen of the focused window.

## Acceptance criteria

- [ ] Each item above works with a second screen.
- [ ] A layout key on one screen doesn't move a window on the other screen.

## Proof

A `tiller-proof` run with a second screen connected to your Mac, for example an external display or an iPad with Sidecar: screenshots of both screens and the log.
