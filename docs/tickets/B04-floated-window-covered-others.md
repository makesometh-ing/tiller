# B04: A floated window kept its carousel frame and covered the other windows

## Problem

After `F`, the floated window kept the frame from its layout. The floated window covered all other windows.

## Events

1. A window was tiled in a carousel.
2. `F` floated it.
3. Its frame didn't change.

## Fix

The floated window is returned to its frame before Tiller first tiled it.

## Proof

[slice-2-floating](../../Tests/Proof/slice-2-floating).
