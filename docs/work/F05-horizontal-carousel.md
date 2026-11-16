# F05: Horizontal carousel

Status: **Done**

## Request

The rules for one, two, and three or more windows are in [requirements-as-written.md, section 1](../requirements-as-written.md).

## What exists

- One window fills the container.
- Two windows: the focused window F starts at x = 0 with width W − S. The other window starts at x = S and fills to the container edge.
- Three or more windows: F starts at S with width W − 2S. F − 1 starts at 0. F + 1 starts at 2S. All other windows start at S. The windows are in a ring, and the ring wraps.
- `H` and `L` in leader key mode focus the previous and next window in the ring.
- A focus step moves at most 4 windows, for any number of windows.
- Only F is raised. The other windows of the carousel don't cover the visible edges of F − 1 and F + 1. Their z-order doesn't matter.

## Decisions

- With SIP enabled, the z-order of the windows of other apps can't be set. A window can only be raised to the top. The carousel rules need only F on top.

## Proof

[slice-1](../../Tests/Proof/slice-1). Unit tests in `Tests/TillerCoreTests/CarouselTests.swift`.
