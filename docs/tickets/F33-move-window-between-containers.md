# F33: Move a window to another container

## Request

> and one thing we never addressed - how do we move windows between containers? there needs to be a way to do this reliably, too. Assuming that moving a window to a new container will make it the "focused" window in the new container. we also shouldn't then focus the new container, since the use likely wants to shift other windows about.

> fine with me

Source: [requirements-as-written.md, section 15](../requirements-as-written.md).

## What exists

The behaviour is described in [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode).

- `⇧J` and `⇧K` in leader key mode move the focused window to the next or previous container. The moved window becomes the focused window of its new carousel. Focus stays in the old container, on the next window of its carousel.
- A move into an empty container works. When the old container is empty after the move, the new container becomes the focused container.
- The first and the last container wrap around. In the Full Screen layout, a window isn't moved.
- The "Exit after" setting of both actions is off by default. Leader key mode continues and the overlay is updated after each move.
- Both actions are in the WINDOW section of the key bar, the key list and the Shortcuts page, with an empty global shortcut by default. Saved shortcuts get `⇧J` and `⇧K` when another action doesn't use them.
- `Workspace.moveFocusedWindow(offset:)` in `Sources/TillerCore/Workspace.swift` changes the containers. `Controller` sets the frames and gives focus to the new focused window of the old container.
- Each move writes `action.done` with the moved window, the old and the new container, and the latency.

## Proof

[F33-move-window](../../Tests/Proof/F33-move-window): a proof run in the dark appearance and a proof run in the light appearance, with 20 steps each. All steps pass. Each move was checked: the moved window is the focused window of the other container, focus is on the next window of the old carousel, and the focused window of each carousel is in front of the other windows of that carousel. Moves into an empty container, out of the last window of a container and from the last container to container 1 work. In the Full Screen layout, `⇧J` doesn't move a window. The screen recording doesn't show flicker. Latency from the key press: 20.5 to 38.2 ms. `scripts/check-log.py`: 112 lines, 0 failed. Unit tests `moveFocusedWindowPutsItInFrontOfTheNextCarouselAndKeepsFocusInTheOldContainer`, `moveFocusedWindowWrapsAroundAndFocusesTheNextWindowOfTheRing`, `moveIntoAnEmptyContainerAndOutOfTheLastWindowOfAContainer`, `moveDoesNothingWithOneContainerOrWithoutAFocusedWindow`, `moveActionsUseShiftJAndShiftKAndKeepLeaderKeyMode`, `shiftJDoesNotRunJAndJDoesNotRunShiftJ` and `savedShortcutsGetShiftJAndShiftKWhenTheyAreNotUsed`.
