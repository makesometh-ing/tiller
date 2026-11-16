# B06: The settings window opened behind other windows

Status: **Fixed**

## Problem

In the first Hyper proof run, the settings window wasn't visible.

## Events

1. The proof runner opened the settings window.
2. macOS doesn't bring an app to the front when the activation isn't caused by a click.
3. The window opened behind the test windows.

## Fix

The window is ordered to the front with `orderFrontRegardless`.

## Proof

[hyper-dark](../../Tests/Proof/hyper-dark).
