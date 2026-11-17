# F23: Debug log and diagnostics

## Request

> i also want you to spec and design your own debug log (whether it goes to the system log, console, or somewhere else like a file) - and any other telemetry, so that if I am using the app outside of this dev setup that a recording of the logs gives enough information to debug issues like unmapped applications or janky behaviour.

> also, as part of dogfooding - one of the things we need to do is be able to keep debug logs that I can export from the about (maybe on about page in the settings?) and send to you here when debugging/fixing.

Source: [requirements-as-written.md, sections 11 and 13](../requirements-as-written.md).

## What exists

The behaviour is described in [PRD.md, section 13 "Logging and diagnostics"](../PRD.md#13-logging-and-diagnostics).

- `EventLog` and `LogFile` in `Sources/TillerCore/EventLog.swift` write each event to the unified log, subsystem `com.tiller.Tiller`, and to `~/Library/Logs/Tiller/tiller.jsonl`. The file rotates at 5 MB. 3 files are kept. Events are encoded and written on one background queue. A log call takes 0.0017 ms on the calling queue.
- `LogEventName` lists the 22 events, with the category and the level of each. `tiller.log` isn't written.
- `debug` events (`ax.call`) are written only to the unified log.
- Window titles aren't logged. The window dump in the diagnostics zip doesn't contain titles.
- "Export Diagnostics…" in the menu bar menu and in the Tiller app menu writes `Tiller-Diagnostics-<date>.zip` to the Desktop and shows it in Finder. `Diagnostics.export` in `Sources/Tiller/Diagnostics.swift` writes it.
- `scripts/check-log.py` checks each line of a log file: valid JSON, the required keys, a known event, its category and the required fields of the event.
- The `export-diagnostics:<dir>` proof step writes the zip to a folder without Finder.
- Tiller quits through `applicationWillTerminate` on SIGTERM, so `app.terminate` and the queued events are written.
- Mockups of the About page: [about-page.html](../mockups/about-page.html), 3 variants in the light and the dark appearance. Each variant shows the "Export Diagnostics…" button and the place of the "Debug logging" and "Include window titles in logs" switches.

## Proof

[F23-debug-log](../../Tests/Proof/F23-debug-log): a proof run with WeChat and the test windows. All steps pass. `scripts/check-log.py` checked the 77 lines of the run: 0 failed. The diagnostics zip shows WeChat window 10014 as `tiled` and the `setFramesMs` of WeChat and of the test windows for each action. `mockups/about-page.png` is the render of the 3 About page variants.

## What to build

These items wait for the approval of one variant in [about-page.html](../mockups/about-page.html):

- The "Export Diagnostics…" button on the About page. It calls the same export as the menu item.
- The "Debug logging" switch. It writes `debug` events to the file and turns off after 24 hours.
- The "Include window titles in logs" switch. It adds titles to `window.classified`, `action.focus` and `windows.json`.

## Acceptance criteria

- [x] Unit tests for the log event encoding and the log file rotation at 5 MB.
- [ ] A unit test for the "Include window titles in logs" setting.
- [x] A script checks the log of a run. Each log line is valid JSON with the required fields.
- [x] A run is made with WeChat and the test windows. Its diagnostics zip shows the window kind of each WeChat window and the `setFramesMs` of each app.
- [x] Logging adds less than 0.5 ms to the latency of an action.
- [ ] "Export Diagnostics…" on the About page writes the diagnostics zip, in the light and the dark appearance.
- [ ] "Debug logging" writes `debug` events to the file and turns off after 24 hours.

## Proof needed

Screenshots of the About page in the light and the dark appearance, the diagnostics zip written by the button, and the unit test output of the window titles setting.
