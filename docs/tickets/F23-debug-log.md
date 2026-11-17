# F23: Debug log and diagnostics

## Request

> i also want you to spec and design your own debug log (whether it goes to the system log, console, or somewhere else like a file) - and any other telemetry, so that if I am using the app outside of this dev setup that a recording of the logs gives enough information to debug issues like unmapped applications or janky behaviour.

> also, as part of dogfooding - one of the things we need to do is be able to keep debug logs that I can export from the about (maybe on about page in the settings?) and send to you here when debugging/fixing.

Source: [requirements-as-written.md, sections 11 and 13](../requirements-as-written.md).

## What exists

The behaviour is described in [PRD.md, section 13 "Logging and diagnostics"](../PRD.md#13-logging-and-diagnostics).

- `EventLog` and `LogFile` in `Sources/TillerCore/EventLog.swift` write each event to the unified log, subsystem `com.tiller.Tiller`, and to `~/Library/Logs/Tiller/tiller.jsonl`. The file rotates at 5 MB. 3 files are kept. Events are encoded and written on one background queue. A log call takes 0.002 ms on the calling queue.
- `LogEventName` lists the 23 events, with the category and the level of each.
- `debug` events (`ax.call`) are written to the file only while "Debug logging" is on.
- `EventLog` removes the `title` and `titles` fields of each event while "Include window titles in logs" is off. `window.classified` has the window title. `action.focus` has the titles of the windows in ring order.
- "Export Diagnostics…" in the menu bar menu, in the Tiller app menu and on the About page writes `Tiller-Diagnostics-<date>.zip` to the Desktop and shows it in Finder. `Diagnostics.export` in `Sources/Tiller/Diagnostics.swift` writes it. `windows.json` in the zip has the window titles only while "Include window titles in logs" is on.
- The About page, `AboutPage` in `Sources/Tiller/Settings/SettingsView.swift`, is variant 4 in [about-page.html](../mockups/about-page.html): the icon, the name and the version, the "Log" group, then the "Diagnostics" group.
  - "Log file" shows the log folder, the file count and the total size. The values are read each time the page is shown and after an export. "Show in Finder" shows `tiller.jsonl` in Finder.
  - "Debug logging" is saved as the time it turns off, `debugLoggingUntil`, in the Tiller defaults. A timer turns it off after 24 hours. A badge shows the hours left.
  - "Include window titles in logs" is saved as `logTitles` in the Tiller defaults.
  - "Export Diagnostics…" calls the same export as the menu item.
- `scripts/check-log.py` checks each line of a log file: valid JSON, the required keys, a known event, its category and the required fields of the event. A window title is allowed only while "Include window titles in logs" is on in the session. A `debug` line is allowed only while "Debug logging" is on in the session.
- Proof steps: `export-diagnostics:<dir>` writes the zip to a folder without Finder. `toggle:debugLogging`, `toggle:logTitles` and `expire:debugLogging` change the switches. `press:<title>` presses a button with the Accessibility press action. A `settings:<page>` step also captures the settings window alone.
- Tiller quits through `applicationWillTerminate` on SIGTERM, so `app.terminate` and the queued events are written.

## Proof

- [F23-debug-log](../../Tests/Proof/F23-debug-log): a proof run with WeChat and the test windows. All steps pass. `scripts/check-log.py` checked the 77 lines of the run: 0 failed. The diagnostics zip shows WeChat window 10014 as `tiled` and the `setFramesMs` of WeChat and of the test windows for each action.
- [F23-about-page](../../Tests/Proof/F23-about-page): a proof run in the dark appearance and one in the light appearance. All 14 steps of each run pass.
  - The settings window screenshots show the About page as in variant 4, with both switches off, then both on with the "24 h left" badge, then both off after the timer turned debug logging off.
  - The "Export Diagnostics…" button wrote a zip in each run. Each zip has the window titles in `windows.json` and 8 `ax.call` lines in `tiller.jsonl`.
  - `scripts/check-log.py` checked the 43 lines of each run: 0 failed. The 8 `ax.call` lines were written while "Debug logging" was on. The 3 window moves after the timer turned it off weren't written to the file.
  - The unit tests for "Debug logging" and "Include window titles in logs" pass: 52 tests passed.
