# F43: A click on a window in leader key mode focuses it and ends leader key mode

## Request

> 1. in leader key mode, clicking an app window should focus it and exit leader key mode

Source: [requirements-as-written.md, section 22](../requirements-as-written.md).

## What exists

- The overlay doesn't receive clicks. A click is sent to the window under the pointer. The app of that window gives it focus.
- The event tap receives only key events. Leader key mode continues after a click. The overlay stays on the screen.

## What to build

The behaviour is described in [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode).

- End leader key mode on a mouse down event while leader key mode is active. The click isn't stopped.
- A click on a tiled window behind the focused window of a carousel is described in [F44](F44-click-tiles-window-behind.md).

## Acceptance criteria

- [ ] Leader key, then a click on a window of another container: that window has focus. Leader key mode ended. The overlay isn't shown.
- [ ] Leader key, then a click on a floating window: that window has focus. Leader key mode ended. Windows don't move.
- [ ] The next key press after the click goes to the clicked window.

## Proof needed

A `tiller-proof` run with a click step, screenshots after each click, and the log.
