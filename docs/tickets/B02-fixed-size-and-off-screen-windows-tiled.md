# B02: Windows with a fixed size and windows not on screen were tiled

## Problem

The window dump showed two kinds of windows tiled in error by slice 1: the Xcode welcome window and tldraw windows not on screen.

## Events

1. Slice 1 tiled every window with subrole `AXStandardWindow`.
2. The Xcode welcome window can't be resized.
3. The window server listed tldraw windows as not on screen. The Accessibility API listed the same windows.

## Fix

The window rule tiles only windows on screen with a settable size. See [F10: Window rule: tiled, floating and ignored windows](F10-window-rule.md).

## Proof

[window-rule-wechat](../../Tests/Proof/window-rule-wechat), unit tests in `WindowTraitsTests.swift`.
