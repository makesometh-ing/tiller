# F13: New, closed, minimized and hidden windows

## Request

Slice 1 excluded "windows opened after a layout is applied". The owner's comment: "perfect". Source: [requirements-as-written.md, section 5](../requirements-as-written.md).

The owner approved the behaviour for minimized windows and the windows of hidden apps: "yes". Source: [requirements-as-written.md, section 15](../requirements-as-written.md).

The owner reported a problem: with Tiller running, ⌘H hid Finder, and the other windows weren't arranged again.

## What exists

The behaviour is described in [PRD.md, section 7 "Windows"](../PRD.md#7-windows).

- `WindowObserver` in `Sources/Tiller/WindowObserver.swift` adds an Accessibility observer to each managed app for a focused window change and a created window. It adds the destroyed, minimized and unminimized notifications to each window. It also reads the `NSWorkspace` notifications for an app activated, hidden, shown, launched and quit.
- `Controller.syncWindows` reads the window list after each window notification and changes each workspace:
  - A window that isn't in the list is removed from its carousel. A closed window writes `window.closed`. A minimized window, a window of a hidden app and a window that isn't on the screen write `window.removed`. Their ring position is saved in `Workspace.savedPositions`.
  - A tiled window with a saved position is put back with `Workspace.restore`: same container, same ring index, as the focused window of that container. It writes `window.restored`.
  - Another tiled window that isn't in a workspace is put into the focused container after the focused window with `Workspace.insert`, and gets focus. It writes `window.opened`.
  - The frames of the changed carousels are then set. One `action.done` line with the action `window-change` gives the latency from the first notification.
- The `--proof` handler of Tiller has the `window:` steps for the test windows app and the `app:hide:` and `app:show:` steps. `tiller-proof` checks the ring position of each window after these steps.

## Proof

[F13-window-lifecycle](../../Tests/Proof/F13-window-lifecycle): a proof run with the steps `1,window:open,window:open-floating,2,window:close:Test 3,window:minimize:Test 2,window:unminimize:Test 2,app:hide:com.tiller.TestWindows,app:show:com.tiller.TestWindows,window:open,l,esc`. All steps pass:

- A new test window is put after the focused window and becomes the focused window.
- The fixed-size test window doesn't change a container.
- A closed and a minimized test window are removed at once. The other windows of the carousel are arranged again.
- An unminimized test window goes back to its container and ring index.
- After the test windows app is hidden and shown, each window has the same container, ring index and frame as before.

`finder/` is a second run with `--apps com.apple.finder`. Hiding Finder removes its windows and arranges the test windows again. Showing Finder puts its windows back at their ring positions.

Each change writes one `action=window-change` line. Tiller's own frame and focus changes don't cause a second arrangement. From the notification to the new frames: 21 to 32 ms for a single window, 25 to 68 ms for a hidden or shown app. `scripts/check-log.py` passes on both logs. The screen recordings are `run.mov` and `finder/run.mov`.
