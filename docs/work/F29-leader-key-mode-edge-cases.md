# F29: Leader key mode edge cases

Status: **Not done**

## Request

Found in the audit. There isn't a separate request.

## What exists

- Leader key mode doesn't have a timeout.
- It doesn't end on an app switch, a mouse click or a screen lock.
- If the event tap fails to start, the failure is shown only in the menu text. There isn't a retry.
- A key up event can be lost after a tap timeout. Its key code then stays in the list of stopped key codes.
