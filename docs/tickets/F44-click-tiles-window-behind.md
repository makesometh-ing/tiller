# F44: A click on a window behind the focused window makes it the focused window of its carousel

## Request

> 2. clicking a window BEHIND the focused window, should focus it and TILE IT. (like pressing h or l in leader key mode to go to the next window)

Source: [requirements-as-written.md, section 22](../requirements-as-written.md).

## What exists

The behaviour is described in [PRD.md, section 7 "Windows"](../PRD.md#7-windows).

- `WindowObserver` in `Sources/Tiller/WindowObserver.swift` adds an Accessibility observer for the focused window changed notification of each managed app. It also reads the app activation notification of `NSWorkspace`. Apps that start after Tiller are observed at their launch or at their first activation.
- `Controller.syncFocus` reads the system focused window after each notification. When the window is a tiled window of a workspace and isn't the focused window of that workspace, it becomes the focused window of its carousel and its container. The frames of the carousel are then set, as with `H`, `L`, `J` and `K`.
- A focus change made by Tiller doesn't change the workspace: the window that got focus is already the focused window of the workspace. A focus change without a click in the second after Tiller's focus call is read again after that second.
- Each arrangement after a focus change writes an `action.done` event with the action `focus-change`, the trigger (`click` or `other`), the container, the moved windows, the time from the click to the notification and the time from the click to the new frames.
- With Tiller off, focus changes don't move windows.

## Proof

[F44-click-tiles-window-behind](../../Tests/Proof/F44-click-tiles-window-behind): a proof run with the steps `1,l,h,click:next,click:previous,2,click:container2,leader,click:next,leader,click:container1,j,l,esc`. All steps pass. A click on the right edge of the carousel gives the same frames as `L`. A click on the left edge gives the same frames as `H`. A click in container 2 makes container 2 the focused container and doesn't change the frames of container 1. Clicks work in leader key mode and out of leader key mode. The log contains one `action=focus-change` line for each click and none for Tiller's own focus changes. From the click to the new frames: 29 to 55 ms. The screen recording is `run.mov`.
