# V1-11: Key names from the current keyboard layout

Work file: [F31](../work/F31-keyboard-layouts.md)

## Problem

Key names are read from a list of the US layout. On another layout, the key bar and the settings show the wrong letter, or `keyNN`.

## What to build

- Read each key name from the current keyboard layout.
- Read the names again when the keyboard layout changes.
- Chords are stored as key codes. A saved chord stays on the same key after a layout change.

## Acceptance criteria

- [ ] With the German layout, the key bar and the settings show the German key names.
- [ ] With the French layout, the key bar and the settings show the French key name for each of the four number keys.

## Proof

Screenshots of the key bar and the Shortcuts page with the US, German and French layouts.
