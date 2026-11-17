# F31: Keyboard layouts other than US

## Request

This problem was found in the audit of the project. There isn't a separate request.

## Problem

Key names are read from `KeyNames.codes` in `KeyChord.swift`. `KeyNames.codes` is a list of the key names of the US layout. On another layout, the key bar and the settings show the wrong letter, or `keyNN`.

## What to build

The behaviour is described in [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode).

## Acceptance criteria

- [ ] With the German layout, the key bar and the settings show the German key names.
- [ ] With the French layout, the key bar and the settings show the French key name for each of the number keys `1`, `2`, `3` and `4`.

## Proof needed

Screenshots of the key bar and the Shortcuts page with the US, German and French layouts.
