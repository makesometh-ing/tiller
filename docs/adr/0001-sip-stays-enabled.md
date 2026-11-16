# SIP stays enabled

Tiller controls windows only with the Accessibility API, a `CGEventTap` and the private function `_AXUIElementGetWindow`. All of these work with SIP enabled. The owner's requirement is "permissions are fine - disabling security is not".

## Considered options

- The yabai scripting addition. It is loaded into the Dock process. It can set the window order of other apps and move windows between Spaces. It works only with SIP partly disabled. This option was rejected.

## Consequences

- Tiller can't set the order of windows behind the front window. In a carousel, only the focused window is raised. The order of the other windows is set by macOS.
- A focus on a window brings all windows of its app in front of other apps.
