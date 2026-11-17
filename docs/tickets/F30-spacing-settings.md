# F30: Spacing settings

## Request

> workspace margin: workspace can have margin - this similar to built-in window management/margins in macOS

Source: [requirements-as-written.md, section 1](../requirements-as-written.md).

## What exists

The workspace margin, the container margin and the carousel spacing are constants: 10, 10 and 30 points.

## What to build

The behaviour is described in [PRD.md, section 5 "Layouts and carousels"](../PRD.md#5-layouts-and-carousels) and [PRD.md, section 11 "Settings window and menu bar menu"](../PRD.md#11-settings-window-and-menu-bar-menu).

- Make 3 mockups of the spacing settings, in the light and the dark appearance, for approval.

## Acceptance criteria

- [ ] A change of each spacing value moves the test windows to the new frames at once.
- [ ] The spacing values are kept after a relaunch.

## Proof needed

Screenshots of the mockups, of the settings page, and of the test windows before and after each change.
