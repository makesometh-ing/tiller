# Tiller product requirements

This document is the spec for Tiller. Each section describes the current behaviour, then the behaviour planned for v1. The owner's requirements, word for word, are in [requirements-as-written.md](requirements-as-written.md). The decisions that are hard to change are in [adr/](adr/). Each feature, bug and research item is a ticket in [tickets/](tickets/). The status and the build order of each ticket are in [tickets/tickets.jsonl](tickets/tickets.jsonl).

## 1. Product

Tiller is a tiling window manager for macOS. It is a menu bar app with a minimal UI. Tiller is used through a leader key. One key chord starts leader key mode. The next key does an action.

## 2. Principles

- Latency and visible jank aren't acceptable. Each action is measured and logged.
- SIP stays enabled. Tiller uses the Accessibility API and permissions. Tiller doesn't move windows off-screen.
- Work is done in vertical slices. Each slice is real working software that can be tested.
- A task is done only with a proof bundle: logs, screenshots, screen recordings or test output. Proof bundles are stored in `Tests/Proof/<task>/`. Git ignores this folder.
- Before UI is built, at least 3 mockups are made for approval. Each mockup is shown in the light and the dark appearance. The look of the UI must match the quality of the Alcove settings window (`docs/references/ui-alcove-settings.png`).
- AeroSpace, yabai, Amethyst and Glide are used for ideas and for their fixes to known problems.

## 3. Glossary

The terms are defined in [GLOSSARY.md](../GLOSSARY.md). The glossary of the requirements drawing is copied word for word in [requirements-as-written.md, section 1](requirements-as-written.md), "Requirements drawing". One term in GLOSSARY.md is different from the drawing: a workspace is a singleton per screen.

## 4. Platform and build

- Swift 6, AppKit for the app and the panels, SwiftUI for the views. Objective-C isn't used. Swift calls the same C APIs as Objective-C, at the same cost. The latency is caused by the Accessibility calls to other apps.
- The Swift 6 compiler is from the Command Line Tools. It isn't installed through mise.
- Windows are moved and resized with the Accessibility API. Key presses are read with a `CGEventTap`. The private function `_AXUIElementGetWindow` returns the window id of an Accessibility element. It works with SIP enabled.
- Tiller requires the Accessibility permission. The terminal app that starts `build/tiller-proof` also requires the Screen Recording permission for `screencapture`.
- The build doesn't use Xcode. `scripts/build.sh` builds and signs the app with the Apple Development certificate. `scripts/test.sh` runs the unit tests.
- The minimum macOS version is 26.0.
- The source is published under the GPL 3.0 license. The license text is in `LICENSE`.

Planned for v1:

- A window opens at launch when Tiller doesn't have the Accessibility permission. It says why the permission is needed. It contains a button. The button opens System Settings → Privacy & Security → Accessibility.
- The permission window closes when the permission is granted. Leader key mode then works without a relaunch of Tiller.
- Settings, Permissions page: each permission used by Tiller, with its state, granted or not granted. A permission that isn't granted has a button. The button opens the System Settings page for that permission. A change in System Settings is shown on the page.

## 5. Layouts and carousels

- The four must-have layouts are built: Full Screen, Vertical Split, Left Two-Thirds and Right Two-Thirds. Keys: `1`, `2`, `3`, `4`.
- A layout is applied to the workspace of the screen with the focused window. The other screens don't change.
- Container order is left to right, then top to bottom.
- Each container is a horizontal carousel or a vertical carousel. The carousel rules are defined in the requirements drawing.
- `V` switches the focused container between horizontal and vertical.
- With SIP enabled, only the focused window of a carousel is raised. The carousel rules require only that window to be on top.
- Workspace margin: 10 points. Container margin: 10 points. Carousel spacing: 30 points.
- Built: when a layout key is pressed, the windows on the screen of the focused window are read. Only tiled windows are used. See section 7 "Windows". The focused window is put into container 1. The other windows are put into the containers in turn, from container 2. The carousel mode of each container is set to horizontal.

Planned for v1:

- When Tiller is enabled on a screen for the first time, the Full Screen layout is applied. All tiled windows on the screen are put into its one container.
- When a layout is applied, each window stays in the container with the same number. A new container is empty until a window is moved into it. The windows of a removed container are put into the last container of the new layout.
- When a layout is applied, the carousel mode of each container number is retained if that number exists in the new layout.
- The layout, the containers, the carousel modes and the windows of each workspace are saved, with the display UUID as the key.
- When Tiller is enabled on a screen again, or after a launch, the saved workspace of that screen is restored. Each window that still exists is put back into its saved container.
- The workspace margin, the container margin and the carousel spacing are settings. A change is applied at once to each workspace.

After v1: Left Busy, Right Busy, Horizontal Split, named custom layouts, and a command to copy a layout to another screen.

## 6. Leader key mode

- The default leader key is ⌃⌥ Space. The owner uses Hyper L (⌃⌥⇧⌘ L). The leader key can be recorded in the settings.
- Tiller's event tap is at the annotated session tap point. Key remappers such as Hyperkey add their modifier flags in a session event tap. These flags are included before Tiller receives the key event.
- One layer is built. More layers can be added after v1.
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
| Tiller | `Q` | Turn Tiller off |
| | `?` | Open or close the key list |
| | `Esc` | End leader key mode |

Planned for v1:

- `P`: peek. See section 7 "Windows".
- `⇧J` and `⇧K` move the focused window to the next or previous container. The moved window becomes the focused window of its new carousel. Focus stays in the old container, on the next window of its carousel.
- Leader key mode ends 10 seconds after the last key press. It doesn't end while the key list is open.
- Each action has an "Exit leader key mode" setting. When it is off, leader key mode continues after the action and the overlay is updated. Off by default for `H`, `L`, `J`, `K`, `⇧J` and `⇧K`. On by default for the other actions. `Q` always ends leader key mode.
- Leader key mode ends on an app switch, a mouse click and a screen lock.
- When the event tap doesn't start, the menu bar menu shows the failure. Tiller starts the event tap again every second until it starts.
- Key names are read from the current keyboard layout. They are read again when the keyboard layout changes. Chords are stored as key codes. A saved chord stays on the same key after a keyboard layout change.

## 7. Windows

- `WindowTraits.kind` in `Sources/TillerCore/WindowTraits.swift` sets the kind of each window:
  - tiled: subrole `AXStandardWindow`, the size can be set, the parent is the app, not modal.
  - floating: other windows at window layer 0.
  - ignored: minimized, not on screen, above window layer 0, subrole `AXUnknown` or without a subrole.
- Dialogs and child windows float. They aren't resized. AeroSpace, yabai, i3 and Glide do the same. The sources are in [research/child-windows.md](research/child-windows.md).
- A new floating window doesn't cause a re-layout or a focus change.
- When a window gets focus, all windows of its app are brought in front of the windows of other apps. The floating windows of that app stay behind the focused window. `R` raises them and gives the front one focus. With the Accessibility API, the focused window of an app is always the top window of that app. A floating window can be above the focused window only when the floating window has focus.
- To give a window focus, Tiller sets `AXMain` on the window, raises it with `AXRaise`, sets `AXFrontmost` on its app and calls `NSRunningApplication.activate()`. Some apps, for example Dia, return success for `AXFrontmost` and stay inactive. `activate()` makes them active. Without the all-windows option, only the main window of the app comes forward.
- `F` floats the focused tiled window. The window is returned to its frame from before Tiller first tiled it. `F` again puts it back in the focused container.
- A Finder window with native tabs is one window on the screen. The window server contains one window for each tab, at the same frame. Only the window of the selected tab is on the screen. The Accessibility API returns only that window. A tab switch changes the window id of the visible window.

Planned for v1:

- A new tiled window is put into the focused container, after the focused window. It becomes the focused window.
- A closed window is removed from its container at once. The other windows of the carousel are arranged again.
- A minimized window, or a window of a hidden app, is removed from its carousel. Its container and its position in the ring order are recorded. When the window is shown again, it is put back into the same container, at the same position in the ring order, as the focused window of that container. If that container doesn't exist, the window is put into the focused container.
- Each native tab group is one window in its carousel. When the visible window id changes at the same frame, the new id replaces the old id in the carousel. A new tab doesn't add a window to the carousel. A closed tab doesn't remove the window of the group from the carousel while another tab of the group is open.
- Peek: `P` fills the workspace with the focused window. The workspace margin is kept. `P` again, or a focus change to another tiled window, returns it to its container. `P` doesn't do anything in the Full Screen layout. `P` is shown on the window pill of a tiled window and in the key bar.

## 8. Screens

- Each screen has one workspace. The workspaces are stored with the display UUID as the key.
- macOS Spaces aren't used. See [ADR 0003](adr/0003-one-workspace-per-screen.md).
- Tiller was tested with one screen only.

Planned for v1:

- The workspace of a disconnected screen is removed. Its overlay panels are removed.
- The workspace frame is updated when the resolution, the Dock or the menu bar changes. The windows of that workspace are arranged again at once.
- A tiled window moved to another screen is removed from the workspace of its old screen. It is put into the focused container of the new screen.
- The key bar and the key list open on the screen of the focused window.

## 9. Leader key overlay

- Mockups: variant 3 in [leader-mode-v3.html](mockups/leader-mode-v3.html) for the containers and the pills, and variant 1 in [leader-mode-v4.html](mockups/leader-mode-v4.html) for the key bar.
- The key bar is shown at once. The containers and window pills are shown 18 to 30 ms later.
- Container: a teal edge without a fill. The edge of the focused container is brighter.
- Container chip: a solid pill on the top edge of the container, over the border. Teal for the focused container, grey for the others. It shows the container number, ⇆ or ⇅, a window-stack icon with the window count, and the `V` key. A tooltip on the key shows what the key does.
- Window pill: small, translucent, at the bottom-right corner of every window, including floating windows. It shows the real app icon, the app name, Tiled or Floating, and the `F` key. The pill of a window behind the focused window in a carousel shows only the app icon, in the visible edge of the window.
- A pill isn't shown when the area of the pill is behind another window.
- Key bar: draggable, at the bottom center of the screen by default. The keys are in sections with a heading: SCREEN, CONTAINER, WINDOW and APP. `?` and `Esc` are at the right end.
- Key list: `?` opens it above the key bar. It lists each key with a description.
- The setting "Show the key bar" is on by default. When it is off, the containers and pills are shown without the key bar.
- Key caps are flat: a rounded square with a solid fill and without a border. The key is in the system sans font. Letters are upper case. Modifiers are shown as symbols, for example "⌃⌥⇧⌘ L".
- The overlay doesn't receive clicks. Clicks are sent to the windows below it.

## 10. Appearance and theme

- All UI follows the system light or dark appearance.
- `Theme` in `Sources/Tiller/Overlay/Theme.swift` defines the colors, materials and fonts. Each color has a light value and a dark value.

After v1: a setting for light, dark or system, and themes.

## 11. Settings window and menu bar menu

- "Settings…" (⌘,) in the Tiller menu opens the settings window, in front of the other apps. Mockup: variant 1 in [settings.html](mockups/settings.html).
- Layout: a sidebar with colored icons, as in the CleanShot settings (`docs/references/ui-cleanshot-settings-*.png`). Pages: General, Shortcuts and About. A Permissions page is planned, see section 4 "Platform and build".
- Shortcuts page: the leader key field, "Show the key bar", and one field for each action.
- Shortcut field, as in Rectangle Pro (`docs/references/ui-rectanglepro-shortcut-*.png`): the keys in a grey field with a clear button. A click starts recording. The field shows "Press keys…" with a teal edge. The next key press is saved. `Esc` cancels the recording.
- Each chord can use Hyper. A chord can have only one action.
- Shortcuts are saved in the Tiller defaults.
- General page: "Show Tiller in", a segmented control with "Menu bar", "Dock" and "Both", as variant 2 in [general-page.html](mockups/general-page.html). The default is "Menu bar". A change is applied at once. The settings window stays in front. The value is saved in the Tiller defaults and applied at launch.
- With "Dock" or "Both", a click on the Tiller icon in the Dock opens the settings. The Dock menu of Tiller contains "Enable Tiller" and "Settings…". With "Dock", the Tiller menu in the app menu bar contains "Settings…" (⌘,) and "Quit Tiller".
- Saved shortcuts get the standard key of an action that was added after the save, if another action doesn't use that key. A cleared key stays cleared.
- General page: "Enable Tiller". It is the same setting as the switch in the menu bar menu. It is saved in the Tiller defaults and applied at launch. On by default.
- Menu bar menu, as variant A in [menu-bar-menu-v2.html](mockups/menu-bar-menu-v2.html): a "Tiller" row with the global shortcut in grey before a switch.
- When Tiller is off, the leader key and the global shortcuts are sent to the focused app. Windows stay where they are. When Tiller is on again, the windows are arranged again in their containers.
- The global shortcut to turn Tiller on and off is `⌃⌥⌘ T`. It doesn't require a Hyper key. `⇧⌘T` isn't used. Safari, Chrome, Firefox, VS Code and Finder use it. `⌃⌥T` isn't used. Rectangle uses it. `⌥⌘T` isn't used. Finder uses it. With Tiller off, only the global shortcut, the menu bar menu, the General page and the Dock menu turn Tiller on. The global shortcut can't be recorded yet.

Planned for v1, with mockups in [settings-v2.html](mockups/settings-v2.html), [general-page.html](mockups/general-page.html) and [menu-bar-menu-v2.html](mockups/menu-bar-menu-v2.html):

- Global shortcuts: each action except the leader key has a global shortcut. A global shortcut does its action without the leader key. The focused app doesn't receive it. Global shortcuts are empty by default, except the shortcut to turn Tiller on and off.
- A global shortcut can't be the same chord as the leader key or as another global shortcut.
- Shortcuts page: a segmented control at the top of the page shows the action keys ("Leader key mode") or the global shortcuts ("Global").
- Shortcuts page: an "Exit leader key mode" checkbox column next to the "Leader key mode" fields. See section 6 "Leader key mode".
- General page: "Open at login", off by default. The switch shows the state from macOS. A change in System Settings is shown in the switch.
- General page: the workspace margin, the container margin and the carousel spacing. See section 5 "Layouts and carousels".
- The global shortcut to turn Tiller on and off can be recorded. Its default is `⌃⌥⌘ T`.

## 12. Icons

- App icon: three windows with a T in the gaps between them, with one gradient. The app contains only the dark icon, amber to coral.
- Menu bar icon: a template image of three windows with a T in the gaps. macOS draws it in the menu bar text color.

Planned for v1:

- The app shows the light icon, violet to blue, in the light appearance, and the dark icon in the dark appearance.
- The menu bar icon has the same shape as the gradient icons.

## 13. Logging and diagnostics

- The current log is `~/Library/Logs/Tiller/tiller.log`. It contains launches, actions with latency, frame times for each app, overlay times and setting changes.
- Each focus action writes a `focus` line 150 ms after the action, from another queue: the ring order (bundle id and window id), the focused window stored in the workspace, the system focused window before the action, the ring index before and after, the window that got focus, the AXError values of `AXMain`, `AXRaise` and `AXFrontmost`, the result of `activate()`, and the system focused window and frontmost app after the action.

Planned for v1: the logging described below replaces `tiller.log`.

### Goal

A user sends one diagnostics file. The file contains enough information to find the cause of these problems:

- An app window is tiled when it must float, or floats when it must be tiled.
- A window doesn't move, moves to the wrong frame, or moves back after Tiller moves it.
- An action is slow or causes visible jank.
- A key press doesn't start leader key mode, or is sent to the wrong app.
- Tiller hangs, or stops reading key presses.

All data stays on the Mac. Tiller doesn't send data over the network. The user sends the diagnostics file by hand.

### Destinations

Each log event is written to two places.

| Destination | Why | How to read it |
|---|---|---|
| Apple unified log, subsystem `com.tiller.Tiller` | A write takes less time than a file write. Console.app and `log` read it. | `log stream --level debug --predicate 'subsystem == "com.tiller.Tiller"'` |
| JSON Lines file `~/Library/Logs/Tiller/tiller.jsonl` | The user can attach this one file. Each line is one event with typed fields. A script can read it. | Any text editor, or `jq` |

The JSON Lines file rotates at 5 MB. Tiller keeps 3 files: `tiller.jsonl`, `tiller.1.jsonl` and `tiller.2.jsonl`.

Events are written on one background queue. A log call takes less than 0.05 ms on the calling queue. The event tap callback and the window move code aren't blocked by file writes.

### Levels

| Level | Written by default | Use |
|---|---|---|
| `error` | Yes | An Accessibility call failed, the event tap was disabled, a frame didn't match the target frame after a move. |
| `info` | Yes | Launch, settings changes, each action with its timings, each new app and window classification. |
| `debug` | No | Each Accessibility call with its time and result, each overlay update, each window list read. |

Settings → General → "Debug logging" turns `debug` on. It is turned off after 24 hours. This prevents debug logging from staying on by mistake.

### Event format

Each line of the JSON Lines file is one object:

```json
{"ts":"2026-11-16T17:29:03.412Z","level":"info","cat":"action","event":"action.done","session":"6F2A…","fields":{…}}
```

- `ts`: the time in UTC, with milliseconds.
- `cat`: one of `lifecycle`, `keys`, `action`, `window`, `ax`, `overlay`, `settings`, `display`.
- `session`: a random id for each launch. It is used to separate the events of two launches in one file.

### Events

#### lifecycle

- `app.launch`: Tiller version and build, macOS version, Mac model, Accessibility permission, the screens (display UUID, frame, desktop frame, scale), and all settings: leader key, each action key, spacing values, enabled state.
- `app.enabled` and `app.disabled`: the source (menu, global shortcut, settings).
- `tap.disabled`: the reason (`timeout` or `userInput`) and the time since the last key press. A timeout means a callback took too long.
- `app.terminate`.

#### keys

Tiller logs only the leader key and the keys in leader key mode. Text typed by the user isn't in the log.

- `leader.start` and `leader.end`: the chord and the reason for the end (action, `Esc`, leader key again).
- `leader.key`: the chord and the action id, or `unbound` when the chord doesn't have an action.
- `global.key`: the chord and the action id of a global shortcut.

#### action

- `action.done`: the action id, the screen UUID, the layout, the number of windows moved, and the timings in milliseconds:
  - `windowListMs`: the read of all windows.
  - `focusReadMs`: the read of the focused window.
  - `setFramesMs` for each app: bundle id, number of windows, time.
  - `focusMs`: the focus call.
  - `totalMs`: from the key press in the event tap to the end of the action.
- `action.slow` (`error`): the same fields as `action.done`. It is logged when `totalMs` is more than 100 ms.

#### window

- `window.classified`: logged one time for each window id. Bundle id, app name, window id, role, subrole, size settable, window layer, modal, parent role, buttons, and the result (tiled, floating or ignored). This event shows why an app window is tiled or floats.
- `window.frameMismatch` (`error`): logged when the frame read back after a move differs from the target frame by more than 1 point. Bundle id, window id, target frame and actual frame. It shows apps with a minimum size, or apps that move their windows back.
- `window.closed` and `window.opened`.

#### ax

- `ax.error` (`error`): the Accessibility function, the attribute, the `AXError` code, the bundle id and the time. For example `kAXErrorCannotComplete` from a hung app.
- `ax.call` (`debug`): each Accessibility call with its time.

#### overlay

- `overlay.shown`: the time to the key bar, the time to the containers and pills, the number of pills, and the number of pills hidden because they are behind another window.

#### settings

- `settings.changed`: the setting and the new value. Chords are logged as text, for example `ctrl+opt+shift+cmd+l`.

#### display

- `display.changed`: the new screen list. Tiller logs it when a screen is added, removed or changed.

### Window titles

Window titles can contain private text, for example a document name or a chat name. Titles aren't logged by default. Each window is logged with its window id and bundle id.

Settings → General → "Include window titles in logs" adds the titles.

### Export diagnostics

The About page of the settings window has an "Export Diagnostics…" button. The Tiller menu has an "Export Diagnostics…" item. Both write `Tiller-Diagnostics-<date>.zip` to the Desktop. The zip is then shown in Finder. The zip contains:

- The state at the time of the export: Tiller version and build, macOS version, Mac model, Accessibility permission, and the screens (display UUID, frame, desktop frame, scale).
- The JSON Lines files.
- The unified log entries of the last 2 hours: `log show --last 2h --predicate 'subsystem == "com.tiller.Tiller"'`.
- A window dump: the attributes and the window rule result of every window. This is the same data as `Tiller --dump-windows`.
- The settings.
- The workspace state of each screen: layout, containers, windows in each container, carousel mode, floating windows.

Window titles are added only when "Include window titles in logs" is on.

## 14. Latency

| Action | Measured latency |
|---|---|
| Layout, test windows | 25 to 50 ms |
| Focus step, test windows | 19 to 35 ms |
| Layout, with WeChat windows | 77 to 141 ms |
| Key bar shown | 0.5 to 1.4 ms |
| Containers and pills shown | 18 to 30 ms |

- WeChat takes 23 to 80 ms to resize one window. A move without a resize takes 1 to 3 ms.

Planned for v1:

- Only one size call is made for each window when the frame read back after the move is correct.
- A cached window list is updated from the Accessibility notifications. A container focus step doesn't read all windows.

## 15. Proof and test tools

- `build/tiller-proof` runs the end-to-end test. In proof mode, Tiller manages only the windows of the apps in `--only-bundle-ids`. Proof runs use the defaults domain `com.tiller.Tiller.proof`. A proof run doesn't change the saved shortcuts in the Tiller defaults.
- `Tiller --dump-windows <path>` writes the attributes and the kind of every window.
- `Tiller --focus-test <bundle id> <window id> <method> <path>` tests one focus method.
- The unit tests are in `Tests/TillerCoreTests/`.
