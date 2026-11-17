# F23: Debug log and diagnostics

## Request

> i also want you to spec and design your own debug log (whether it goes to the system log, console, or somewhere else like a file) - and any other telemetry, so that if I am using the app outside of this dev setup that a recording of the logs gives enough information to debug issues like unmapped applications or janky behaviour.

> also, as part of dogfooding - one of the things we need to do is be able to keep debug logs that I can export from the about (maybe on about page in the settings?) and send to you here when debugging/fixing.

Source: [requirements-as-written.md, sections 11 and 13](../requirements-as-written.md).

## What exists

- The spec is in [PRD.md, section 13 "Logging and diagnostics"](../PRD.md#13-logging-and-diagnostics).
- The current log `~/Library/Logs/Tiller/tiller.log` is plain text. It isn't rotated. It contains launches, actions with latency, frame times for each app, overlay times and setting changes.

## What to build

The behaviour is described in [PRD.md, section 13 "Logging and diagnostics"](../PRD.md#13-logging-and-diagnostics).

- Make 3 mockups of the About page with the "Export Diagnostics…" button, in the light and the dark appearance, for approval.

## Acceptance criteria

- [ ] There are unit tests for the log event encoding, the log file rotation at 5 MB and the "Include window titles in logs" setting.
- [ ] A script checks the log of a run with each event type. Each log line is valid JSON with the required fields.
- [ ] A run is made with WeChat and the test windows. Its diagnostics zip shows the window kind of each WeChat window and the `setFramesMs` of each app.
- [ ] Logging adds less than 0.5 ms to the latency of an action.
- [ ] "Export Diagnostics…" on the About page writes the diagnostics zip, in the light and the dark appearance.

## Proof needed

The unit test output, the output of the script that checks the log lines, the diagnostics zip of the run with WeChat, and the measurement of the time added by logging.
