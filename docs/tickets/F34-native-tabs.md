# F34: One tile for each native tab group

## Request

> how do we handle windows that want to use native tabs? I don't want to force individual tiles ...

> yes

Source: [requirements-as-written.md, section 15](../requirements-as-written.md).

## What exists

- The research and the results of a test on the owner's Mac are in [research/native-tabs.md](../research/native-tabs.md).
- Each tab of a native tab group is a separate window in the window server, at the same frame. Only the window of the selected tab is on the screen. A tab switch changes the window id of the visible window.
- A tab switch isn't handled. The new window id isn't in a container.

## What to build

The behaviour is described in [PRD.md, section 7 "Windows"](../PRD.md#7-windows).

- Read the background tabs of an app from the CoreGraphics window list: windows of the same app, off the screen, at the same frame as a tiled window.

## Acceptance criteria

- [ ] A Finder window with two tabs is one tile.
- [ ] After a tab switch in Finder, the window stays at the same place in its carousel.
- [ ] A new tab and a closed tab in Terminal don't change the containers.
- [ ] The latency of each tab switch is logged.

## Proof needed

A `tiller-proof` run with Finder and Terminal: screenshots before and after each tab switch, and the log.
