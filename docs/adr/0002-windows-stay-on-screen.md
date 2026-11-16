# Windows aren't moved off-screen

Tiller doesn't hide windows by moving them outside the screen. A window that isn't in front of its carousel stays in the container, behind the focused window. The owner rejected off-screen windows because "it causes jank".

## Considered options

- AeroSpace has more than one workspace on a screen. It moves the windows of the hidden workspaces to a position outside the screen. This option was rejected. Tiller has one workspace for each screen.
