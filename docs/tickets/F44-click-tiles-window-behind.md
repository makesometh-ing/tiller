# F44: A click on a window behind the focused window makes it the focused window of its carousel

## Request

> 2. clicking a window BEHIND the focused window, should focus it and TILE IT. (like pressing h or l in leader key mode to go to the next window)

Source: [requirements-as-written.md, section 22](../requirements-as-written.md).

## What exists

- A click on the visible edge of a window behind the focused window: the app gives the window focus and brings it to the front. The window keeps its carousel frame at the edge. The frames of the other windows don't change.
- Before each focus action, Tiller reads the system focused window and sets it as the focused window of the carousel. The carousel is arranged again only at the next `H`, `L`, `J` or `K`.

## What to build

The behaviour is described in [PRD.md, section 7 "Windows"](../PRD.md#7-windows).

- Read focus changes from the Accessibility API: the focused window changed notification of each app, and the app activation from `NSWorkspace`.
- When a tiled window gets focus by a click, make it the focused window of its carousel and set the frames of the carousel, as with `H` and `L`.
- When the window is in another container, make that container the focused container.
- A focus change made by Tiller doesn't cause a second arrangement.

## Acceptance criteria

- [ ] A click on the right edge of the carousel gives the same frames as `L`.
- [ ] A click on the left edge of the carousel gives the same frames as `H`.
- [ ] A click on a window in container 2 makes container 2 the focused container. The frames of container 1 don't change.
- [ ] It works in leader key mode and out of leader key mode. In leader key mode, the click also ends leader key mode, see [F43](F43-click-ends-leader-key-mode.md).
- [ ] The latency from the click to the new frames is logged.

## Proof needed

A `tiller-proof` run with click steps on the carousel edges, screenshots after each click, the screen recording and the log.
