# V1-07: Global shortcuts

Work file: [F20](../work/F20-global-shortcuts.md)

## What to build

- The Shortcuts page is variant 3 in [settings-v2.html](../mockups/settings-v2.html). A segmented control at the top of the page shows the action keys ("Leader key mode") or the global shortcuts ("Global").
- Each action has a global shortcut, in addition to its action key. The leader key doesn't have a global shortcut.
- A global shortcut does its action without the leader key. The focused app doesn't receive it.
- A global shortcut can't be the same chord as the leader key or as another global shortcut.
- Global shortcuts are empty by default.

## Acceptance criteria

- [ ] A Hyper global shortcut for "Focus next window" does the action.
- [ ] The shortcut field doesn't save a chord that is already a global shortcut or the leader key.
- [ ] The Shortcuts page matches variant 3 in the light and the dark appearance.

## Proof

A `tiller-proof` run with `--keys` set to global shortcuts, and screenshots of the Shortcuts page.
