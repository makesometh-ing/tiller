# F42: Stay in leader key mode after an action

## Request

> also, I think as part of the config, we need to decide if a shortcut should exit leader key mode or stay in leader key mode. for switch windows in the container and moving between containers, and moving windows between containers, I think it should stay in leader key mode by default, but there should be a column "exit leader key mode" with a checkbox for each action. what do you think?

Source: [requirements-as-written.md, section 18](../requirements-as-written.md).

## What exists

Each action ends leader key mode.

## What to build

The behaviour is described in [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode) and [section 11 "Settings window and menu bar menu"](../PRD.md#11-settings-window-and-menu-bar-menu).

- Make 3 mockups of the Shortcuts page with the "Exit leader key mode" column, in the light and the dark appearance, for approval.

## Acceptance criteria

- [ ] With the default settings, leader, then `L` three times, moves focus three windows. The overlay stays open between the key presses.
- [ ] With the default settings, leader, then `1`, applies the layout and ends leader key mode.
- [ ] A changed checkbox is saved and applied without a relaunch.
- [ ] `Q` always ends leader key mode. Its checkbox can't be changed.
- [ ] The overlay is updated after each action in leader key mode, within the latency of the action.

## Proof needed

A `tiller-proof` run with `L` pressed three times after one leader key press, screenshots of the overlay after each press, and screenshots of the Shortcuts page in the light and the dark appearance.
