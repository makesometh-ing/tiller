# F20: Global shortcuts: a second shortcut for each action

## Request

> we should be able to define a leader key layer key AND a non-leader shortcut (two columns) for each key except leader key. give me a mockup to check design, before we start coding.

Source: [requirements-as-written.md, section 10](../requirements-as-written.md).

## What exists

The behaviour is described in [PRD.md, section 11 "Settings window and menu bar menu"](../PRD.md#11-settings-window-and-menu-bar-menu).

Approved designs, listed in [docs/mockups/README.md](../mockups/README.md):

- Variant 3 of the Shortcuts page in [settings-v2.html](../mockups/settings-v2.html): a segmented control with "Leader key mode" and "Global". Source: [requirements-as-written.md, section 14](../requirements-as-written.md).
- Variant 1 in [exit-leader-key-mode.html](../mockups/exit-leader-key-mode.html): the "Global shortcuts" group and the "Exit after" checkbox column. Source: [requirements-as-written.md, section 19](../requirements-as-written.md).

Built:

- `Shortcuts.global` in `Sources/TillerCore/KeyChord.swift` contains the global shortcut of each action. It is saved with the other shortcuts. Shortcuts saved before this change get empty global shortcuts.
- `Shortcuts.conflict` returns the shortcut that already uses a chord: the leader key, the shortcut to turn Tiller on and off, or another global shortcut. A global shortcut without a modifier is refused.
- The event tap does the action of a global shortcut and stops the key press, in every app and in leader key mode. It writes a `global.key` log event.
- The Shortcuts page has the segmented control in the title row. "Leader key mode" shows the keys with the "Exit after" column. "Global" shows one global shortcut field for each action. A refused chord shows "Used by" and the other shortcut for 2 seconds.
- Proof tools: `--global`, the `global:`, `shortcuts-mode:` and `record:global:` steps. See [PRD.md, section 15 "Proof and test tools"](../PRD.md#15-proof-and-test-tools).

## Proof

[F20-global-shortcuts](../../Tests/Proof/F20-global-shortcuts): two proof runs, dark and light, with `--global focusNextWindow=hyper+y`. All steps pass. Hyper Y did "Focus next window" 3 times in each run, and the chord didn't reach the test windows. The "Full screen layout" field refused Hyper Y ("Used by Focus next window") and the leader key ("Used by Leader key"), then saved ⌃⌥⇧ U. ⌃⌥⇧ U then applied the Full Screen layout. `settings-window/` shows the "Leader key mode" page and the "Global" page in both appearances. Latency of a global shortcut: 22 to 34 ms.
