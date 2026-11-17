# B13: The leader key from Hyperkey is recorded and detected as ⌘

## Problem

> I just tried recording a leader key of Hyper + L and it recorded `cmd + L`. what gives? I'm using the Hyperkey app to remap caps lock to hyper.

## Events

1. Hyperkey changes Caps Lock to left ⌘ with a `hidutil` key mapping.
2. Hyperkey adds ⌃⌥⇧ to each key event in its own event tap at the session tap point.
3. Tiller's event tap was also at the session tap point, inserted at the head. Tiller started after Hyperkey. Tiller's tap then received each key event first.
4. Tiller's tap received L with only ⌘. The chord ⌘ L was saved.
5. A leader key of ⌃⌥⇧⌘ L saved before Hyperkey was used isn't detected. Tiller's tap receives ⌘ L from Hyperkey. ⌘ L doesn't match the leader key.

## Fix

Tiller's event tap is at the annotated session tap point. Each key event is received there after every session tap. The modifier flags from Hyperkey and other key remappers are then included.

## Proof

[B13-hyperkey-leader](../../Tests/Proof/B13-hyperkey-leader): the end-to-end test passes with the tap at the annotated session tap point.

## Proof needed

- A recording of the leader key with Caps Lock and L in Hyperkey shows ⌃⌥⇧⌘ L.
- Caps Lock and L in Hyperkey start leader key mode.

Synthetic key events don't start Hyperkey. This test is done on your laptop with the physical keys.
