# F33: Move a window to another container

Status: **Not done**

## Request

> and one thing we never addressed - how do we move windows between containers? there needs to be a way to do this reliably, too. Assuming that moving a window to a new container will make it the "focused" window in the new container. we also shouldn't then focus the new container, since the use likely wants to shift other windows about.

> fine with me

Source: [requirements-as-written.md, section 15](../requirements-as-written.md).

## What exists

There isn't an action to move a window to another container.

## Decisions

- `⇧J` in leader key mode moves the focused window to the next container. `⇧K` moves it to the previous container.
- The moved window becomes the focused window of its new carousel.
- Focus stays in the old container, on the next window of its carousel.

## Open items

- With SIP enabled, a window of an inactive app can't be put in front of the windows of other apps. Test this sequence for flicker: focus the moved window, then focus the window in the old container.
