# F07: Leader key mode

Status: **Done**

## Request

> we will access tiller via a "leader" key interaction pattern, that means that a single key shortcut will activate the tiller app layer and then further keys will be used to perform actions/functions. at first we'll build one layer, but we might want to build multiple layers in the future to isolate categories of actions

Source: [requirements-as-written.md, section 2](../requirements-as-written.md).

## What exists

- A `CGEventTap` reads each key press. The leader key starts leader key mode.
- In leader key mode, each key press is stopped. The focused app doesn't receive it.
- An action key does its action and ends leader key mode.
- `Esc` or a second press of the leader key ends leader key mode.
- `?` opens the key list. Leader key mode stays active.
- A key without an action is stopped. Leader key mode stays active.
- The event tap is enabled again after a timeout of the tap. The log records it.
- The default leader key is ⌃⌥ Space. The leader key can be recorded in the settings.

## Decisions

- The leader key is ⌃⌥ Space until a settings window exists. This was approved. The settings window exists now.

## Proof

[slice-1](../../Tests/Proof/slice-1), [hyper-dark](../../Tests/Proof/hyper-dark). Each proof run checks that the key presses don't reach the test windows.

## Open items

- Leader key mode doesn't have a timeout. It doesn't end on an app switch, a click or a screen lock. See [F29](F29-leader-key-mode-edge-cases.md).
- More than one layer isn't built. See [F26](F26-multiple-layers.md).
