# B08: The pill of a covered floating window was shown

## Problem

> I also noticed when you're running the tests that several times the window overlay that would appear on floating windows appears in the foreground even though a floating window is not in the foreground and is behind another window.

## Events

1. The leader key overlay is a panel above all windows.
2. A floating window can be behind a tiled window.
3. The window pill of that floating window was drawn on the leader key overlay. The window pill was shown over the tiled window.

## Fix

A window pill is shown only when other windows aren't in front of the pill position. The window order and the window frames are read from the window server.

## Proof

[covered-pills](../../Tests/Proof/covered-pills), unit test `aPointIsCoveredOnlyByWindowsInFront`.
