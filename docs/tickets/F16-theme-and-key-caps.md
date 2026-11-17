# F16: Theme, light and dark appearance, flat key caps

## Request

> we also need to make sure that this works in light and dark and should respect the system settings. ... In fact, we should open this up to theming so you could actually theme it however you want it to be, but let's just keep that in mind so you can modularize it and ready for theming, but doesn't need theming yet, not in the slice one.

> I don't like the monospace font we're using for the "keys". it looks a bit too vibe coded. I want to use something like this: flat design and nice sans fornt

Source: [requirements-as-written.md, section 9](../requirements-as-written.md).

## What exists

- `Theme` in `Sources/Tiller/Overlay/Theme.swift` defines all colors, materials and fonts of the overlay and the key caps.
- Each color has a light value and a dark value. The UI follows the system appearance.
- Key caps are flat: a rounded square with a solid fill, without a border. The key is in the system sans font, medium weight, 10.5 pt. Letters are upper case.

## Proof

[flat-keys-dark](../../Tests/Proof/flat-keys-dark), [flat-keys-light](../../Tests/Proof/flat-keys-light). Each overlay proof ran in both appearances.

## Known gaps

- The settings window uses system colors. It doesn't read `Theme` yet.
