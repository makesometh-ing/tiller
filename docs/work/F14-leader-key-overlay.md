# F14: Leader key overlay: containers and window pills

Status: **Done**

## Request

> one of the things that I want in leader key mode is to show a small translucent overlay over containers to show container edges, which mode they're in (i.e. horizontal or vertical carousel) and for windows to show a status line with button for peek, and to toggle floating or not.

The design feedback is in [requirements-as-written.md, section 9](../requirements-as-written.md).

## What exists

- Each container gets a teal tint and edge. The focused container is brighter.
- A solid chip is on the top edge of each container, over the border. The chip of the focused container is teal. The other chips are grey.
- The chip shows the container number, ⇆ or ⇅, a window-stack icon with the window count, and the `V` key. The icon is the SF Symbol `rectangle.on.rectangle`, drawn in the chip text color.
- A tooltip on the `V` key shows what the key does, for example "Switch to vertical carousel". Clicks still go to the windows below the overlay.
- Each window gets a small translucent pill at its bottom-right corner: the real app icon, the app name, Tiled or Floating, and the `F` key.
- A window behind the focused window in a carousel shows only its app icon, in its visible edge.
- A pill isn't shown when another window covers the place of the pill.
- The key bar is shown at once. The containers and pills are shown after the window read, in 18 to 30 ms.
- The overlay reads the windows on its own queue. This doesn't delay an action key.

## Decisions

- Mockups: [leader-mode.html](../mockups/leader-mode.html), [leader-mode-v2.html](../mockups/leader-mode-v2.html), [leader-mode-v3.html](../mockups/leader-mode-v3.html) and [leader-mode-v4.html](../mockups/leader-mode-v4.html). Variant 3 of v3 was selected: teal chip on the focused container, grey chips on the others.
- The pill shows the state (Tiled or Floating), at the bottom-right corner.
- `F` is the only float key.

## Proof

[slice-1-overlay-dark](../../Tests/Proof/slice-1-overlay-dark), [slice-1-overlay-light](../../Tests/Proof/slice-1-overlay-light), [overlay-chip-fix-dark](../../Tests/Proof/overlay-chip-fix-dark), [covered-pills](../../Tests/Proof/covered-pills).

## Open items

- The `P` key isn't on the pill yet. See [F12](F12-peek.md).
- At the bottom-right corner, the key bar can cover the pill of a window in the left container. The key bar can be dragged away.
