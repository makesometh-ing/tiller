# B11: A proof run saves the key bar position in your defaults

Status: **Not fixed**

## Problem

Found in the audit. `OverlayController.hide` hides the key bar. It saves the key bar position in the standard defaults, also during a proof run.

## Events

1. A proof run shows and hides the key bar.
2. The key bar position is saved in `com.tiller.Tiller`.
3. Your saved key bar position changes.

## Fix

Save the key bar position in the proof defaults domain during a proof run.
