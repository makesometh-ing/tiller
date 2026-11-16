# F13: Windows that open after a layout is applied

Status: **Not done**

## Request

Slice 1 excluded "windows opened after a layout is applied". The owner's comment: "perfect". Source: [requirements-as-written.md, section 5](../requirements-as-written.md).

## What exists

A window that opens after a layout is applied stays outside every container until the next layout key.

## Open items

- Decide where a new tiled window goes, for example after the focused window in the focused container.
- Watch for new windows with Accessibility notifications. Closed windows are removed only at the next action now.
