# B03: Screen recording of a proof run wasn't saved

## Problem

`run.mov` was missing after the second proof run.

## Events

1. The proof runner started `screencapture -v`.
2. The proof runner stopped `screencapture` with an interrupt.
3. `screencapture` discards the video when it is interrupted.

## Fix

The proof runner records for a fixed time. Then it waits for the recording to end.

## Proof

Each proof bundle in [Tests/Proof](../../Tests/Proof) contains `run.mov`.
