# V1-04: Keep the carousel mode and restore workspaces after a launch

Work file: [F28](../work/F28-workspace-state.md)

## Problem

A layout key sets the carousel mode of each container back to horizontal. Workspaces are lost when Tiller quits.

## What to build

- A layout key keeps each window in its container number. A new container is empty until a window is moved into it.
- The windows of a removed container go into the last container of the new layout.
- A layout key keeps the carousel mode of each container number that exists in the new layout.
- The layout, the containers, the carousel mode and the windows of each workspace are saved, with the display UUID as the key.
- After a launch, each window that still exists goes back to its saved container.

## Acceptance criteria

- [ ] From Full Screen to Vertical Split: all windows stay in container 1. Container 2 is empty.
- [ ] From Vertical Split to Full Screen: the windows of container 2 go into container 1.
- [ ] `V` on container 1, then a new layout key: container 1 is still a vertical carousel.
- [ ] Quit and open Tiller: the test windows are in the same containers, with the same carousel modes.

## Proof

A `tiller-proof` run with screenshots before the quit and after the launch, and the saved workspace state.
