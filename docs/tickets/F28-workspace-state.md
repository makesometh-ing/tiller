# F28: Workspace state across layouts and launches

## Request

This problem was found in the audit of the project. There isn't a separate request.

## Problem

A layout key sets the carousel mode of each container back to horizontal. Workspaces are lost when Tiller quits.

## What exists

- A layout key builds a new workspace.
- Workspaces aren't saved.

## What to build

The behaviour is described in [PRD.md, section 5 "Layouts and carousels"](../PRD.md#5-layouts-and-carousels).

## Acceptance criteria

- [ ] From Full Screen to Vertical Split: all windows stay in container 1. Container 2 is empty.
- [ ] From Vertical Split to Full Screen: the windows of container 2 go into container 1.
- [ ] `V` on container 1, then a new layout key: container 1 is still a vertical carousel.
- [ ] Quit and open Tiller: the test windows are in the same containers, with the same carousel modes.

## Proof needed

A `tiller-proof` run with screenshots before the quit and after the launch, and the saved workspace state.
