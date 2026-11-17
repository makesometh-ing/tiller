# F13: Windows that open after a layout is applied

## Request

Slice 1 excluded "windows opened after a layout is applied". The owner's comment: "perfect". Source: [requirements-as-written.md, section 5](../requirements-as-written.md).

## Problem

A window that opens after a layout is applied stays outside every container until the next layout key. A closed window stays in its container until the next action.

## What to build

The behaviour is described in [PRD.md, section 7 "Windows"](../PRD.md#7-windows).

- Read the Accessibility notifications for a created window, a closed window and a minimized window.

## Acceptance criteria

- [ ] A test window opened after a layout key is put in the focused container, after the focused window.
- [ ] The fixed-size test window opened after a layout key doesn't change a container.
- [ ] A closed test window is removed from its carousel at once.
- [ ] A minimized test window is removed from its carousel at once.
- [ ] An unminimized test window is put back in its container, at its ring position.
- [ ] A hidden app and an app shown again give the same result as a minimized and an unminimized window.
- [ ] Each change is logged with its latency.

## Proof needed

A `tiller-proof` run that opens, closes and minimizes test windows after a layout key: screenshots after each step and the log.
