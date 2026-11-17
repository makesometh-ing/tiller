#!/usr/bin/env python
"""Checks Tiller JSON Lines log files. Each line must be one JSON object with the required fields.

Usage: scripts/check-log.py <tiller.jsonl> [more files]
Prints the number of lines of each event, and each line that fails a check. Exits with 1 when a line fails.
A window title is allowed only while "Include window titles in logs" is on in the session of the line.
A `debug` line is allowed only while "Debug logging" is on in the session of the line.
"""
import json
import re
import sys

CATEGORIES = {"lifecycle", "keys", "action", "window", "ax", "overlay", "settings", "display"}
LEVELS = {"error", "info", "debug"}
TS = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$")
# Event: (category, fields that each line of the event must contain).
EVENTS = {
    "app.launch": ("lifecycle", {"version", "build", "macOS", "model", "accessibility", "screens", "settings"}),
    "app.enabled": ("lifecycle", {"source"}),
    "app.disabled": ("lifecycle", {"source"}),
    "app.terminate": ("lifecycle", set()),
    "tap.started": ("lifecycle", {"keyTap", "mouseTap"}),
    "tap.disabled": ("lifecycle", {"tap", "reason"}),
    "leader.start": ("keys", {"reason", "chord"}),
    "leader.end": ("keys", {"reason"}),
    "leader.key": ("keys", {"chord", "action"}),
    "global.key": ("keys", {"chord", "action"}),
    "action.done": ("action", {"action", "moved", "totalMs"}),
    "action.slow": ("action", {"action", "moved", "totalMs"}),
    "action.focus": ("action", {"action", "order", "systemFocusedBefore", "systemFocusedAfter"}),
    "window.classified": ("window", {"bundleId", "windowId", "subrole", "sizeSettable", "layer", "modal", "kind"}),
    "window.frameMismatch": ("window", {"bundleId", "windowId", "target", "actual"}),
    "window.opened": ("window", {"windowId", "bundleId", "screen", "container", "ringIndex"}),
    "window.closed": ("window", {"windowId"}),
    "window.removed": ("window", {"windowId", "bundleId", "screen", "container", "ringIndex", "reason"}),
    "window.restored": ("window", {"windowId", "bundleId", "screen", "container", "ringIndex", "sameContainer"}),
    "ax.error": ("ax", {"function", "code"}),
    "ax.call": ("ax", {"function", "ms"}),
    "overlay.shown": ("overlay", {"containersMs", "pills", "hiddenPills"}),
    "overlay.hidden": ("overlay", {"hideMs"}),
    "settings.changed": ("settings", {"setting", "value"}),
    "diagnostics.exported": ("settings", {"path", "ms"}),
    "display.changed": ("display", {"screens"}),
}
# The required fields of each action.done line, by action.
ACTION_TIMINGS = {"windowListMs", "focusReadMs", "setFramesMs", "focusMs", "totalMs"}


# The settings of each session: {"logTitles": bool, "debugLogging": bool}. Set by app.launch and settings.changed.
SESSIONS = {}


def problems(line):
    try:
        e = json.loads(line)
    except json.JSONDecodeError as error:
        return [f"not JSON: {error}"]
    found = []
    if not isinstance(e, dict) or set(e) != {"ts", "level", "cat", "event", "session", "fields"}:
        return [f"keys are {sorted(e) if isinstance(e, dict) else type(e)}"]
    if not TS.match(e["ts"]):
        found.append(f"ts {e['ts']!r} isn't UTC with milliseconds")
    if e["level"] not in LEVELS:
        found.append(f"level {e['level']!r}")
    if e["cat"] not in CATEGORIES:
        found.append(f"cat {e['cat']!r}")
    if not e["session"]:
        found.append("session is empty")
    spec = EVENTS.get(e["event"])
    if spec is None:
        return found + [f"event {e['event']!r} isn't a Tiller event"]
    category, required = spec
    if e["cat"] != category:
        found.append(f"cat {e['cat']!r}, expected {category!r}")
    missing = required - set(e["fields"])
    if e["event"] == "action.done" and e["fields"].get("action", "").split(":")[0] in {"layout", "focus-next-window", "focus-previous-window",
                                                                                       "focus-next-container", "focus-previous-container", "toggle-axis", "toggle-float"}:
        missing |= ACTION_TIMINGS - set(e["fields"])
    if missing:
        found.append(f"fields missing: {sorted(missing)}")
    state = SESSIONS.setdefault(e["session"], {"logTitles": False, "debugLogging": False})
    if e["event"] == "app.launch":
        settings = e["fields"].get("settings", {})
        state.update(logTitles=settings.get("logTitles", False), debugLogging=settings.get("debugLogging", False))
    if e["event"] == "settings.changed" and e["fields"].get("setting") in state:
        state[e["fields"]["setting"]] = e["fields"]["value"]
    if "title" in json.dumps(e["fields"]) and not state["logTitles"]:
        found.append("contains a window title, and \"Include window titles in logs\" is off")
    if e["level"] == "debug" and not state["debugLogging"]:
        found.append("is a debug event, and \"Debug logging\" is off")
    return found


def main(paths):
    counts = {}
    failed = 0
    total = 0
    titled = 0
    for path in paths:
        with open(path, encoding="utf-8") as f:
            for number, line in enumerate(f, 1):
                total += 1
                found = problems(line)
                try:
                    name = json.loads(line).get("event", "?")
                except Exception:
                    name = "?"
                counts[name] = counts.get(name, 0) + 1
                titled += '"title' in line
                if found:
                    failed += 1
                    print(f"FAIL {path}:{number}: {'; '.join(found)}")
    for name in sorted(EVENTS):
        print(f"{name}\t{counts.get(name, 0)}")
    print(f"Lines with window titles\t{titled}")
    print(f"{total} lines, {failed} failed: {'PASS' if failed == 0 else 'FAIL'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
