# B16: The other windows of a carousel weren't tiled after its focused window was closed

PRD: [section 7 "Windows"](../PRD.md#7-windows) and section 13 "Logging and diagnostics".

## Problem

> I just closed finder with the red x button and the rest of the windows didn' tile

Source: [requirements-as-written.md, section 24](../requirements-as-written.md).

After the focused window of a carousel was closed, Tiller set the frames of the other windows of the carousel, but it didn't raise the new focused window. The new focused window stayed behind the windows before and after it in the ring order, so the carousel looked like windows in a cascade.

The window server order is the front-to-back order of all windows on the screen. Only the window server order shows which window of a carousel is in front. The frames don't show it.

## Events

The owner's log at 23:15 GMT on 2026-11-17, Vertical Split layout:

1. Container 2 contains Slack, WeChat and Dia, in ring order. WeChat is the focused window of the carousel and has focus.
2. A Finder window opens (23:15:15.539). Tiller puts it after WeChat, at ring index 2, and Finder has focus. The ring order is Slack, WeChat, Finder, Dia.
3. The owner clicks the close button of the Finder window (23:15:17.497). Finder stays the active app. Finder doesn't have a focused window.
4. Tiller removes the Finder window from the carousel. Dia is now at ring index 2 and becomes the focused window of the carousel. Tiller sets the frames of Dia and Slack (`moved` 2).
5. Tiller doesn't call `AXRaise` or give focus to any window (`focusMs` 0). Tiller gave focus only to a new window.
6. In the window server order, WeChat stays in front of Dia, because WeChat had focus before Finder. WeChat has the frame at the start of the container and covers most of Dia.
7. The carousel stays in this state until a click on a window or a focus key.

The same problem occurred at 23:15:13, with a focus change before the window change:

1. The owner clicks the close button of System Settings in container 1. System Settings quits when its last window closes.
2. macOS makes another app active. Its focused window is in container 2.
3. The focus change is read first. Tiller removes the System Settings window and makes container 2 the focused container (`focus-change`, `moved` 2). The new focused window of container 1 isn't raised.
4. At 23:15:22, the owner clicks a window in container 1 to arrange it.

The proof run `before-fix/` gives the same result with test windows, Finder and Disk Utility. Disk Utility also quits when its last window closes. After each close, the system focused window is none and Finder is the frontmost app. The new focused window of the carousel is behind one or two other windows of its carousel.

## Fix

The behaviour is described in [PRD.md, section 7 "Windows"](../PRD.md#7-windows).

- `Workspace.newFrontWindows(since:)` in `Sources/TillerCore/Workspace.swift` compares the workspace before and after the removal. It returns the new focused window of the focused container when the focused window of the workspace was removed, and the new focused windows of the other containers whose focused window was removed.
- `Controller.syncWindows` in `Sources/Tiller/Controller.swift` raises the new focused windows of the other containers with `AXRaise`. Then it gives focus to the new focused window of the focused container. It doesn't read the system focused window in this case. When a raised window is a window of the active app and no other window gets focus, the system focused window gets focus again, because `AXRaise` gave focus to the raised window.
- `Controller.syncFocus` sends a focus change to `syncWindows` when a window of a workspace doesn't exist. Focus then stays in the container of the closed window.
- The `action.done` event with the action `window-change` has two new fields: `raised` and `focused`.
- The proof runner has a `close:focused` step. It clicks the close button of the system focused window. After close and minimize steps, the proof runner checks the window server order of each carousel and writes it to `zorder.log`.

## Proof

[B16-close-focused-window](../../Tests/Proof/B16-close-focused-window): the same steps before and after the fix, with 6 test windows, a Finder window and Disk Utility in the Vertical Split layout. Before the fix, 4 of the 10 steps fail. After the fix, all steps pass. From the notification to the focus call, a close takes 40 to 86 ms.

## Known gaps

- `AXRaise` doesn't put a window of an inactive app in front of the windows of the active app. When a window of the active app is in another carousel, in front of the new focused window of that carousel, the new focused window stays behind it.
