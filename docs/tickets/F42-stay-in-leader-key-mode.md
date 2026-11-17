# F42: Stay in leader key mode after an action

## Request

> also, I think as part of the config, we need to decide if a shortcut should exit leader key mode or stay in leader key mode. for switch windows in the container and moving between containers, and moving windows between containers, I think it should stay in leader key mode by default, but there should be a column "exit leader key mode" with a checkbox for each action. what do you think?

Source: [requirements-as-written.md, section 18](../requirements-as-written.md) and section 19 "Shortcuts page with the "Exit after" column".

## What exists

Built as variant 1 in [exit-leader-key-mode.html](../mockups/exit-leader-key-mode.html). The behaviour is described in [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode) and [section 11 "Settings window and menu bar menu"](../PRD.md#11-settings-window-and-menu-bar-menu).

- Each action on the Shortcuts page has an "Exit after" checkbox. `H`, `L`, `J`, `K`, `⇧J` and `⇧K` keep leader key mode by default. The checkbox of "Turn Tiller off" is checked and disabled.
- With leader key mode active after an action, the overlay is updated 38 to 48 ms after the key press.
- The "Global shortcuts" group contains the leader key and the shortcut to turn Tiller on and off. Both can be recorded.

## Proof

[F42-stay-in-leader-key-mode](../../Tests/Proof/F42-stay-in-leader-key-mode): a run in the dark appearance with 19 steps and a run in the light appearance with 8 steps. Unit tests `focusActionsKeepLeaderKeyModeByDefault` and `toggleChordAndExitAfterAfterJSON`.

