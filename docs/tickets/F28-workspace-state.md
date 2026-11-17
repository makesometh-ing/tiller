# F28: Workspace state across layouts and launches

## Request

This problem was found in the audit of the project. There isn't a separate request.

## Problem

Workspaces are lost when Tiller quits. The carousel mode of each container across layout changes is part of [F45](F45-carousel-mode-per-layout.md).

## What exists

- A layout key builds a new workspace.
- Workspaces aren't saved.

## What to build

The behaviour is described in [PRD.md, section 5 "Layouts and carousels"](../PRD.md#5-layouts-and-carousels).

## Acceptance criteria

- [ ] From Full Screen to Vertical Split: all windows stay in container 1. Container 2 is empty.
- [ ] From Vertical Split to Full Screen: the windows of container 2 go into container 1.
- [ ] Quit and open Tiller: the test windows are in the same containers, with the same carousel modes.

## Proof needed

A `tiller-proof` run with screenshots before the quit and after the launch, and the saved workspace state.
