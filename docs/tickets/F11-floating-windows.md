# F11: Floating windows: the F and R keys

## Request

> The other thing is obviously "floating" windows, which we will allow to be rendered outside of the container and workspace edges.

> fine with this, but what about focusing an app with multiple windows using the carousel or a click - will it bring them to the front? I think it should...

> Option one is probably the best for the moment.

Source: [requirements-as-written.md, sections 6 and 8](../requirements-as-written.md).

## What exists

- `F` in leader key mode floats the focused tiled window. The window goes back to its frame before Tiller first tiled it. If that frame isn't on the workspace, the window gets the center 60 % of the workspace. The other windows of its container fill the space.
- `F` on a window floated by `F` puts it back in the focused container, after the focused window.
- `F` on a window floated by the window rule does nothing.
- `R` raises the floating windows of the focused app. The front floating window gets focus.
- A focus on a window brings all windows of its app in front of other apps. The floating windows of that app stay behind the focused window.
- A new floating window doesn't cause a re-layout or a focus change.

## Proof

[slice-2-floating](../../Tests/Proof/slice-2-floating), [focus-floating](../../Tests/Proof/focus-floating). `Tiller --focus-test` tested 4 focus methods with the WeChat windows: `ax`, `all-windows`, `raise-floating` and `raise-floating-keep-focus`.

## Known gaps

- The `F` key doesn't show a message when the window can't be tiled.
