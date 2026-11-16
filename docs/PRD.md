# Tiller product requirements

This document describes the decisions and the behaviour of Tiller as they are now. Your requirements, word for word, are in [requirements-as-written.md](requirements-as-written.md). The status of each feature and bug is in [work/README.md](work/README.md).

## 1. Product

Tiller is a tiling window manager for macOS. It is a menu bar app with almost no UI. Tiller is used through a leader key. One key chord starts leader key mode. The next key does an action.

## 2. Principles

- Latency and visible jank aren't acceptable. Each action is measured and logged.
- SIP stays enabled. Tiller uses the Accessibility API and permissions. Tiller doesn't move windows off-screen.
- Work is done in vertical slices. Each slice is real working software that can be tested.
- A task is done only with a proof bundle: logs, screenshots, screen recordings or test output. Proof bundles are stored in `Tests/Proof/<task>/`. Git ignores this folder.
- Before UI is built, at least 3 mockups are made for approval. Each mockup is shown in the light and the dark appearance. The look must match the quality of the Alcove settings window (`docs/references/ui-alcove-settings.png`).
- AeroSpace, yabai, Amethyst and Glide are used for ideas and for their fixes to known problems.

## 3. Glossary

The glossary is defined in the requirements drawing. It is copied word for word in [requirements-as-written.md, section 1](requirements-as-written.md). One term changed:

- Workspace: the workspace is a singleton per screen. Each screen has exactly one workspace with its own layout.

Terms added during the work:

| Term | Meaning |
|---|---|
| Leader key mode | The state after the leader key is pressed. Tiller reads the next key press as an action. The key press doesn't reach the focused app. |
| Tiled window | A window in a container. Tiller sets its frame. |
| Floating window | A window that isn't in a container. Tiller doesn't move, resize or focus it. |
| Ignored window | A window that Tiller doesn't handle: minimized, not on screen, above window layer 0, or a popup. |
| Container chip | The label on the top edge of a container in leader key mode. |
| Window pill | The label at the bottom-right corner of a window in leader key mode. |
| Key bar | The bar with the keys of leader key mode, at the bottom of the screen. |
| Global shortcut | A key chord that does an action without the leader key. Not built yet. |

## 4. Platform and build

- Swift 6, AppKit for the app and the panels, SwiftUI for the views. Objective-C isn't used.
- The Accessibility API moves and resizes windows. A `CGEventTap` reads key presses. The private function `_AXUIElementGetWindow` returns the window id of an Accessibility element. It works with SIP enabled.
- Required permission: Accessibility. The terminal that runs the proof runner also needs Screen Recording for `screencapture`.
- The build doesn't use Xcode. `scripts/build.sh` builds and signs the app with the Apple Development certificate. `scripts/test.sh` runs the unit tests.
- The minimum macOS version is 26.0.
- The source is published under the GPL 3.0 license, in `LICENSE`.

## 5. Layouts and carousels

- The four must-have layouts are built: Full Screen, Vertical Split, Left Two-Thirds and Right Two-Thirds. Keys: `1`, `2`, `3`, `4`.
- A layout is applied to the workspace of the screen with the focused window. The other screens don't change.
- The tiled windows on that screen are put in the containers. The focused window goes into the first container. The other windows go into the containers round-robin, from the second container.
- Container order is left to right, then top to bottom.
- Each container is a horizontal carousel or a vertical carousel. The carousel rules are the rules in the requirements drawing.
- `V` switches the focused container between horizontal and vertical.
- Planned: a layout key keeps each window in its container number. A new container is empty until a window is moved into it. The windows of a removed container go into the last container of the new layout.
- Workspace margin: 10 points. Container margin: 10 points. Carousel spacing: 30 points. These values are constants now.
- With SIP enabled, only the focused window of a carousel is raised. The carousel rules require only that window on top.

Not built: Left Busy, Right Busy, Horizontal Split, named custom layouts, and a command to copy a layout to another screen.

## 6. Leader key mode

- The default leader key is ⌃⌥ Space. The owner uses Hyper L (⌃⌥⇧⌘ L). The leader key is recorded in the settings.
- One layer is built. More layers can be added later.
- In leader key mode, each key press is stopped. The focused app doesn't receive it.
- An action key does its action and ends leader key mode. `Esc` or the leader key ends leader key mode. `?` opens the key list and keeps leader key mode active. A key without an action keeps leader key mode active.
- An action key without modifiers also matches while modifiers are still held, for example `1` while Hyper is still held.

| Section | Key | Action |
|---|---|---|
| Screen | `1` to `4` | Apply a layout |
| Container | `K`, `J` | Focus the previous or next container |
| Container | `V` | Switch the carousel mode |
| Window | `H`, `L` | Focus the previous or next window in the carousel |
| Window | `F` | Float a tiled window, or tile it again |
| App | `R` | Raise the floating windows of the focused app |
| | `?` | Open or close the key list |
| | `Esc` | End leader key mode |

Planned keys:

- `P` for peek.
- `Q` turns Tiller off. It is shown in the key bar, at the right end, next to `?` and `Esc`.
- `⇧J` and `⇧K` move the focused window to the next or previous container. The moved window becomes the focused window of its new carousel. Focus stays in the old container, on the next window of its carousel.

## 7. Windows

- `WindowTraits.kind` in `Sources/TillerCore/WindowTraits.swift` sets the kind of each window:
  - tiled: subrole `AXStandardWindow`, the size can be set, the parent is the app, not modal.
  - floating: other windows at window layer 0.
  - ignored: minimized, not on screen, above window layer 0, subrole `AXUnknown` or without a subrole.
- Dialogs and child windows float. They aren't resized.
- A new floating window doesn't cause a re-layout or a focus change.
- A focus on a window brings all windows of its app in front of other apps. The floating windows of that app stay behind the focused window. `R` raises them and gives the front one focus.
- `F` floats the focused tiled window. The window goes back to its frame before Tiller first tiled it. `F` again puts it back in the focused container.
- Planned: peek. `P` fills the workspace with the focused window and keeps the workspace margin. `P` again, or a focus change to another tiled window, returns it to its container. Peek isn't used in the Full Screen layout.
- Not built: windows that open after a layout is applied aren't put in a container.
- Planned: a minimized window, or a window of a hidden app, is removed from its carousel. Its container and ring position are recorded. When the window comes back, it goes back into the same container, at the same ring position, as the focused window of that container. If that container doesn't exist, the window goes into the focused container.
- A Finder window with native tabs is one window on the screen. The window server has one window for each tab, at the same frame. Only the window of the selected tab is on the screen. The Accessibility API returns only that window. A tab switch changes the window id of the visible window.
- Planned for v1: one tile for each native tab group. When the visible window id changes at the same frame, the new id replaces the old id in the carousel.

## 8. Screens

- Each screen has one workspace. The workspaces are stored with the display UUID as the key.
- Only one screen was tested. The multi-screen gaps are in [F27](work/F27-multiple-screens.md).

## 9. Leader key overlay

- The key bar is shown at once. The containers and window pills follow in 18 to 30 ms.
- Container: a teal tint and edge. The focused container is brighter.
- Container chip: a solid pill on the top edge of the container, over the border. Teal for the focused container, grey for the others. It shows the container number, ⇆ or ⇅, a window-stack icon with the window count, and the `V` key. A tooltip on the key shows what the key does.
- Window pill: small, translucent, at the bottom-right corner of every window, including floating windows. It shows the real app icon, the app name, Tiled or Floating, and the `F` key. A window behind the focused window in a carousel shows only its app icon, in its visible edge.
- A pill isn't shown when another window covers the place of the pill.
- Key bar: draggable, at the bottom center of the screen by default. The keys are in sections with a heading: SCREEN, CONTAINER, WINDOW and APP. `?` and `Esc` are at the right end.
- Key list: `?` opens it above the key bar. It lists each key with a description.
- "Show the key bar" is on by default. When it is off, the containers and pills are shown without the key bar.
- Key caps are flat: a rounded square with a solid fill and without a border. The key is in the system sans font. Letters are upper case. Modifiers are shown as symbols, for example "⌃⌥⇧⌘ L".
- The overlay doesn't take clicks. Clicks go to the windows below it.

## 10. Appearance and theme

- All UI follows the system light or dark appearance.
- `Theme` in `Sources/Tiller/Overlay/Theme.swift` defines the colors, materials and fonts. Each color has a light value and a dark value. Themes can be added later. A setting for light, dark or system comes later.

## 11. Settings window

- "Settings…" (⌘,) in the Tiller menu opens it.
- Layout: a sidebar with colored icons, as in the CleanShot settings (`docs/references/ui-cleanshot-settings-*.png`). Pages: Shortcuts and About.
- Shortcuts page: the leader key field, "Show the key bar", and one field for each action.
- Shortcut field, as in Rectangle Pro (`docs/references/ui-rectanglepro-shortcut-*.png`): the keys in a grey field with a clear button. A click starts recording. The field shows "Press keys…" with a teal edge. The next key press is saved. `Esc` cancels.
- Each chord can use Hyper. One chord has one action.
- Shortcuts are saved in the Tiller defaults.

Planned, with mockups in [settings-v2.html](mockups/settings-v2.html) and [general-page.html](mockups/general-page.html):
- A global shortcut for each action except the leader key. A segmented control at the top of the Shortcuts page shows the action keys ("Leader key mode") or the global shortcuts ("Global").
- General page: "Open at login", off by default, and "Enable Tiller".
- General page: "Show Tiller in", a segmented control with "Menu bar", "Dock" and "Both". The default is "Menu bar". With "Dock", a click on the Tiller icon in the Dock opens the settings.
- A menu bar menu to enable and disable Tiller, as variant A in [menu-bar-menu-v2.html](mockups/menu-bar-menu-v2.html): a "Tiller" row with the global shortcut in grey before a switch. When Tiller is off, the leader key and the global shortcuts pass to the focused app. Windows stay where they are.
- The default global shortcut to turn Tiller on and off is `⌃⌥⌘ T`. `Q` in leader key mode turns Tiller off. With Tiller off, only the global shortcut and the menu turn Tiller on.

## 12. Icons

- App icon: three windows with a T in the gaps between them, with one gradient. Light icon: violet to blue. Dark icon: amber to coral. The app contains only the dark icon now. The light icon needs an asset catalog compiled with `actool` from Xcode.
- Menu bar icon: a template image of three windows with a T in the gaps. macOS draws it in the menu bar text color.

## 13. Logging and diagnostics

- The current log is `~/Library/Logs/Tiller/tiller.log`. It contains launches, actions with latency, frame times for each app, overlay times and setting changes.
- The planned log is in [specs/logging.md](specs/logging.md): the Apple unified log and a JSON Lines file, a classification event for each new window, frame mismatch events, and "Export Diagnostics…" on the About page of the settings window and in the Tiller menu.
- Tiller logs only the leader key and the keys in leader key mode. Window titles aren't logged by default. Data doesn't leave the Mac.

## 14. Latency

| Action | Measured latency |
|---|---|
| Layout, test windows | 25 to 50 ms |
| Focus step, test windows | 19 to 35 ms |
| Layout, with WeChat windows | 77 to 141 ms |
| Key bar shown | 0.5 to 1.4 ms |
| Containers and pills shown | 18 to 30 ms |

- WeChat takes 23 to 80 ms to resize one window. A move without a resize takes 1 to 3 ms.
- Planned fixes: one size call per window in place of two, and a cached window list.

## 15. Proof and test tools

- `build/tiller-proof` runs the end-to-end test. See [F02](work/F02-proof-bundles.md).
- `Tiller --dump-windows <path>` writes the attributes and the kind of every window.
- `Tiller --focus-test <bundle id> <window id> <method> <path>` tests one focus method.
- The unit tests are in `Tests/TillerCoreTests/`.
