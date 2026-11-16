# F19: Hyper key chords

Status: **Done**

## Request

> you must support "Hyper" key combinations in the redefined keys - and proof test them. I will be using hyper (shift, command, option, control + l) for the leader key

> "Hype" shouldn't be the shortcut text, it should show all the keys that are assigned

Source: [requirements-as-written.md, sections 10 and 11](../requirements-as-written.md).

## What exists

- `KeyChord` in `Sources/TillerCore/KeyChord.swift` is a key code with modifiers. Hyper is ⌃⌥⇧⌘ together.
- The leader key matches only with the exact modifiers.
- An action key matches with the same modifiers first. A key without modifiers also matches while modifiers are still held, for example `1` while Hyper is still held after Hyper L.
- A chord is shown with all its modifier symbols, for example "⌃⌥⇧⌘ L".
- `--leader hyper+l` and `--keys focusNextWindow=hyper+n` set the shortcuts for one launch.

## Proof

[hyper-dark](../../Tests/Proof/hyper-dark), [hyper-light](../../Tests/Proof/hyper-light), [covered-pills](../../Tests/Proof/covered-pills) (step 7). Unit tests in `KeyChordTests.swift`.

## Open items

- Your saved leader key is still ⌃⌥ Space. Record Hyper L in the settings to use it.
