# F25: Diagnostic tools: window dump and focus test

## Request

These tools were built for the research on child windows and focus. There isn't a separate request.

## What exists

- `Tiller --dump-windows <path>` writes the Accessibility attributes and the window kind of every window to a JSON file.
- `Tiller --focus-test <bundle id> <window id> <method> <path>` focuses one window with one method. It then writes the front-to-back window order.

## Proof

The window dumps are in `docs/research/`. The focus test results are in [focus-floating](../../Tests/Proof/focus-floating).
