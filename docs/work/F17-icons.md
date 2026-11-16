# F17: App icon and menu bar icon

Status: **Not done**

## Request

> oh, you should also use a codex subagent to design the app icon and menu bar app icon sillouhette (since claude doesn't have an image generator) - I would like it to look like a bunch of windows being organized but with a distinct T visible as the gaps between the windows or containers.

> Additionally, having reviewed this one, I would actually prefer there not to be like 3 different colours in the icon. I think it should just be one gradient top to bottom.

> these two

Source: [requirements-as-written.md, section 7](../requirements-as-written.md).

## What exists

- The selected light icon is the violet-to-blue gradient (`docs/mockups/icons/gradient-b`). The selected dark icon is the amber-to-coral gradient (`docs/mockups/icons/gradient-c`). Both are stored in `Resources/`.
- `scripts/clean-icon.swift` removed a grey mark from the image generator in both icons.
- `build/Tiller.app` contains the dark icon in `AppIcon.icns`.
- The menu bar icon is a template image of three windows with a T in the gaps. macOS draws it in the menu bar text color.

## Decisions

- The icons were made by a Codex subagent with image generation.

## Proof

[icons-final](../../Tests/Proof/icons-final), [icons](../../Tests/Proof/icons).

## Open items

- An `.icns` file contains one appearance. The light icon needs an asset catalog compiled with `actool`. `actool` is installed only with Xcode. The question "Can `scripts/build.sh` use `actool` from Xcode for this one step?" isn't answered.
- The menu bar icon is from the first icon design (variant A). It wasn't made again with the gradient icons.
