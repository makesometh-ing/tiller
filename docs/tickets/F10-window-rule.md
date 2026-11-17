# F10: Window rule: tiled, floating and ignored windows

## Request

> we also need to work out how to handle windows that are either a) children of main apps, for example settings windows or modals. ... do we try to "resize" those, or do we let them just pop over? how do other apps like aerospace and yabai and i3 handle it? I want like to avoid jank behavior, unexpected focus changes and resize issues as much as possible.

> this sounds great, though!

Source: [requirements-as-written.md, sections 6 and 8](../requirements-as-written.md).

## What exists

- `WindowTraits.kind` in `Sources/TillerCore/WindowTraits.swift` returns the kind of each window:
  - tiled: subrole `AXStandardWindow`, the size can be set, the parent is the app, not modal.
  - floating: other windows at window layer 0. Tiller doesn't move, resize or focus them.
  - ignored: minimized, not on screen, above window layer 0, subrole `AXUnknown` or without a subrole.
- The WeChat update window floats. Its size can't be set. Tiller doesn't move it.
- The WeChat main window and the WeChat browser window are tiled. Both are standard, resizable windows with a fullscreen button.
- `Tiller --dump-windows <path>` writes the attributes and the kind of every window to a JSON file.

## Proof

[window-rule-wechat](../../Tests/Proof/window-rule-wechat). Unit tests in `WindowTraitsTests.swift` use the attributes from the window dumps in `docs/research/`.

## Known gaps

- The WeChat chat window in its own window wasn't tested. It wasn't open during the proof runs.
- Per-app rules aren't built.
