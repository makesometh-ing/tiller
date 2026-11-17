# F45: The carousel mode of each container is kept across layout changes

## Request

> 3. carousel mode (horizontal or vertical) should not be reset when switching between layouts. if I've in vertical carousel mode in layout 1, and I got to layout 2 and back to layout 1, it should still be in vertical carousel mode

Source: [requirements-as-written.md, section 22](../requirements-as-written.md).

## What exists

A layout key builds a new workspace. The carousel mode of each container is set to horizontal.

## What to build

The behaviour is described in [PRD.md, section 5 "Layouts and carousels"](../PRD.md#5-layouts-and-carousels).

- Save the carousel mode of each container for each layout and screen.
- When a layout is applied, set the saved carousel mode of each container.
- Saving the modes across launches is part of [F28](F28-workspace-state.md).

## Acceptance criteria

- [ ] `1`, `V`, `2`, `1`: container 1 is a vertical carousel.
- [ ] `2`, `J`, `V`, `1`, `2`: container 2 is a vertical carousel. Container 1 is horizontal.
- [ ] The carousel modes of one screen don't change the carousel modes of another screen.

## Proof needed

A `tiller-proof` run with these steps and screenshots of the container chips after each layout key.
