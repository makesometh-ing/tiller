# F06: Vertical carousel and the V key

## Request

> we're obviously going to have a shortcut to switch between horizontal or vertical. Maybe not in slice one, but you need to bring that into the design.

> If we do in the leader key mode, is it just going to switch for whatever the selected container is? That's fine by me or the active container. I think that's a good way to do it. But maybe the key should be S, like switch, or yeah, V is fine.

Source: [requirements-as-written.md, sections 1 and 9](../requirements-as-written.md).

## What exists

- The vertical carousel uses the rules of the horizontal carousel on the y axis.
- `V` in leader key mode switches the focused container between horizontal and vertical. The other containers don't change.

## Proof

[vertical-carousel](../../Tests/Proof/vertical-carousel), [slice-1-overlay-dark](../../Tests/Proof/slice-1-overlay-dark). Unit tests in `CarouselTests.swift` and `WorkspaceTests.swift`.
