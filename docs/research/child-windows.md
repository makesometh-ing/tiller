# How other tiling window managers handle child windows, dialogs, floating windows and workspace fill

Sources were read at these commits:
- AeroSpace: https://github.com/nikitabobko/AeroSpace/tree/6ed6af6
- yabai: https://github.com/koekeishiya/yabai/tree/b2dc8b4
- i3: https://github.com/i3/i3/tree/8a97b0f
- Glide: https://github.com/glide-wm/glide/tree/546607f

## Which windows are tiled

| Tool | Tiled | Floated | Ignored |
|---|---|---|---|
| AeroSpace | Other windows | Subrole isn't `AXStandardWindow`, or the fullscreen button is missing or disabled. 11 apps are excepted. (`Sources/AppBundle/model/AxUiElementWindowType.swift`) | Popups: non-normal window level for some apps, accessory apps without a close button, and other app-specific cases. |
| yabai | Root window, role `AXWindow`, subrole `AXStandardWindow`, normal window level, movable, not sticky, minimized or hidden. (`src/window_manager.c`) | Child windows. Windows that can't be resized and are 500 points or less in width or height. (`src/window.c`) | `AXUnknown` windows. `AXPopover` windows. |
| i3 | Other windows | Dialog, utility, toolbar, notification and splash types. Modal windows. Fixed-size windows. Windows with `transient_for` or a leader window. (`src/manage.c`) | Dock windows aren't floated. |
| Glide | Role `AXWindow` with subrole `AXStandardWindow` and a settable size | Other subroles. Size not settable. System Preferences. (`src/actor/layout.rs`) | Window server layer isn't 0. Firefox Picture-in-Picture. |

## User control

- AeroSpace: `on-window-detected` with `layout floating`, and `layout floating tiling` to toggle.
- yabai: `rule --add app=... manage=off`, and `window --toggle float`.
- i3: `for_window [criteria] floating enable`, and `floating toggle`.
- Glide: `[[window_rules]]` with `float = true|false`, and `toggle_window_floating`.

## Fill the workspace without native fullscreen

- AeroSpace: `fullscreen` toggles. Outer gaps are kept unless `--no-outer-gaps` is passed. The window leaves fullscreen when focus moves to another tiled window. (`docs/aerospace-fullscreen.adoc`)
- yabai: `--toggle zoom-fullscreen` and `--toggle zoom-parent`, in BSP layout only.
- i3: `fullscreen toggle` uses the whole output.
- Glide: `toggle_fullscreen` keeps the outer gap.

## Floating windows above tiled windows

- yabai puts tiled windows in a lower layer through its scripting addition. `--sub-layer`, `--raise` and `--lower` need SIP partly disabled. (`doc/yabai.asciidoc`)
- Glide documents that floating windows can't be kept on top without disabling security protection. `toggle_focus_floating` raises all floating windows. (`glide.default.toml`)
- i3 (Linux) keeps floating windows on top.

## Child window problems and fixes

- yabai CHANGELOG: #2044 separates root windows from child windows. #2036 changes window detection. #162 ignores `AXPopover` windows.
- AeroSpace: #201 (Reminders popup focus), #1220 (Calendar completion popup moves focus, open), #1097 (focus race when a window closes, open), #2170 (Wispr Flow popup detected as a window), #776 (Emacs child frames).
- i3: `popup_during_fullscreen`, `focus_on_window_activation` and `no_focus` control focus changes from new windows.
- Glide CHANGELOG #231: focus and stacking when apps raise windows.
