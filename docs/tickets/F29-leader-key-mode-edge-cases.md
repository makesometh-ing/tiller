# F29: Leader key mode edge cases

## Request

These problems were found in the audit of the project. There isn't a separate request.

## What exists

- Leader key mode doesn't have a timeout.
- It doesn't end on an app switch, a mouse click or a screen lock.
- If the event tap fails to start, the failure is shown only in the text of the Tiller menu. There isn't a retry.
- A key up event can be lost after an event tap timeout. Its key code then stays in the list of stopped key codes.

## What to build

The behaviour is described in [PRD.md, section 6 "Leader key mode"](../PRD.md#6-leader-key-mode).

- Clear the list of stopped key codes when leader key mode ends.

## Acceptance criteria

- [ ] Each problem listed under "What exists" has a step in `tiller-proof` or a unit test.

## Proof needed

The `tiller-proof` run and the unit test output.
