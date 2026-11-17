# B11: A proof run saves the key bar position in your defaults

## Problem

This bug was found in the project audit. `OverlayController.hide` hides the key bar. It saved the key bar position in the standard defaults, also during a proof run.

## Events

1. A proof run shows and hides the key bar.
2. The key bar position is saved in `com.tiller.Tiller`.
3. Your saved key bar position changes.

## Fix

The key bar position is read from and saved in the defaults domain of `ShortcutStore`. In a proof run, this is `com.tiller.Tiller.proof`. The proof domain is emptied when Tiller starts with `--proof`. Each proof run then starts with the key bar at the default position.

The `move-bar` proof step moves the key bar by the same distance as a drag.

## Proof

[B11-key-bar-position](../../Tests/Proof/B11-key-bar-position): a proof run with the steps `1,leader,move-bar,esc,leader,esc`. `barOrigin` in `com.tiller.Tiller` is `{581, 90}` before and after the run. `barOrigin` in `com.tiller.Tiller.proof` is `{650, 150}` after the run. The second `leader` step shows the key bar at the moved position.
