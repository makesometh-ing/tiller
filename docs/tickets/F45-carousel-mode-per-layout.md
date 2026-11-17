# F45: The carousel mode of each container is kept across layout changes

## Request

> 3. carousel mode (horizontal or vertical) should not be reset when switching between layouts. if I've in vertical carousel mode in layout 1, and I got to layout 2 and back to layout 1, it should still be in vertical carousel mode

Source: [requirements-as-written.md, section 22](../requirements-as-written.md).

## What exists

The behaviour is described in [PRD.md, section 5 "Layouts and carousels"](../PRD.md#5-layouts-and-carousels).

- `Workspace.savedAxes` in `Sources/TillerCore/Workspace.swift` contains the carousel mode of each container, for each layout. `V` writes the modes of the current layout to it. `Workspace.apply` gives each container its saved mode. A container without a saved mode is horizontal.
- A layout key builds a new workspace for the screen. The new workspace gets the saved modes of the old workspace of the same screen. Each screen has its own saved modes.
- The action name of a layout in the log lists the mode of each container, for example `layout:verticalSplit:horizontal-vertical`.
- The saved modes are kept until Tiller quits. Saving them across launches is part of [F28](F28-workspace-state.md).

## Proof

[F45-carousel-mode-per-layout](../../Tests/Proof/F45-carousel-mode-per-layout): a proof run with the steps `1,v,leader,esc,2,leader,esc,1,leader,esc,2,j,v,leader,esc,1,leader,esc,2,leader,esc`. All steps pass. After `1`, `V`, `2`, `1`, the Full Screen container is a vertical carousel. After `2`, `J`, `V`, `1`, `2`, the chip of container 1 shows ⇆ and the chip of container 2 shows ⇅. Unit tests check the saved modes and the separate modes of two screens. Layout latency: 31 to 64 ms.
