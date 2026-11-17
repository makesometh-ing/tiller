# B12: Your typing during a proof run failed the key check

## Problem

A dark mode run failed. The key log contained `n` from your typing during the run.

## Events

1. The key check counted every log line with a key code that was also sent by the run.
2. You typed `n` during the run.
3. The run also sent Hyper N.

## Fix

The key check compares the key code and the modifiers of each chord sent by the run.

## Proof

[hyper-dark](../../Tests/Proof/hyper-dark).
