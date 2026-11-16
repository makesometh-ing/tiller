# V1-13: Save the key bar position of a proof run in the proof defaults

Work file: [B11](../work/B11-key-bar-position-saved-in-proof-runs.md)

## What to build

During a proof run, the key bar position is saved in `com.tiller.Tiller.proof`.

## Acceptance criteria

- [ ] The key bar position in `com.tiller.Tiller` is the same before and after a proof run.

## Proof

`defaults read com.tiller.Tiller` before and after a proof run.
