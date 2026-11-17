# F03: Container layouts: the four must-have layouts

## Request

> must have
>
> full screen (1 container),
>
> vertical split screen (2 containers, one next to the other)
>
> left two-thirds (2 containers, one on the left of the screen 2/3 of the width, and one on the right of the screen 1/3 of the width)
>
> right two-thirds (2 containers, one on the right of the screen 2/3 of the width, and one on the left of the screen 1/3 of the width).

Source: [requirements-as-written.md, section 1](../requirements-as-written.md).

## What exists

- `1`, `2`, `3` and `4` in leader key mode apply Full Screen, Vertical Split, Left Two-Thirds and Right Two-Thirds.
- A layout is applied to the workspace of the screen with the focused window.
- The workspace is the desktop inset by the workspace margin. The containers are separated by the container margin. Container edges on the workspace edge don't get a margin.
- The tiled windows on that screen are put in the containers. The focused window is put in the first container. The other windows are put in the containers round-robin, from the second container.
- Container order is left to right, then top to bottom.

## Proof

[slice-1](../../Tests/Proof/slice-1), [slice-1-overlay-dark](../../Tests/Proof/slice-1-overlay-dark). Unit tests in `Tests/TillerCoreTests/LayoutTests.swift`.
