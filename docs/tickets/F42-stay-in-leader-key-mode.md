# F42: Stay in leader key mode after an action

## Request

> also, I think as part of the config, we need to decide if a shortcut should exit leader key mode or stay in leader key mode. for switch windows in the container and moving between containers, and moving windows between containers, I think it should stay in leader key mode by default, but there should be a column "exit leader key mode" with a checkbox for each action. what do you think?

Source: [requirements-as-written.md, section 18](../requirements-as-written.md) and section 19 "Shortcuts page with the "Exit after" column".

## What exists

Each action ends leader key mode.

## What to build

The behaviour is described in [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode) and [section 11 "Settings window and menu bar menu"](../PRD.md#11-settings-window-and-menu-bar-menu).

- Approved design: variant 1 in [exit-leader-key-mode.html](../mockups/exit-leader-key-mode.html), a checkbox column with the heading "Exit after".
- The "Global shortcuts" group on the Shortcuts page contains the leader key and the shortcut to turn Tiller on and off. Both can be recorded.

## Acceptance criteria

- [x] With the default settings, leader, then `L` three times, moves focus three windows. The overlay stays open between the key presses.
- [x] With the default settings, leader, then `1`, applies the layout and ends leader key mode.
- [x] A changed checkbox is saved and applied without a relaunch.
- [x] The shortcut to turn Tiller on and off can be recorded. The recorded chord turns Tiller off and on.
- [x] `Q` always ends leader key mode. Its checkbox can't be changed.
- [x] The overlay is updated after each action in leader key mode, within the latency of the action.

## Proof needed

A `tiller-proof` run with `L` pressed three times after one leader key press, screenshots of the overlay after each press, and screenshots of the Shortcuts page in the light and the dark appearance.
