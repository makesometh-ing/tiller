# F22: Enable and disable Tiller from the menu bar

Status: **Not done**

## Request

> as well as a menu bar option to toggle enable/disable for Tiller.

> can we combo 2 and 3? also, that default needs to be leader -> Q OR global shortcut -> shift command + T (I hope that doesn't conflict) otherwise, something else with T.

Source: [requirements-as-written.md, sections 10 and 16](../requirements-as-written.md).

## What exists

Mockups only: three menu designs in [menu-bar-menu.html](../mockups/menu-bar-menu.html). Three designs that combine the switch and the shortcut are in [menu-bar-menu-v2.html](../mockups/menu-bar-menu-v2.html).

## Decisions

- When Tiller is off, the leader key and the global shortcuts pass to the focused app. Windows stay where they are.
- The menu is variant A in [menu-bar-menu-v2.html](../mockups/menu-bar-menu-v2.html): a "Tiller" row with the global shortcut in grey before a switch.
- The default global shortcut is `⌃⌥⌘ T`. It doesn't need a Hyper key. `⇧⌘T` isn't used, because Safari, Chrome, Firefox, VS Code and Finder use it. `⌃⌥T` isn't used, because Rectangle uses it. `⌥⌘T` isn't used, because Finder uses it.
- `Q` is shown in the key bar of leader key mode, at the right end, next to `?` and `Esc`.
- The default action key in leader key mode is `Q`. It turns Tiller off. With Tiller off, the leader key goes to the focused app. Only the global shortcut and the menu turn Tiller on.

## Open items

- Build the menu, the `Q` key and the global shortcut.
