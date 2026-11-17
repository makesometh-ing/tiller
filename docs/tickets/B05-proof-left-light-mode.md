# B05: A proof run left your Mac in light mode

## Problem

After the first dark mode run, your Mac stayed in light mode.

## Events

1. The proof runner read the appearance from the wrong defaults domain.
2. The read returned light mode.
3. At the end of the run, the proof runner set light mode.

## Fix

The proof runner reads the appearance with `osascript`. Dark mode was restored on your Mac.

## Proof

[slice-1-overlay-dark](../../Tests/Proof/slice-1-overlay-dark).
