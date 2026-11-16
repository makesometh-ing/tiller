# V1-19: Move a window to another container

Work file: [F33](../work/F33-move-window-between-containers.md)

## What to build

- `⇧J` in leader key mode moves the focused window to the next container. `⇧K` moves it to the previous container.
- The moved window becomes the focused window of its new carousel.
- Focus stays in the old container, on the next window of its carousel.
- `⇧J` and `⇧K` are shown in the key bar and the key list, and can be recorded in the settings.

## Acceptance criteria

- [ ] `⇧J` in the Vertical Split layout moves the focused window from container 1 to container 2.
- [ ] The moved window is in front of the carousel of container 2.
- [ ] Focus is on the next window of container 1.
- [ ] A move into an empty container works.
- [ ] The latency of each move is logged. The proof shows if the move causes flicker.

## Proof

A `tiller-proof` run with screenshots after each move, a screen recording, and the log.
