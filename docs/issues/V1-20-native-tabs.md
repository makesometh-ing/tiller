# V1-20: One tile for each native tab group

Work file: [F34](../work/F34-native-tabs.md)

## What to build

- Read the background tabs of an app from the CoreGraphics window list: windows of the same app, off the screen, at the same frame as a tiled window.
- When the visible window id changes at the same frame, the new id replaces the old id in the carousel.
- A new tab doesn't add a tile. A closed tab doesn't remove the tile while another tab of the group is open.

## Acceptance criteria

- [ ] A Finder window with two tabs is one tile.
- [ ] A tab switch in Finder keeps the window at the same place in its carousel.
- [ ] A new tab and a closed tab in Terminal don't change the containers.
- [ ] The latency of each tab switch is logged.

## Proof

A `tiller-proof` run with Finder and Terminal: screenshots before and after each tab switch, and the log.
