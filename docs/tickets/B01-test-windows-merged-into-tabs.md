# B01: Test windows merged into one window with tabs

## Problem

The first proof run tiled only one window. macOS merged the 5 test windows into one window with tabs.

## Events

1. "Prefer tabs: Always" is set in your System Settings.
2. The test app opened 5 windows.
3. macOS merged them into one window with 5 tabs.

## Fix

The test app sets `NSWindow.allowsAutomaticWindowTabbing = false`.

## Proof

[slice-1](../../Tests/Proof/slice-1).
