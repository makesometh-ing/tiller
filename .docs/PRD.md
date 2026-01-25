# Tiller Window Manager: Functional & UX Specification

## macOS Menu Bar Interface

### Menu Bar App Constraints

* **Menu Bar Only:**

  * Tiller operates exclusively as a macOS menu bar application.

  * No Dock icon is shown unless required by the operating system for technical reasons.

### Popup UI Structure

* **Accessing the Popup:**

  * Clicking the menu bar icon opens the Tiller popup UI.

* **Monitor Representation:**

  * Each connected monitor appears as a separate top-level section in the popup, visually separated by dividers.

  * Monitors are listed as `<index, 1-based>-<monitor name>` (example: `1-MacBook Pro`).

* **Layouts per Monitor:**

  * Each monitor section lists its available layouts formatted as `<index, 1-based>-<layout name>`, with the currently active layout visually indicated.

* **Additional Items:**

  * A ‘Quit’ action is always presented as the final entry at the bottom of the menu.

* **Monitor Navigation Row:**

  * The menu’s persistent header displays all monitor numbers (e.g., `1 – 2 – 3`), highlighting the currently active monitor with a square outline.

* **Monitor Focus:**

  * Focusing a window on a monitor updates Tiller’s active monitor indicator.

## Monitor and Layout Switching Logic

### Monitor Focus Handling

* **Active Monitor Tracking:**

  * The UI and view always reflect the current active monitor.

* **Keyboard Monitor Switching:**

  * Change the active monitor using the leader shortcut: Option+Space → ‘m’ → .

* **Menu Mouse Interaction:**

  * Clicking a monitor in the popup sets it to active.

* **Window Focus-Driven Selection:**

  * Focusing any window on a monitor makes that monitor active in Tiller.

### Layout Application Rules

* **Per-Monitor Changes:**

  * Layout changes are always scoped to the currently active monitor.

* **Layout Shortcut Application:**

  * Changing layout via leader shortcut and digit (`1`–`7`) applies to the active monitor only.

## Functional Requirements

### System Integrity and Permissions

SIP and Native Permissions

* Tiller must never require disabling or weakening macOS System Integrity Protection (SIP).

* All window management and accessibility features employ only supported macOS APIs for permissions.

### Window Tiling Engine

Animated Transitions

* All window movements and layout changes animate with:

  * Native macOS-style animation

  * 200ms duration per transition

  * Hardware acceleration and 60fps target; no dropped frames

Per-Monitor State

* Independent tiling and state for each monitor.

* Layouts, containers, and window positioning for each monitor persist across disconnects and reconnects.

* On first launch or monitor add, windows are tiled into a single fullscreen ‘monocle’ container.

Strict Layout and Containment

* Organizing hierarchy per monitor: `Layout` > `Container(s)` > `Window(s)`

* Exactly seven distinct layouts:

  1. Full screen (monocle)

  2. Split half-and-half (vertical)

  3. Half left; two right quarters

  4. Half right; two left quarters

  5. Four equal quarters

  6. One third left, two thirds right

  7. Two thirds left, one third right

### Container Display and Focus Mechanics

Accordion Visual Logic

* **Critical Rule:** All windows remain ON screen at all times. No windows are ever positioned off-screen.

* **Window Positioning (Horizontal Accordion):**

  * **1 window:** Fills container completely. Position at container origin, size = container size.

  * **2 windows:**
    * Window width = container.width - accordionOffset
    * Focused window: left-aligned at container origin (minX)
    * Other window: same size, positioned at (minX + accordionOffset)
    * Result: accordionOffset visible on RIGHT of focused window showing the other window behind

  * **3+ windows:**
    * Window width = container.width - (2 * accordionOffset)
    * Previous window: positioned at container origin (minX)
    * Focused window: centered at (minX + accordionOffset)
    * Next window: positioned at (minX + 2 * accordionOffset)
    * Other windows: same position/size as focused (hidden behind it)
    * Result: accordionOffset visible on LEFT (previous), accordionOffset visible on RIGHT (next)

* **Z-Order (front to back):**
  1. Focused window
  2. Next window
  3. Previous window
  4. Other windows (behind focused)

* **Configurable Accordion Offset:**

  * Offset range: 4px–24px (user-adjustable).

  * If space is limited, offset auto-reduces to 4px minimum.

Window Cycling and Ring Buffer

* Focus cycling (shift+comma `<`, shift+period `>`) operates as a ring buffer per container.

* Cycling updates focus, animates the accordion, and visually brings the new focused window to the front.

* Moving a window between containers visually highlights valid drop zones with a subtle blue outline.

* Any focus, move, or cycle action brings window to front and shows its focus state.

* Focus changes by external means (e.g., Alt+Tab, Dock click) update container order and focus instantly.

Window State Persistence

* Complete container/window state for each monitor is saved and auto-restored across relaunch and monitor hotplug.

### Management of Floating Windows

Automated Detection

* Tiller automatically marks windows as ‘floating’ if they are:

  * Dialogs

  * Modals

  * Palettes/tool windows (using macOS Accessibility APIs)

* Floating windows are visually above tiled containers and excluded from tiling actions.

User Control of Floating Windows

* Users may add applications to a global float/ignore list via menu bar GUI or a leader-key shortcut.

* The list is always visible and editable in the configuration UI.

## Keyboard and Shortcut Infrastructure

### Leader Key Standards

* **Definition:**

  * The leader key is the root trigger for all shortcuts; default is Option+Space.

* **Assignment Constraints:**

  * Must consist of both a modifier (Cmd/Ctrl/Option/Shift or combination) and a standard key (A–Z, 0–9, F1–F19).

  * Assignment and changes are made via the GUI, which validates for compliance and refutes improper assignments with instant user feedback.

* **Overlay Behavior:**

  * Pressing the leader key shows a full command palette with commands grouped and visually structured.

### Shortcut Assignment System

* **Shortcut Types:**

  * Hierarchical leader sequences (e.g., leader+‘m’+\[monitor\]) and direct hotkeys (non-leader mapping) are both supported.

* **Leader Subgroups:**

  * Actions are organized into groups and subgroups (e.g., movement, window, layouts) inspired by nvim’s key mapping style.

* **Editable Actions:**

  * Users control, per action, if it stays in leader mode, returns to a parent group, or exits leader mode post-execution.

  * Defaults: h/j/k/l and Shift variants stay in leader mode.

  * Leader or Escape always exits leader mode and overlay state.

* **Conflict Prevention:**

  * All mappings are validated for uniqueness on assignment; any conflicts immediately prompt error/warning in the config UI.

### Default Keyboard Mappings

* **Window Move (container):** h, j, k, l (remains in leader mode)

* **Focus Move (container):** Shift+h, Shift+j, Shift+k, Shift+l (remains in leader mode)

* **Cycle Container Windows:** < (Shift+comma), > (Shift+period) (remains in leader mode)

* **Switch Layout:** 1–7

* **Change Monitor:** leader + m + \[monitor number\]

* **Exit Leader:** leader (again) or esc

* **Editing:**

  * All defaults editable in the config UI, shown with macOS-style shortcut picker using system conventions and accessibility standards.

### Command Palette Overlay

* Invoking leader opens a keyboard-navigable, accessible overlay showing all actions, keybindings, groups, and post-action behavior.

* Overlay design assures WCAG AA accessibility with high contrast.

## GUI Configuration Editor

### Menu Bar Integration

* Accessible only via menu bar icon (unless technical needs dictate Dock icon).

* Opening displays a three-tab UI: General, Leader Key/Shortcuts, About.

### Live Configuration Editing

* All configuration changes are saved instantly and trigger a live reload—no app restart.

* Upon successful save, users receive immediate visual confirmation (checkmark/banner).

* Validation errors are shown inline; invalid changes are discarded and do not alter live state.

### Config File Management

* **Location:** `~/.config/tiller`

* **Format:** User-selectable, JSON or YAML

* **Supported Settings:**

  * Margin (container outer gap): 0–20px (default 8px)

  * Padding (gap between containers): 0–20px (default 8px)

  * Accordion offset: 4–24px (default 8px; forcibly 4px if container size insufficient)

  * Leader and shortcut bindings

  * Floating application ignore list

## Configuration Schema and Validation

### Strict Schema Enforcement

* All config files (JSON/YAML) are schema-validated on load and save.

* Public schema specification is provided for validation.

* If config is invalid/malformed, only affected features are disabled and a banner/popup notifies the user of fallbacks. Application remains stable for unaffected features.

## Animations, Visual Feedback, and Responsiveness

### Animated Behavior

* All window moves, resizes, layout changes are animated with a 200ms default duration.

* Synchronization: All related containers and windows animate together (no overlaps or disjointed actions).

### Visual Communication

* All errors, configuration saves, and command palette commands provide prompt, visible feedback (banners, overlays, color cues).

* Design upholds WCAG AA contrast requirements throughout overlays, focus rings, and command palettes.

### Responsive Design

* Interface and visuals scale smoothly for retina and standard displays.

### Error Handling

* **Config File Issues:**

  * Malformed or invalid configs are non-fatal. UI displays error banners, only the valid portions continue running.

* **Monitor Attach/Detach:**

  * Layouts and window positions remain stable and are restored correctly on monitor events.

* **Shortcut Edge Cases:**

  * If the leader key is reserved or overridden by macOS, Tiller disables only those shortcuts and signals in the config UI.

## User Experience Flows

### Initial App Launch and Permissions

1. On install/first launch:

* Only menu bar icon is visible.

* Standard macOS accessibility permission requests are made.

* All windows on the main monitor are immediately tiled in the fullscreen (monocle) layout.

1. Accessing Configuration:

* Opening config editor presents an initial welcome/permission explanation once.

* Users can access General, Shortcuts, and About tabs.

### Day-to-Day Window Management

1. Windows tile automatically to the active layout per monitor.

2. Pressing the leader key summons the command overlay, fully navigable without a mouse.

3. Performing actions (layout swap, focus change, cycle) animates window/container movements instantly.

4. Config editing in the GUI updates tiling live; visual error prevention for invalid entries.

5. Window cycling and focus interactivity use the accordion and animate as expected.

### Advanced Scenarios and Edge Cases

* **Monitor Attach/Detach:**

  * Instantly restores layouts, containers, and window assignments.

* **Floating/Modal Exclusion:**

  * Such windows are never tiled unless deliberately removed from float/ignore list.

* **Hotkey Conflicts:**

  * Potential conflicts generate warning indicators in the GUI and are never silently overridden.

## Feature Exclusions

* No virtual desktop (workspace) switching.

* No plugin or scripting capabilities.

* macOS-only support for MVP; no Windows or Linux support.

## Configuration Option Table

## Performance and Scalability

* Supports simultaneous management of up to 6 displays and 40+ windows.

* Animation performance target: 60fps on modern MacBook models.

## macOS Integration Details

* Uses macOS Accessibility APIs for all window management.

* Leverages menu bar API for config editor and app access.

* No networking; configuration strictly local.

---

**End of Tiller Window Manager: Functional & UX Specification**
