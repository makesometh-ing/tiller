# F43: A click on a window in leader key mode focuses it and ends leader key mode

## Request

> 1. in leader key mode, clicking an app window should focus it and exit leader key mode

Source: [requirements-as-written.md, section 22](../requirements-as-written.md).

## What exists

The behaviour is described in [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode).

- `LeaderKey` in `Sources/Tiller/LeaderKey.swift` has a second event tap for mouse down events. It is a listen-only tap, so it can't stop or delay a click.
- A mouse down while leader key mode is active ends leader key mode. The overlay is hidden. The app under the pointer receives the click and gives the clicked window focus.
- A mouse down on the key bar doesn't end leader key mode. The key bar can then be dragged.
- The `leader.end` event with the reason `click` gives the click point and the time from the click to the tap callback (`clickToTapMs`). The `overlay.hidden` event gives the time to hide the overlay (`hideMs`).
- The `click:` proof step clicks a window. See [PRD.md, section 15 "Proof and test tools"](../PRD.md#15-proof-and-test-tools). The proof runner checks that leader key mode ended after each click. It checks that a `pass:` chord after a click reaches the clicked window.
- A click on a tiled window behind the focused window of a carousel is described in [F44](F44-click-tiles-window-behind.md).

## Proof

[F43-click-ends-leader-key-mode](../../Tests/Proof/F43-click-ends-leader-key-mode): a proof run with the steps `2,leader,click:container2,pass:ctrl+opt+shift+y,leader,click:floating,pass:ctrl+opt+shift+y,leader,click:container1,leader,esc`. All steps pass. After each click, leader key mode ended, the overlay isn't shown and the clicked window has focus. A click on the floating window doesn't move a window. The chord after each click reached the clicked window. From the click to the tap callback: 0.8 to 1.8 ms. Overlay hidden: 0.8 to 1.8 ms.
