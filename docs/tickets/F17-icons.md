# F17: App icon and menu bar icon

## Request

> oh, you should also use a codex subagent to design the app icon and menu bar app icon sillouhette (since claude doesn't have an image generator) - I would like it to look like a bunch of windows being organized but with a distinct T visible as the gaps between the windows or containers.

> Additionally, having reviewed this one, I would actually prefer there not to be like 3 different colours in the icon. I think it should just be one gradient top to bottom.

> these two

Source: [requirements-as-written.md, section 7](../requirements-as-written.md).

## What exists

- The selected light icon is the violet-to-blue gradient (`docs/mockups/icons/gradient-b`). The selected dark icon is the amber-to-coral gradient (`docs/mockups/icons/gradient-c`). Both are stored in `Resources/`.
- The image generator added a grey mark to both icons. `scripts/clean-icon.swift` removed it.
- `build/Tiller.app` contains the dark icon in `AppIcon.icns`.
- The menu bar icon is a template image of three windows with a T in the gaps. macOS draws it in the menu bar text color.
- The icons were made by a Codex subagent with image generation.

## Proof

[icons-final](../../Tests/Proof/icons-final), [icons](../../Tests/Proof/icons).

## What to build

The behaviour is described in [PRD.md, section 12 "Icons"](../PRD.md#12-icons).

- Compile an asset catalog with the light and the dark icon with `actool`.

## Acceptance criteria

- [ ] The Dock, Finder and the settings window show the light icon in the light appearance and the dark icon in the dark appearance.
- [ ] The menu bar icon is clear in a light and a dark menu bar.

## Proof needed

Screenshots of the Dock, Finder, the About page and the menu bar, in the light and the dark appearance.
