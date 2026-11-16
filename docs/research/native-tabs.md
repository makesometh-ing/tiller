# Native tabs in other tiling window managers

## Test on the owner's Mac

A Finder window with two native tabs was tested:

- The window server has two windows at the same frame, one for each tab.
- Only the window of the selected tab is on the screen.
- The Accessibility API returns only the window of the selected tab.
- After a tab switch, the visible window has a different window id. The other window id still exists, off the screen.

## Other tiling window managers

| App | Status | Source |
|---|---|---|
| AeroSpace | Issue #68 is open since December 2023. Each tab is tiled as a separate window. The maintainer recommends the AeroSpace accordion layout in place of native tabs. Pull request #2027 detects background tabs with the CoreGraphics window list. It was closed without a merge. | [Issue #68](https://github.com/nikitabobko/AeroSpace/issues/68), [pull request #2027](https://github.com/nikitabobko/AeroSpace/pull/2027) |
| yabai | Issue #68 "Handle native tabs properly" is open since June 2019. The README lists Terminal and Finder as apps that don't behave correctly when tabs are created. Apple answered a bug report with "Works as expected". | [yabai wiki](https://github.com/koekeishiya/yabai/wiki) |
| Amethyst | Issue #633 reports a blank space in windows with native tabs. Issue #1613 reports that Terminal tabs break layouts. | [Issue #633](https://github.com/ianyh/Amethyst/issues/633) |
| Ghostty | The Ghostty docs say that its native tabs can be tiled as separate windows in yabai and AeroSpace. | [Ghostty docs](https://ghostty.org/docs/help/macos-tiling-wms) |
