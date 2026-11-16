# F34: One tile for each native tab group

Status: **Not done**

## Request

> how do we handle windows that want to use native tabs? I don't want to force individual tiles ...

> yes

Source: [requirements-as-written.md, section 15](../requirements-as-written.md).

## What exists

- Research and a test on the owner's Mac: [research/native-tabs.md](../research/native-tabs.md).
- Each tab of a native tab group is a separate window in the window server, at the same frame. Only the window of the selected tab is on the screen. A tab switch changes the window id of the visible window.
- A tab switch isn't handled. The new window id isn't in a container.

## Decisions

- One tile for each native tab group, in v1.
- When the visible window id changes at the same frame, the new id replaces the old id in the carousel.
