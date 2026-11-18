# B17: Focus goes to another window of the carousel after a child window is closed

PRD: [section 7 "Windows"](../PRD.md#7-windows) and section 15 "Proof and test tools".

## Problem

> When I open a child window from something like wechat, maybe an image, then close it, the focused window is not always its parent, but another window in the same container.

Source: [requirements-as-written.md, section 25](../requirements-as-written.md).

After the focused window of a carousel was closed, Tiller gave focus to the window at its ring index. A new window is put after the focused window. When the new window was closed, the window after it in the ring order got focus, not the window that opened it.

## Events

The owner's log at 18:54 GMT on 2026-11-18, Full Screen layout:

1. Container 1 contains the WeChat main window, Slack and other windows. The WeChat main window is the focused window of the carousel and has focus.
2. The owner clicks an image in WeChat (18:54:25.617). WeChat opens an image viewer window, window 15752. Its subrole is `AXStandardWindow` and its size can be set, so it is tiled. Tiller puts it after the WeChat main window, at ring index 6, as the focused window.
3. The owner clicks the close button of the image viewer (18:54:28.700). WeChat gives focus to its main window. The WeChat main window comes to the front.
4. The focus change finds that window 15752 doesn't exist, so it is handled as a window change. Tiller removes window 15752 from the carousel. The window at ring index 6, Slack (window 15224), becomes the focused window of the carousel.
5. Tiller gives focus to Slack (`focused` 15224). Slack comes to the front of the WeChat main window.
6. At 18:54:29, the owner clicks the WeChat main window to focus it again.

The same events occurred at 18:54:41 with window 15762.

The proof run `before-fix/` gives the same result with test windows. After a new window is closed or minimized, the window after it in the ring order gets focus.

## Fix

The behaviour is described in [PRD.md, section 7 "Windows"](../PRD.md#7-windows).

- `Container.focusHistory` in `Sources/TillerCore/Workspace.swift` contains the windows of the carousel that were the focused window before the current focused window. The last window was the focused window just before the current focused window.
- Each `Workspace` function that changes the focused window of a carousel adds the old focused window to the focus history of that carousel: `focusWindow(offset:)`, `focus(window:)`, `insert`, `remove`, `restore` and `moveFocusedWindow(offset:)`.
- `Workspace.remove` makes the last window of the focus history the focused window when the removed window was the focused window. When the focus history is empty, the window at the ring index of the removed window becomes the focused window, as before.
- When the last window of the focus history is removed from the carousel, the focus history is cleared.
- `Controller.syncWindows` in `Sources/Tiller/Controller.swift` doesn't change. It gives focus to the new focused window of the focused container. When the app already gave focus to that window, Tiller doesn't make a focus call. The wrong window then doesn't come to the front.
- After a `window:close:` or `window:minimize:` step for the focused window, the proof runner checks that the window focused just before it gets focus. When that window isn't in the carousel, it checks that the window at the ring index of the removed window gets focus.

## Proof

[B17-focus-after-close](../../Tests/Proof/B17-focus-after-close): the same steps before and after the fix, with 5 test windows in the Full Screen layout. Before the fix, 2 of the 12 steps fail. After the fix, all steps pass. From the notification to the end of the window change, a close or a minimize takes 23 to 45 ms.
