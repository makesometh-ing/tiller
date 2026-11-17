# B15: The pill of a floating window was drawn over the windows in front of it

PRD: section 9 "Leader key overlay". This bug was left after the fix of [B08](B08-covered-floating-pill-shown.md).

## Problem

> I mean, it doesn't really matter what I mean in my description. Like, can you not see the problem? That there's a window in between one window, 2 windows, doesn't really matter. There's windows in between the overlay and the window that the overlay belongs to.

Source: [requirements-as-written.md, section 20](../requirements-as-written.md).

## Events

1. The floating window "Test Floating" is behind the tiled windows "Test 1" and "Test 5". A floating window stays behind the focused window of its app.
2. The bottom-right corner of "Test Floating" is visible. The left part of the window is behind "Test 1" and "Test 5".
3. The overlay hid a pill only when another window covered one point, 20 points from the right edge of the pill.
4. That point was in the visible corner of "Test Floating". The pill was shown. The left part of the pill was drawn over "Test 5".

## Fix

The overlay hides a pill when a window in front of its window overlaps any part of the pill area. The pill width is calculated from the app name.

## Proof

[pill-covered-by-window](../../Tests/Proof/pill-covered-by-window), unit test `aPillIsCoveredOnlyByWindowsInFront`. Before the fix: screenshot 04 in [F42-stay-in-leader-key-mode/dark](../../Tests/Proof/F42-stay-in-leader-key-mode/dark).
