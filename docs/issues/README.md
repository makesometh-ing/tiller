# Tiller v1 issues

Each file is one issue for v1. The text of each file can be copied into a GitHub issue. The request, the decisions and the current behaviour are in the linked work file. An issue is closed only with a proof bundle in `Tests/Proof/<issue id>/`.

[tickets.jsonl](tickets.jsonl) lists each done feature, research item and bug, then each open issue in build order. Each open issue has these fields:

- `order`: the build order. An issue comes after each issue in `depends_on`.
- `priority`: `P1` is needed for daily use on your Mac. `P2` is a setting or a second screen. `P3` is needed for a public release. `P4` is after v1.
- `depends_on`: the issues to build first.
- `blocked_by`: the approvals and answers needed from you.
- `status`: `todo`, or `blocked` when an answer from you is needed before the work starts.

## v1

| Issue | Title | Work file | Blocked by |
|---|---|---|---|
| [V1-01](V1-01-new-and-closed-windows.md) | Put new windows in a container, and remove closed windows | [F13](../work/F13-new-windows.md) | |
| [V1-02](V1-02-peek.md) | Peek: the P key | [F12](../work/F12-peek.md) | |
| [V1-03](V1-03-latency.md) | Make focus steps and layout changes faster | [F24](../work/F24-latency.md) | V1-01 (Put new windows in a container, and remove closed windows), for the cached window list |
| [V1-04](V1-04-workspace-state.md) | Keep the carousel mode and restore workspaces after a launch | [F28](../work/F28-workspace-state.md) | |
| [V1-05](V1-05-multiple-screens.md) | Multiple screens: connect, disconnect and move windows | [F27](../work/F27-multiple-screens.md) | |
| [V1-06](V1-06-leader-key-mode-edge-cases.md) | End leader key mode on a timeout, an app switch, a click and a screen lock | [F29](../work/F29-leader-key-mode-edge-cases.md) | |
| [V1-07](V1-07-global-shortcuts.md) | Global shortcuts | [F20](../work/F20-global-shortcuts.md) |
| [V1-08](V1-08-open-at-login.md) | Open at login | [F21](../work/F21-open-at-login.md) | |
| [V1-09](V1-09-enable-disable.md) | Enable and disable Tiller from the menu bar | [F22](../work/F22-enable-disable.md) | |
| [V1-10](V1-10-debug-log.md) | Debug log and Export Diagnostics | [F23](../work/F23-debug-log.md) | |
| [V1-11](V1-11-keyboard-layouts.md) | Key names from the current keyboard layout | [F31](../work/F31-keyboard-layouts.md) | |
| [V1-12](V1-12-icons.md) | Light app icon and the menu bar icon | [F17](../work/F17-icons.md) | Your answer to the question: can `scripts/build.sh` use `actool`, the Xcode tool that compiles icons into an asset catalog? |
| [V1-13](V1-13-proof-key-bar-position.md) | Save the key bar position of a proof run in the proof defaults | [B11](../work/B11-key-bar-position-saved-in-proof-runs.md) | |
| [V1-14](V1-14-accessibility-permission-window.md) | Accessibility permission window at the first launch | | |
| [V1-15](V1-15-build-from-source.md) | Build from source on any Mac | | |
| [V1-16](V1-16-github-release.md) | Signed and notarized release on GitHub Releases | | Apple Developer Program membership, the GitHub repository, and V1-15 (Build from source on any Mac) |
| [V1-17](V1-17-spacing-settings.md) | Spacing settings | [F30](../work/F30-spacing-settings.md) | |
| [V1-18](V1-18-menu-bar-and-dock.md) | Show Tiller in the menu bar, the Dock or both | [F32](../work/F32-menu-bar-and-dock.md) | |
| [V1-19](V1-19-move-window-between-containers.md) | Move a window to another container | [F33](../work/F33-move-window-between-containers.md) | |
| [V1-20](V1-20-native-tabs.md) | One tile for each native tab group | [F34](../work/F34-native-tabs.md) | |

## After v1

The requirements mark these items as "nice to have", "later" or "in the future".

| Title | Work file |
|---|---|
| Left Busy, Right Busy, Horizontal Split and named custom layouts | [F04](../work/F04-nice-to-have-layouts.md) |
| More than one leader key layer | [F26](../work/F26-multiple-layers.md) |
| Command to copy a container layout to another screen | [F27](../work/F27-multiple-screens.md) |
| Appearance setting: light, dark or system | [F16](../work/F16-theme-and-key-caps.md) |
| Themes | [F16](../work/F16-theme-and-key-caps.md) |
