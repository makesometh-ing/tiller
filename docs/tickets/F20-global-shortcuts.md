# F20: Global shortcuts: a second shortcut for each action

## Request

> we should be able to define a leader key layer key AND a non-leader shortcut (two columns) for each key except leader key. give me a mockup to check design, before we start coding.

Source: [requirements-as-written.md, section 10](../requirements-as-written.md).

## What exists

Mockups: [settings-v2.html](../mockups/settings-v2.html).

The shortcut to turn Tiller on and off can be recorded in the "Global shortcuts" group of the Shortcuts page. It was built in [F42](F42-stay-in-leader-key-mode.md). The other actions don't have a global shortcut yet.

## What to build

The behaviour is described in [PRD.md, section 11 "Settings window and menu bar menu"](../PRD.md#11-settings-window-and-menu-bar-menu).

## Acceptance criteria

- [ ] A Hyper global shortcut for "Focus next window" does the action.
- [ ] The shortcut field doesn't save a chord that is already a global shortcut.
- [ ] The shortcut field doesn't save the chord of the leader key.
- [ ] The Shortcuts page matches variant 3 in `settings-v2.html` in the light and the dark appearance.

## Proof needed

A `tiller-proof` run with `--keys` set to global shortcuts, and screenshots of the Shortcuts page.
