# V1-02: Peek: the P key

Work file: [F12](../work/F12-peek.md)

## What to build

- `P` in leader key mode fills the workspace with the focused window. The workspace margin is kept.
- `P` again returns the window to its container.
- A focus change to another tiled window also returns the window to its container.
- `P` doesn't do anything in the Full Screen layout.
- `P` is shown on the window pill of a tiled window and in the key bar.

## Acceptance criteria

- [ ] `P` in the Vertical Split layout fills the workspace with the focused window.
- [ ] `P` again puts the window back at its carousel frame.
- [ ] `J`, `K`, `H` or `L` during peek returns the window to its container.
- [ ] `P` in the Full Screen layout doesn't move a window.
- [ ] The window pill and the key bar show `P`, in the light and the dark appearance.

## Proof

A `tiller-proof` run with screenshots before peek, during peek and after peek, and the log with the latency of each step.
