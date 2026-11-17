# Tiller

Tiller is a tiling window manager for macOS. It is a menu bar app.

## Requirements that apply to all work

- A task is marked done only with a proof bundle: logs, screenshots, screen recordings or test output. Proof bundles are stored in `Tests/Proof/<task>/`. Git ignores this folder. Proof bundles are thrown away after review.
- Before UI is built, make at least 3 mockups for approval. Show each mockup in the light and the dark appearance. The look must match the quality of `docs/references/ui-alcove-settings.png`.
- SIP stays enabled. Use the Accessibility API and permissions. Don't move windows off-screen.
- Latency and visible jank aren't acceptable. Measure the latency of each action.
- Work in vertical slices. Each slice is real working software that can be tested.
- Each screen has exactly one workspace with its own container layout. The workspace state is stored with the display UUID as the key.

## Requirements

- `docs/PRD.md` is the spec. It describes the built behaviour and the behaviour planned for v1. Write each new decision in the PRD.
- `docs/requirements-as-written.md` contains the owner's requirements word for word.
- `GLOSSARY.md` defines the words for Tiller. Use these words in code, docs and UI text.
- `docs/adr/` contains the decisions that are hard to change, with the reasons.
- `docs/tickets/` contains one file for each feature, bug and research item. Link each ticket file to its PRD section. Don't copy the PRD section into the ticket file. `docs/tickets/README.md` describes the sections of a ticket file.
- `docs/tickets/tickets.jsonl` is the only list of status, order and dependencies. Update it when a ticket is added or its status changes. Don't write the status in a ticket file.
- `docs/references/requirements-infographic.png` and `docs/diagrams_drawing_tiller.tldraw` define the glossary, the container layouts and the carousel rules.

## Commands

- `scripts/test.sh`: unit tests. Xcode isn't used.
- `scripts/build.sh`: builds `build/Tiller.app`, `build/TillerTestWindows.app` and `build/tiller-proof`, signed with the Apple Development certificate. The signature is the same after each rebuild. The Accessibility permission is then kept.
- `build/tiller-proof --out Tests/Proof/<task>`: the end-to-end test. It manages only the test windows. `--apps <bundle id,...>` adds other apps. `--steps 2,leader,esc` runs other steps. `--leader hyper+l`, `--keys focusNextWindow=hyper+n` and `--global focusNextWindow=hyper+y` set the shortcuts for the run. Proof runs use their own defaults domain. Your saved settings and key bar position don't change. `--appearance light|dark` sets the system appearance for the run and restores it.
- Tiller writes its log to `~/Library/Logs/Tiller/tiller.jsonl`, one JSON object for each line, and to the unified log, subsystem `com.tiller.Tiller`. `scripts/check-log.py <file>` checks the lines. "Export Diagnostics…" in the menu bar menu writes the diagnostics zip to the Desktop. `--steps export-diagnostics:<dir>` writes it in a proof run.

## UI

- All UI follows the system light or dark appearance. A setting for light, dark or system comes later.
- Colors, materials, fonts and spacing are read from one theme type. Themes can then be added later.
- Key caps are flat: a rounded square with a solid fill, without a border, and the key in the system sans font. Letters are upper case.
- The leader key overlay has a key bar: draggable, at the bottom of the screen by default. The keys are in sections with a heading that says what they act on: screen, container, window and app (variant 1 in `docs/mockups/leader-mode-v4.html`). `?` opens the full key list with descriptions. The key bar and the key list read their keys from `KeyGuide` in `Sources/Tiller/Overlay/OverlayViews.swift`.

- In leader key mode, each container has a teal edge without a fill, and a solid chip on its top edge, over the border. The chip of the focused container is teal. The other chips are grey. The chip shows the container number, the carousel mode icon (⇆ or ⇅), the window count and the `v` key. A tooltip on the `v` key shows what the key does.
- `v` in leader key mode switches the carousel mode of the focused container between horizontal and vertical.
- In leader key mode, each window has a small translucent pill at its bottom-right corner: app icon, app name, Tiled or Floating, and the `p` and `f` keys. The pill of a window behind the focused window in a carousel shows only the app icon. The app icon is shown in the visible edge of the window.

- The settings window is variant 1 in `docs/mockups/settings.html`: a sidebar with colored icons, as in the CleanShot settings, and shortcut fields with a clear button, as in Rectangle Pro. The references are in `docs/references/`.
- The leader key, the shortcut to turn Tiller on and off, every key in leader key mode and the global shortcut of each action can be recorded in the settings. A segmented control on the Shortcuts page switches between "Leader key mode" and "Global" (variant 3 in `docs/mockups/settings-v2.html`). Each action in leader key mode has an "Exit after" checkbox (variant 1 in `docs/mockups/exit-leader-key-mode.html`). Each chord can use Hyper (⌃⌥⇧⌘ together). A key without modifiers in leader key mode also matches while modifiers are still held.

## Window behavior

- Window kinds are set by the window rule in `Sources/TillerCore/WindowTraits.swift`:
  - tiled: subrole `AXStandardWindow`, the size can be set, the parent is the app, not modal.
  - floating: other windows at window layer 0. Tiller doesn't move, resize or focus them.
  - ignored: minimized, not on screen, above window layer 0, or subrole `AXUnknown`.
- A new floating window doesn't cause a re-layout or a focus change.
- A new tiled window is put into the focused container, after the focused window, and becomes the focused window.
- A closed window is removed from its carousel at once. A minimized window and a window of a hidden app are also removed at once. When such a window is shown again, it goes back into the same container at the same ring position, as the focused window of that container. If that container doesn't exist, it goes into the focused container.
- Tiller's own frame and focus changes don't cause a second arrangement.
- When a floating window opens, focus stays on the focused tiled window. The floating windows of an app stay behind its focused window. `r` in leader key mode raises the floating windows of the focused app. The front floating window then gets focus.
- `f` in leader key mode floats the focused tiled window. The window is returned to its frame before Tiller first tiled it. `f` on that window again puts it back in the focused container.
- Peek (`p`) fills the workspace with the focused window. `p` again, or a focus change to another tiled window, returns it to its container.
