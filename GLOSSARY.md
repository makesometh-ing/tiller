# Tiller

Tiller is a tiling window manager for macOS. This glossary defines the words for the parts of the screen that are managed by Tiller. It also defines the words for controlling Tiller.

## Space on the screen

**Screen**:
A physical display connected to the Mac.
_Avoid_: Monitor, display

**Desktop**:
The area of a screen without the menu bar and without a visible Dock. A hidden menu bar or a hidden Dock is part of the desktop.
_Avoid_: Visible frame, usable area

**Workspace**:
The largest area of one screen for windows. Each screen has exactly one workspace, with its own container layout.
_Avoid_: Space, virtual desktop, macOS workspace

**Container**:
A division of a workspace that contains windows. Containers are never nested. A container can't extend outside its workspace.
_Avoid_: Pane, tile, zone, column

**Window**:
An app window, a dialog or a popup.
_Avoid_: View

## Layouts

**Container layout**:
A set of containers that divides a workspace, for example Full Screen or Left Two-Thirds.
_Avoid_: Layout preset, window layout

**Carousel**:
The arrangement of the windows in one container. The focused window is in front. The edges of the windows before and after it in the ring order are visible.
_Avoid_: Stack, accordion, window layout

**Carousel mode**:
The direction of a carousel: horizontal carousel or vertical carousel.
_Avoid_: Axis, orientation

**Focused window**:
The window in front of a carousel. It receives the key presses. It is called F in the carousel rules.
_Avoid_: Active window, current window

**Focused container**:
The container that contains the focused window.
_Avoid_: Active container, selected container

**Peek**:
A temporary state of one tiled window. In peek, the window fills the workspace. The window goes back to its container when peek ends.
_Avoid_: Zoom, full screen, maximize

## Spacing

**Workspace margin**:
The gap between the edge of the desktop and the edge of the workspace.
_Avoid_: Padding, outer gap

**Container margin**:
The gap between two containers. A container edge that touches the workspace edge doesn't have a container margin.
_Avoid_: Gutter, inner gap

**Carousel spacing**:
The part of a container that isn't covered by the focused window. The edges of the other windows in the carousel are visible in this part.
_Avoid_: Peek size, offset

## Window kinds

**Tiled window**:
A window in a container. Tiller sets its position and size.
_Avoid_: Managed window

**Floating window**:
A window outside every container. Tiller doesn't move it, resize it or give it focus. A floating window can extend outside the workspace.
_Avoid_: Unmanaged window, popped-out window

**Ignored window**:
A window that isn't tracked, for example a minimized window or a menu.
_Avoid_: Hidden window, excluded window

**Child window**:
A window that is opened from the main window of an app, for example a settings window, a sheet or a single chat window. A child window is a floating window.
_Avoid_: Subwindow, popover

## Keys

**Leader key**:
The key chord that starts leader key mode.
_Avoid_: Prefix key, activation key, hotkey

**Leader key mode**:
The state after the leader key is pressed. The next key press does an action. The focused app doesn't receive the key press.
_Avoid_: Command mode, Tiller mode

**Layer**:
One set of action keys in leader key mode. Tiller has one layer.
_Avoid_: Mode, page

**Action**:
One operation on a workspace, a container or a window, for example "Focus next window".
_Avoid_: Command

**Action key**:
The key in leader key mode that does an action.
_Avoid_: Binding, mapping

**Global shortcut**:
A key chord that does an action without the leader key.
_Avoid_: Direct shortcut, hotkey

**Hyper**:
The four modifier keys Control, Option, Shift and Command, pressed together.
_Avoid_: Meh, super

## Leader key overlay

**Leader key overlay**:
All the labels that are shown on the screen in leader key mode.
_Avoid_: HUD

**Container chip**:
The label on the top edge of a container. It shows the carousel mode and the number of windows.
_Avoid_: Pip, container pill, badge

**Window pill**:
The label at the bottom-right corner of a window. It shows the app and the window kind.
_Avoid_: Status line, window badge

**Key bar**:
The bar with the action keys of leader key mode. The action keys are grouped by what they act on.
_Avoid_: Cheat sheet, shortcut bar

**Key list**:
The list of all action keys with a description of each action.
_Avoid_: Help screen, cheat sheet

## Work

**Proof bundle**:
The screenshots, screen recordings, logs and test output for a task. They show that the task works. A task is done only with a proof bundle.
_Avoid_: Evidence, artifacts
