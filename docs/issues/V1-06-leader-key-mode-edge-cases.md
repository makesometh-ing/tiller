# V1-06: End leader key mode on a timeout, an app switch, a click and a screen lock

Work file: [F29](../work/F29-leader-key-mode-edge-cases.md)

## What to build

- Leader key mode ends 10 seconds after the last key press. It doesn't end while the key list is open.
- Leader key mode ends on an app switch, a mouse click and a screen lock.
- When the event tap doesn't start, the menu shows the failure. Tiller starts the event tap again every second until it starts.
- Tiller keeps a list of the key codes that weren't sent to the focused app. This list is cleared when leader key mode ends.

## Acceptance criteria

- [ ] Each item above has a step in `tiller-proof` or a unit test.

## Proof

The `tiller-proof` run and the unit test output.
