# F08: Focus keys: H, L, J and K

Status: **Done**

## Request

> j and k to focus the next/previous container?

Source: [requirements-as-written.md, section 5](../requirements-as-written.md).

## What exists

- `H` and `L` focus the previous and next window in the carousel of the focused container.
- `K` and `J` focus the previous and next container. Empty containers are skipped. The order wraps.
- Before a focus step, Tiller reads the focused window. A click on another window is then used as the start point.

## Proof

[slice-1](../../Tests/Proof/slice-1).
