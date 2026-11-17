# F32: Show Tiller in the menu bar, the Dock or both

## Request

> needs an option about Dock only, Menu bar only, Menu bar and Dock thing.

Source: [requirements-as-written.md, section 14](../requirements-as-written.md).

## What exists

- The General page is the first page of the settings window. It contains the "Show Tiller in" segmented control of variant 2 in [general-page.html](../mockups/general-page.html). The selected segment is filled with the theme accent color.
- The value is stored in the `showIn` key of the Tiller defaults. The default is "Menu bar". A proof run uses its own defaults domain and starts with "Menu bar".
- "Menu bar": the status item is shown and the activation policy is `.accessory`. "Dock": the status item is removed and the activation policy is `.regular`. "Both": the status item is shown and the activation policy is `.regular`.
- A change is applied at once. After a change to `.accessory`, the settings window is shown in front again 0.2 seconds later.
- At launch, the value is applied in `applicationDidFinishLaunching`. `LSUIElement` is still true, so the Dock icon isn't shown at launch with "Menu bar".
- A click on the Dock icon, or `open Tiller.app` while Tiller runs, opens the settings window. The Dock menu contains "Settings…".
- With "Dock" or "Both", the Tiller menu in the app menu bar contains "Settings…" (⌘,) and "Quit Tiller".

## What to build

The behaviour is described in [PRD.md, section 11 "Settings window and menu bar menu"](../PRD.md#11-settings-window-and-menu-bar-menu).

## Acceptance criteria

- [x] For each "Show Tiller in" value, the Tiller icon is shown only in the selected places.
- [x] With "Dock only", a click on the Dock icon opens the settings window.
- [x] The "Show Tiller in" value is kept after a relaunch.
- [x] The General page matches variant 2 in the light and the dark appearance.

## Proof needed

Screenshots of the menu bar and the Dock for each value, in the light and the dark appearance.

## Proof

All files are in [Tests/Proof/F32-menu-bar-and-dock](../../Tests/Proof/F32-menu-bar-and-dock). Each value was set with a real mouse click on its segment.

- General page: [general-page-light.png](../../Tests/Proof/F32-menu-bar-and-dock/general-page-light.png) and [general-page-dark.png](../../Tests/Proof/F32-menu-bar-and-dock/general-page-dark.png).
- Menu bar, Dock and settings window for each value, in the [light](../../Tests/Proof/F32-menu-bar-and-dock/light) and the [dark](../../Tests/Proof/F32-menu-bar-and-dock/dark) appearance: `<value>-menubar.png`, `<value>-dock.png` and `<value>-settings-window.png`. `state-<value>.txt` contains the System Events state of Tiller, the saved value and the front window after the change.
- Relaunch with each saved value, and the Dock read every 0.1 seconds during the launch: [relaunch.txt](../../Tests/Proof/F32-menu-bar-and-dock/relaunch.txt).
- Settings window opened by `open Tiller.app` and by a click on the Dock icon, the Dock menu and the app menu with "Dock": [reopen-and-menus.txt](../../Tests/Proof/F32-menu-bar-and-dock/reopen-and-menus.txt), [dock-icon-click-settings-window.png](../../Tests/Proof/F32-menu-bar-and-dock/dock-icon-click-settings-window.png), [dock-menu.png](../../Tests/Proof/F32-menu-bar-and-dock/dock-menu.png) and [dock-app-menu.png](../../Tests/Proof/F32-menu-bar-and-dock/dock-app-menu.png).
- End-to-end test: [e2e/summary.md](../../Tests/Proof/F32-menu-bar-and-dock/e2e/summary.md).
