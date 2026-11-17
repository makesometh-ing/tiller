# F22: Enable and disable Tiller from the menu bar

## Request

> as well as a menu bar option to toggle enable/disable for Tiller.

> can we combo 2 and 3? also, that default needs to be leader -> Q OR global shortcut -> shift command + T (I hope that doesn't conflict) otherwise, something else with T.

Source: [requirements-as-written.md, sections 10 and 16](../requirements-as-written.md).

## What exists

- The enabled state is stored in the `enabled` key of the Tiller defaults. The default is on. A proof run uses its own defaults domain and starts with Tiller on. Each change is written to the Tiller log as `setting enabled=<value>`.
- The first row of the menu bar menu is variant A in [menu-bar-menu-v2.html](../mockups/menu-bar-menu-v2.html): "Tiller", `⌃⌥⌘ T` in grey, and a switch. A `Toggle` in a menu is drawn grey, so the switch is drawn with the theme accent color.
- The General page contains an "App" group with the "Enable Tiller" switch, as variant 2 in [general-page.html](../mockups/general-page.html). "Open at login" isn't built.
- The Dock menu contains "Enable Tiller" with a check mark when Tiller is on.
- Leader key, then `Q`, turns Tiller off. `Q` is the "Turn Tiller off" action. It can be recorded on the Shortcuts page. The key bar and the key list show it in a "TILLER" section, before `?` and `Esc`. Saved shortcuts get `Q` when another action doesn't use it.
- `⌃⌥⌘ T` turns Tiller off and on. It is a fixed chord in the event tap and can't be recorded yet.
- When Tiller is off, the event tap sends each key press to the focused app, except `⌃⌥⌘ T`. When Tiller is on again, each window of each workspace is moved back to its frame in its container.

## What to build

The behaviour is described in [PRD.md, section 11 "Settings window and menu bar menu"](../PRD.md#11-settings-window-and-menu-bar-menu) and [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode).

- The `⌃⌥⌘ T` shortcut is built in this ticket as a fixed shortcut. Ticket F20 "Global shortcuts: a second shortcut for each action" makes it recordable.
- The "Enable Tiller" switch is added to the General page from ticket F32 "Show Tiller in the menu bar, the Dock or both".
- The Dock menu contains "Enable Tiller".

## Acceptance criteria

- [x] With Tiller off, a test window receives the leader key press.
- [x] With Tiller off, a window doesn't move.
- [x] With Tiller on again, the leader key starts leader key mode.
- [x] `⌃⌥⌘ T` turns Tiller off and on.
- [x] Leader key, then `Q`, turns Tiller off.

## Proof needed

A `tiller-proof` run with the key log of the test windows, and screenshots of the menu bar menu in the light and the dark appearance.

## Proof

All files are in [Tests/Proof/F22-enable-disable](../../Tests/Proof/F22-enable-disable).

- End-to-end test with the key log of the test windows: [e2e/summary.md](../../Tests/Proof/F22-enable-disable/e2e/summary.md). The steps are: layout 2, leader key then `Q` (Tiller off), the leader key and `1` reach the test windows and no window moves, `⌃⌥⌘ T` (on), layout 1, `⌃⌥⌘ T` (off), the leader key reaches the test windows, `⌃⌥⌘ T` (on), the leader key starts leader key mode. `⌃⌥⌘ T` and `Q` don't reach the test windows.
- The default steps of the end-to-end test: [e2e-default-steps/summary.md](../../Tests/Proof/F22-enable-disable/e2e-default-steps/summary.md).
- Menu bar menu with Tiller on and off, in the light and the dark appearance: [menus](../../Tests/Proof/F22-enable-disable/menus).
- General page: [general-page-light.png](../../Tests/Proof/F22-enable-disable/general-page-light.png), [general-page-dark.png](../../Tests/Proof/F22-enable-disable/general-page-dark.png) and [general-page-off.png](../../Tests/Proof/F22-enable-disable/manual/general-page-off.png).
- Key bar and key list with `Q`: [key-list-and-key-bar.png](../../Tests/Proof/F22-enable-disable/key-list/key-list-and-key-bar.png). `Q` on the Shortcuts page, read from shortcuts saved without it: [shortcuts-page-tiller-group.png](../../Tests/Proof/F22-enable-disable/manual/shortcuts-page-tiller-group.png).
- Menu bar switch clicked off and on. A window moved while Tiller is off goes back to its container when Tiller is on: [menu-switch-and-rearrange.txt](../../Tests/Proof/F22-enable-disable/manual/menu-switch-and-rearrange.txt).
- General page switch, the off state after a relaunch, and "Enable Tiller" in the Dock menu: [general-relaunch-dock-menu.txt](../../Tests/Proof/F22-enable-disable/manual/general-relaunch-dock-menu.txt), [dock-menu-on.png](../../Tests/Proof/F22-enable-disable/manual/dock-menu-on.png) and [dock-menu-off.png](../../Tests/Proof/F22-enable-disable/manual/dock-menu-off.png).
- Unit tests for saved shortcuts without `Q`: `savedShortcutsGetTheStandardChordOfANewAction`, `clearedActionStaysClearedAfterJSON` and `newActionDoesNotTakeAChordInUse` in `KeyChordTests.swift`.
