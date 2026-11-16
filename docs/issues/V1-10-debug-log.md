# V1-10: Debug log and Export Diagnostics

Work file: [F23](../work/F23-debug-log.md)

## What to build

The full spec is in [specs/logging.md](../specs/logging.md).

- Each event is written to the Apple unified log and to `~/Library/Logs/Tiller/tiller.jsonl`.
- The JSON Lines file rotates at 5 MB. Tiller keeps 3 files.
- The events of these categories are logged: lifecycle, keys, action, window, ax, overlay, settings and display.
- "Debug logging" on the General page turns on the `debug` level for 24 hours.
- "Include window titles in logs" on the General page is off by default.
- Make 3 mockups of the About page with an "Export Diagnostics…" button, in the light and the dark appearance, for approval.
- "Export Diagnostics…" on the About page and in the Tiller menu writes one zip to the Desktop. The zip is shown in Finder.
- The zip contains all the data needed to find the cause of a problem without the running app.

## Acceptance criteria

- [ ] Unit tests cover the event encoding, the file rotation at 5 MB and the window title setting.
- [ ] A script checks that each line of a run with each event type is valid JSON with the required fields.
- [ ] The diagnostics zip of a run with WeChat and the test windows shows the classification of each WeChat window and the `setFramesMs` of each app.
- [ ] The log adds less than 0.5 ms to an action.
- [ ] "Export Diagnostics…" on the About page writes the zip, in the light and the dark appearance.

## Proof

The unit test output, the script output for the JSON Lines check, the diagnostics zip of the WeChat run, and the measurement of the time added by the log.
