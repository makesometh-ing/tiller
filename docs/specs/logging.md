# Tiller debug log and diagnostics

## Goal

A user sends one diagnostics file. The file gives enough information to find the cause of these problems:

- An app window is tiled when it must float, or floats when it must be tiled.
- A window doesn't move, moves to the wrong frame, or moves back after Tiller moves it.
- An action is slow or causes visible jank.
- A key press doesn't start leader key mode, or reaches the wrong app.
- Tiller hangs, or stops reading key presses.

All data stays on the Mac. Tiller doesn't send data over the network. The user sends the diagnostics file by hand.

## Destinations

Each log event is written to two places.

| Destination | Why | How to read it |
|---|---|---|
| Apple unified log, subsystem `com.tiller.Tiller` | Fast. It contains the events before and after a problem, also when the Tiller file is off. Console.app and `log` read it. | `log stream --level debug --predicate 'subsystem == "com.tiller.Tiller"'` |
| JSON Lines file `~/Library/Logs/Tiller/tiller.jsonl` | One file that the user can attach. Each line is one event with typed fields. A script can read it. | Any text editor, or `jq` |

The JSON Lines file rotates at 5 MB. Tiller keeps 3 files: `tiller.jsonl`, `tiller.1.jsonl` and `tiller.2.jsonl`. The current plain text log `tiller.log` is replaced by this file.

Events are written on one background queue. An event costs less than 0.05 ms on the queue that writes it. The event tap callback and the window move code don't wait for the file.

## Levels

| Level | Written by default | Use |
|---|---|---|
| `error` | Yes | An Accessibility call failed, the event tap was disabled, a frame didn't match after a move. |
| `info` | Yes | Launch, settings changes, each action with its timings, each new app and window classification. |
| `debug` | No | Each Accessibility call with its time and result, each overlay update, each window list read. |

Settings → General → "Debug logging" turns `debug` on. It turns off after 24 hours. This prevents it from staying on by mistake.

## Event format

Each line of the JSON Lines file is one object:

```json
{"ts":"2026-11-16T17:29:03.412Z","level":"info","cat":"action","event":"action.done","session":"6F2A…","fields":{…}}
```

- `ts`: the time in UTC, with milliseconds.
- `cat`: one of `lifecycle`, `keys`, `action`, `window`, `ax`, `overlay`, `settings`, `display`.
- `session`: a random id for each launch. It separates the events of two launches in one file.

## Events

### lifecycle

- `app.launch`: Tiller version and build, macOS version, Mac model, Accessibility permission, the screens (display UUID, frame, desktop frame, scale), and all settings: leader key, each action key, spacing values, enabled state.
- `app.enabled` and `app.disabled`: the source (menu, global shortcut, settings).
- `tap.disabled`: the reason (`timeout` or `userInput`) and the time since the last key press. A timeout means a callback took too long.
- `app.terminate`.

### keys

Tiller logs only the leader key and the keys in leader key mode. Other key presses aren't logged. Text typed by the user isn't in the log.

- `leader.start` and `leader.end`: the chord and the reason for the end (action, `Esc`, leader key again).
- `leader.key`: the chord and the action id, or `unbound` when the chord doesn't have an action.
- `global.key`: the chord and the action id of a global shortcut.

### action

- `action.done`: the action id, the screen UUID, the layout, the number of windows moved, and the timings in milliseconds:
  - `windowListMs`: the read of all windows.
  - `focusReadMs`: the read of the focused window.
  - `setFramesMs` for each app: bundle id, number of windows, time.
  - `focusMs`: the focus call.
  - `totalMs`: from the key press in the event tap to the end.
- `action.slow` (`error`): the same fields, when `totalMs` is more than 100 ms.

### window

- `window.classified`: logged one time for each window id. Bundle id, app name, window id, role, subrole, size settable, window layer, modal, parent role, buttons, and the result (tiled, floating or ignored). This event shows why an app window is tiled or floats.
- `window.frameMismatch` (`error`): logged when the frame read back after a move differs from the target frame by more than 1 point. Bundle id, window id, target frame and actual frame. It shows apps with a minimum size, or apps that move their windows back.
- `window.closed` and `window.opened`.

### ax

- `ax.error` (`error`): the Accessibility function, the attribute, the `AXError` code, the bundle id and the time. For example `kAXErrorCannotComplete` from a hung app.
- `ax.call` (`debug`): each Accessibility call with its time.

### overlay

- `overlay.shown`: the time to the key bar, the time to the containers and pills, the number of pills, and the number of pills hidden because another window covers them.

### settings

- `settings.changed`: the setting and the new value. Chords are logged as text, for example `ctrl+opt+shift+cmd+l`.

### display

- `display.changed`: the new screen list. Tiller logs it when a screen is added, removed or changed.

## Window titles

Window titles can contain private text, for example a document name or a chat name. Titles aren't logged by default. Each window is logged with its window id and bundle id.

Settings → General → "Include window titles in logs" adds the titles. It is off by default.

## Export diagnostics

The About page of the settings window has an "Export Diagnostics…" button. The Tiller menu has an "Export Diagnostics…" item. Both write `Tiller-Diagnostics-<date>.zip` to the Desktop and show the zip in Finder. The zip contains:

- The state at the time of the export: Tiller version and build, macOS version, Mac model, Accessibility permission, and the screens (display UUID, frame, desktop frame, scale).

- The JSON Lines files.
- The unified log entries of the last 2 hours: `log show --last 2h --predicate 'subsystem == "com.tiller.Tiller"'`.
- A window dump: the attributes and the window rule result of every window. This is the same data as `Tiller --dump-windows`.
- The settings.
- The workspace state of each screen: layout, containers, windows in each container, carousel mode, floating windows.

Window titles are added only when "Include window titles in logs" is on.

## Proof for this work

- Unit tests: the event encoding, the file rotation at 5 MB, and the title setting.
- An end-to-end run that writes each event type. A script checks that each line is valid JSON with the required fields.
- An end-to-end run with WeChat and the test windows. The diagnostics zip of that run must show the classification of each WeChat window and the `setFramesMs` of each app.
- A measurement of the time added to an action by the log. The limit is 0.5 ms.
