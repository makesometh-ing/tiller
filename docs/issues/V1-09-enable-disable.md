# V1-09: Enable and disable Tiller from the menu bar

Work file: [F22](../work/F22-enable-disable.md)

## What to build

- The menu bar menu is variant A in [menu-bar-menu-v2.html](../mockups/menu-bar-menu-v2.html): a "Tiller" row with the global shortcut in grey before a switch.
- `Q` in leader key mode turns Tiller off. It is shown in the key bar, at the right end, next to `?` and `Esc`.
- The global shortcut `⌃⌥⌘ T` turns Tiller on and off. It can be recorded in the settings.
- The "Enable Tiller" switch on the General page is the same setting.
- When Tiller is off, the leader key and the global shortcuts go to the focused app. Windows stay where they are.
- When Tiller is on again, the windows are arranged again in their containers.

## Acceptance criteria

- [ ] With Tiller off, the leader key reaches a test window.
- [ ] With Tiller off, a window doesn't move.
- [ ] With Tiller on again, the leader key starts leader key mode.
- [ ] `⌃⌥⌘ T` turns Tiller off and on.
- [ ] Leader key, then `Q`, turns Tiller off.

## Proof

A `tiller-proof` run with the key log of the test windows, and screenshots of the menu in the light and the dark appearance.
