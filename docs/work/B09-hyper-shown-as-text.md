# B09: A Hyper chord was shown as "Hyper"

Status: **Fixed**

## Problem

> "Hype" shouldn't be the shortcut text, it should show all the keys that are assigned

## Events

1. A chord with all four modifiers was shown as "Hyper L".

## Fix

A chord shows all its modifier symbols, for example "⌃⌥⇧⌘ L".

## Proof

[covered-pills](../../Tests/Proof/covered-pills) (step 7), unit test `hyperSpecIsAllFourModifiers`.
