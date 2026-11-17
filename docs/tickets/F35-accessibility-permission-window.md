# F35: Accessibility permission window at the first launch

## Request

This ticket was added for the release of Tiller to other users. There isn't a separate request.

## Problem

Without the Accessibility permission, Tiller shows the macOS Accessibility prompt one time. After that, the permission state is shown only as one line in the Tiller menu. A new user isn't told why Tiller must have the permission.

## What to build

The behaviour is described in [PRD.md, section 4 "Platform and build"](../PRD.md#4-platform-and-build).

- Make 3 mockups of the permission window, in the light and the dark appearance, for approval.

## Acceptance criteria

- [ ] After `tccutil reset Accessibility com.tiller.Tiller`, the permission window opens at launch.
- [ ] The permission window closes after the permission is granted.
- [ ] The leader key works after the permission window closes.

## Proof needed

Screenshots of the mockups, of the permission window, and of the leader key overlay after the permission is granted.
