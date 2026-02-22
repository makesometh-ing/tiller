---
name: debug
description: Read and analyze Tiller debug logs from the last run. Use after the user runs the app from Xcode to diagnose window classification, tiling, animation, and AX probe issues.
---

# Debug — Tiller Runtime Log Analysis

## Log Location

Tiller writes debug logs to a file on each run. The log is replaced (not appended) every launch.

**Default path:** `~/.tiller/logs/tiller-debug.log`

**Custom path:** Set `logLocation` in `~/.config/tiller/config.json`:
```json
{
  "logLocation": "/some/other/path/tiller-debug.log"
}
```

## Reading Logs

Read the current config to find the log path, then read the log:

!`cat ~/.config/tiller/config.json 2>/dev/null | python3 -c "import sys,json; c=json.load(sys.stdin); print(c.get('logLocation', '~/.tiller/logs/tiller-debug.log'))" 2>/dev/null || echo "~/.tiller/logs/tiller-debug.log"`

Then read the log file at that path using the Read tool.

## Log Format

```
=== Tiller debug log started at 2026-02-22T21:30:00Z ===
=== Log path: /Users/.../.tiller/logs/tiller-debug.log ===
[HH:mm:ss.SSS] [category] message
```

### Categories

| Category | What it logs |
|---|---|
| `window-discovery` | Window enumeration, open/close/focus events, AX probe results, classification decisions |
| `orchestration` | Tiling decisions, debouncing, z-order, ring buffer state |
| `layout` | Accordion calculations, centering decisions, frame computations |
| `animation` | Positioning, size-set results, raise failures, AX trust checks |
| `monitor` | Monitor detection, configuration changes, active monitor switches |
| `config` | Config loading, validation, accessibility permission state |

## What to Look For

### Window Classification Issues
Search for lines containing `isResizable=` and `isFloating=` to see how each window was classified:
```
[window-discovery] Window 1234 (com.app.Bundle) -> isResizable=true, isFloating=false
```

### AX Probe Failures
Search for `AXResizable query failed` to see which windows have broken attribute probes:
```
[window-discovery] Window 1234 (com.app.Bundle): AXResizable query failed (error -25211)
```

### Centering vs Tiling
Search for `Centering non-resizable` to see which windows are being centered:
```
[layout] Centering non-resizable window 1234 (AppName) at (x, y, w, h)
```

### Animation Issues
Search for `duration=0` or `Instant positioning` to check if animations are being skipped:
```
[animation] Instant positioning (duration=0)
```

### Size-Set Failures (Non-Resizable Detection)
Search for `Size-set failed` to see windows that reject resize:
```
[animation] Size-set failed for window 1234 (error -25200), position was set — tolerating
```

## Common AX Error Codes

| Code | Meaning |
|---|---|
| -25200 | `kAXErrorFailure` — general failure (e.g. window rejects resize) |
| -25201 | `kAXErrorIllegalArgument` |
| -25202 | `kAXErrorInvalidUIElement` — element no longer exists |
| -25204 | `kAXErrorAttributeUnsupported` — app doesn't expose this attribute |
| -25205 | `kAXErrorCannotComplete` — AX call couldn't finish (transient) |
| -25211 | `kAXErrorNoValue` — attribute exists but has no value |

## OSLog (Production Errors)

Production `.error()` level messages still go through OSLog and are visible via:
```bash
log show --predicate 'subsystem == "ing.makesometh.Tiller"' --info --debug --last 1h
```

Note: `--level` is NOT a valid flag. Use `--info --debug` flags instead.
