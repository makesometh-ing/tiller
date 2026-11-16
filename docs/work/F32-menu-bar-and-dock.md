# F32: Show Tiller in the menu bar, the Dock or both

Status: **Not done**

## Request

> needs an option about Dock only, Menu bar only, Menu bar and Dock thing.

Source: [requirements-as-written.md, section 14](../requirements-as-written.md).

## What exists

- Tiller is shown only in the menu bar.
- Mockups only: [general-page.html](../mockups/general-page.html). The General page has a "Menu bar and Dock" group with a "Show Tiller in" setting:
  - Variant 1: a pop-up button.
  - Variant 2: a segmented control with "Menu bar", "Dock" and "Both".
  - Variant 3: three cards, each with a small picture of the screen and the place of the Tiller icon.

## Decisions

- The control is variant 2 in [general-page.html](../mockups/general-page.html): a segmented control with "Menu bar", "Dock" and "Both". Source: [requirements-as-written.md, section 14](../requirements-as-written.md).
- The three values are "Menu bar only", "Dock only" and "Menu bar and Dock". The default is "Menu bar only".
- With "Dock only", a click on the Tiller icon in the Dock opens the settings. The Dock menu of Tiller contains "Enable Tiller".

## Open items

- Build the setting.
