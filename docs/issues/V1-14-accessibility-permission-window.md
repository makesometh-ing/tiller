# V1-14: Accessibility permission window at the first launch

## Problem

Without the Accessibility permission, Tiller shows the macOS prompt one time. After that, the permission is shown only as one line in the Tiller menu. A new user doesn't get an explanation of why Tiller needs the permission.

## What to build

- Make 3 mockups in the light and the dark appearance for approval.
- A window opens at launch when Tiller doesn't have the Accessibility permission. It says why the permission is needed. It has a button that opens System Settings → Privacy & Security → Accessibility.
- The window closes when the permission is granted. Leader key mode then works without a relaunch.

## Acceptance criteria

- [ ] After `tccutil reset Accessibility com.tiller.Tiller`, the window opens at launch.
- [ ] The window closes after the permission is granted.
- [ ] The leader key works after the window closes.

## Proof

Screenshots of the mockups, of the window, and of the leader key overlay after the permission is granted.
