# F23: Debug log and diagnostics

Status: **Not done**

## Request

> i also want you to spec and design your own debug log (whether it goes to the system log, console, or somewhere else like a file) - and any other telemetry, so that if I am using the app outside of this dev setup that a recording of the logs gives enough information to debug issues like unmapped applications or janky behaviour.

> also, as part of dogfooding - one of the things we need to do is be able to keep debug logs that I can export from the about (maybe on about page in the settings?) and send to you here when debugging/fixing.

Source: [requirements-as-written.md, sections 11 and 13](../requirements-as-written.md).

## What exists

- The spec is in [docs/specs/logging.md](../specs/logging.md).
- The current log `~/Library/Logs/Tiller/tiller.log` is plain text. It isn't rotated. It contains launches, actions with latency, frame times for each app, overlay times and setting changes.

## Decisions

- The spec writes each event to the Apple unified log and to a JSON Lines file that rotates at 5 MB.
- Tiller logs only the leader key and the keys in leader key mode.
- Window titles aren't logged by default.
- "Export Diagnostics…" is on the About page of the settings window and in the Tiller menu. It writes one zip to the Desktop. Data doesn't leave the Mac.

## Open items

- Build the spec.
