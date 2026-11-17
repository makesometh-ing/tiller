# F08: Focus keys: H, L, J and K

## Request

> j and k to focus the next/previous container?

Source: [requirements-as-written.md, section 5](../requirements-as-written.md).

## What exists

- `H` and `L` focus the previous and next window in the carousel of the focused container.
- `K` and `J` focus the previous and next container. Empty containers are skipped. The order wraps.
- Before a focus step, Tiller reads the focused window. After a click on another window, the focus step starts from that window.

## Proof

[slice-1](../../Tests/Proof/slice-1).
