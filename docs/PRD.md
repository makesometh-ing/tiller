# Tiller Window Manager: Functional & UX Specification

## macOS Menu Bar Interface

### Menu Bar App Constraints

* **Menu Bar Only:**

  * Tiller operates exclusively as a macOS menu bar application.

  * No Dock icon is shown unless required by the operating system for technical reasons.

### Menubar UI Structure

* **Accessing the menubar:**

  * Clicking the menu bar icon opens the Tiller menubar app UI.

* **Top menu item is "enable/disable" tiller tiling**

  * When enabled: displays "✓ Tiller is tiling your windows..." with a checkmark

  * When disabled: displays "✗ Tiller is sleeping..." with a cross

* **Monitor layout selection section:**

  * Each connected monitor appears as a separate group in the monitor layour section with a label. Each group is visually separated by dividers.

  * Monitors are listed as `[<index, 1-based>] <monitor name>` (example: `[1] MacBook Pro`).

  * **Layouts per Monitor:**

    * Each monitor group lists its available layouts formatted as `<index, 1-based>-<layout name>`, with the currently active layout visually indicated.

* **Additional Items:**

  * A settings action for opening the setting menu

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

  * Changing layout via leader shortcut and digit (`1`–`9`) applies to the active monitor only.

### Window-to-Container Assignment on Layout Switch

When switching between built-in layouts, windows must be distributed across the new layout's container set using the following algorithm:

1. **Per-layout memory (primary):** Tiller maintains a per-monitor, per-layout memory of which windows were assigned to which containers. When switching to a layout that has been previously used on that monitor, windows are restored to their remembered container positions. Windows that no longer exist are silently ignored; their remembered slots are left empty.

2. **Center-coordinate fallback (secondary):** If no per-layout memory exists for the target layout (first time switching to it), each window is assigned to whichever container in the new layout geometrically contains the window's current center coordinates.

3. **Unmatched windows:** If a window's center coordinates do not fall within any container in the new layout (edge case), assign it to the container nearest to its center coordinates.

4. **Empty containers are acceptable.** If a layout switch results in one or more containers with no windows, they remain empty.

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

* On first launch, windows on the main monitor are tiled into the monocle layout — layout 1.

* When a new/unrecognized monitor is connected, it defaults to layout 1 (monocle). Windows already present on that monitor are tiled into its single container.

* Windows on secondary monitors are not affected by layout changes on other monitors. Each monitor is an independent tiling space.

Strict Layout and Containment

* Organizing hierarchy per monitor: `Layout` > `Container(s)` > `Window(s)`

* Exactly nine distinct layouts:

  1. Monocle (single full-screen container)

  2. Split half-and-half (vertical)

  3. Half left; two right quarters

  4. Half right; two left quarters

  5. One third left, two thirds right

  6. Two thirds left, one third right

  7. Two fifths left, three fifths right

  8. Three fifths left, two fifths right

  9. One fifth left, three fifths center, one fifth right

### Dynamic Container Resizing

Users can resize containers dynamically beyond the nine built-in layouts using dedicated keybindings.

**Default Keybindings (leader mode):**

* `-` : shrink container horizontally
* `=` : grow container horizontally
* `_` (Shift + `-`) : shrink container vertically
* `+` (Shift + `=`) : grow container vertically

These keybindings remain in leader mode after execution.

**Resize Algorithm — Horizontal (vertical behaves identically on the Y axis):**

* **Edge-touching container** (left or right side flush against the screen edge):

  * Grow: expand width away from the touching edge. E.g., a container flush-left grows rightward.

  * Shrink: contract width toward the touching edge (inverse of grow).

  * Adjacent containers shrink or grow accordingly to fill the remaining space.

* **Center container** (neither left nor right side touches a screen edge):

  * Grow: expand width equally from the container's current center.

  * Shrink: contract width equally toward the container's current center.

  * Adjacent containers on both sides adjust accordingly.

* **Vertical resize** follows the same rules on the Y axis: top/bottom-touching containers grow/shrink away from or toward their touching edge; center containers grow/shrink from center.

**Constraints:**

* Minimum container size is enforced. If a shrink operation would push any container below the minimum, the operation is clamped (no further shrink occurs).

* If a resize causes a non-resizable window to no longer fit its container, the existing non-resizable window handling chain applies (move to next largest container → auto-float).

* The resize increment (default 5%, configurable as percentage or pixels) is applied per keypress.

**Dynamic Layout State:**

* Any manual container resize instantly invalidates the current built-in layout selection.

* The menu bar UI shows no layout selected and displays a "D" indicator to denote a dynamic layout.

* The resize increment value and unit selector (percent/pixels) are visible in the General settings tab of the config UI.

### Container Display and Focus Mechanics

Accordion Visual Logic

Accordion arrangement is defined with dynamic precision, but precision nonetheless. Every screen size is different, so implementation should be flexible to support any and all resolutions. However, we will use a set of *reference values* in order to define requirements:

* 1920px (horizontal) x 1080px (vertical) container

* 8px margin

* 32px accordion offset

* The coordinate system placed (0, 0) at the top left, with X increasing right, Y increasing downward. Example below is for horizontal accordion mode; for vertical, swap axes accordingly

* In “horizontal” accordion mode

**For a single window**

* Window is rendered at (8, 8)

* Window size is 1064 x 1904

**For two windows**

* **Focused window:**

  * Rendered at (8, 8)

  * Size: 1064 x 1872

* **Unfocused window:**

  * Rendered at (40, 8)

  * Size: 1064 x 1872

  * Displayed *behind* the focused window

**For three or more windows**

* **Focused window:**

  * Rendered at (40, 8)

  * Size: 1064 x 1840

* **Next window in the ring buffer:**

  * Rendered at (72, 8)

  * Size: 1064 x 1840

  * Displayed behind the focused window

* **Previous (last) window in the ring buffer:**

  * Rendered at (8, 8)

  * Size: 1064 x 1840

  * Displayed behind the "next" window

* **All other windows (4th, 5th, etc.):**

  * Rendered at (40, 8)

  * Size: 1064 x 1840

  * Appear behind the three visible windows, not visible unless cycled into view

Rules

* Windows MUST NEVER be positioned off-screen.

**Vertical Accordion Mode**

Using the same reference values (1920px x 1080px container, 8px margin, 32px accordion offset), the vertical accordion positions are:

| Scenario | Focused Position (x, y) | Focused Size | Other Positions (x, y) | Other Size | Notes |
|---|---|---|---|---|---|
| Single window | (8, 8) | 1064 x 1904 | — | — | -- |
| Two windows | (8, 8) | 1032 x 1904 | (8, 40) (unfocused, behind) | 1032 x 1904 | -- |
| Three+ windows | (8, 40) | 1000 x 1904 | (8, 72) (next), (8, 8) (last), All others: (8, 40) | 1000 x 1904 | Only first three visible in stack |

**Accordion Direction Per Container:**

* Every container defaults to horizontal accordion mode.

* There is a keybinding action to toggle a container's accordion direction between horizontal and vertical. This toggle applies to the currently focused container.

* Accordion direction is remembered **per container, per built-in layout**. Example: layout 1 set to vertical accordion; switch to layout 2 where left container is set to vertical and right container remains horizontal; switching back to layout 1 restores vertical; switching back to layout 2 restores left=vertical, right=horizontal.

* Dynamic layouts do not persist accordion direction. When switching from a dynamic layout to a built-in layout, the dynamic layout's accordion settings are discarded.

* The accordion offset is user-configurable between 4-64px; this is auto-reduced to 8px if available space is insufficient.

* Only three windows are visually stacked at once: focused, next, and last windows in the buffer. All others are hidden behind at the (40, 8) position (or (8, 40) for vertical).

### Window Cycling and Ring Buffer

* Focus cycling (shift+comma `<`, shift+period `>`) operates as a ring buffer per container.

* Cycling updates focus, animates the accordion, and visually brings the new focused window to the front.

* Moving a window between containers visually highlights valid drop zones with a subtle blue outline.

* Any focus, move, or cycle action brings window to front and shows its focus state.

* Focus changes by external means (e.g., Alt+Tab, Dock click) update container order and focus instantly.

### Peek Mode

Peek mode temporarily expands a window from its container to a prominent centered position on screen. It is only relevant for layouts other than monocle (layout 1); invoking peek in monocle has no effect.

**Activation:**

* Default keybinding: `f` (leader mode)
* The focused window animates out from its container to the center of the screen.

**Peek Window Sizing:**

* **Standard aspect ratios (16:10, 16:9):** The peeked window fills the full screen size minus the margin on all sides.

* **Ultrawide monitors:** The peeked window is rendered as a 16:10 aspect ratio window, horizontally centered on the monitor. Vertical size equals the monitor's vertical resolution minus the margin and dock space. Horizontal size is derived from the 16:10 ratio.

**Visual State During Peek:**

* The underlying containers and their windows remain visible but are blurred behind the peeked window.

**Dismissal — any of the following exits peek mode:**

* Pressing `f` again (toggles peek off, window animates back to its container).
* Any focus change to another window (Alt+Tab, Dock click, mouse click on another window).
* Any other Tiller action (layout switch, container move, etc.).

**Interaction Rules:**

* The peeked window retains its container assignment — peek is a temporary visual state only.
* Window cycling (`<`/`>`) while in peek mode dismisses peek first, then cycles normally on the next keypress.
* Peek mode is not persisted. It is always dismissed on layout switch, monitor change, or app relaunch.

Automatic Tiling and Resizing Behavior

* Every non-floating window in a container is always automatically resized and positioned according to the above rules based on its position in the ring/accordion.

* User direct manipulation of size is not supported; all window geometry is managed by Tiller.

* When an app is opened, it is assigned to the same container as the currently focused window on that monitor.

* **Non-Resizable Window Handling (strict precedence chain):**

  1. When a non-resizable window is opened or spawned, assign it to the same container as its parent window (if identifiable), or the same container as the currently focused window.

  2. If the window fits within its assigned container: center it within the container (not top-left aligned).

  3. If the window is too large for its assigned container: immediately move it to the next largest container in the current layout and center it there.

  4. If the window is too large for all containers on the monitor: auto-float the window. When focused, center it on screen. No notification is shown for auto-float.

  5. Spawned windows (e.g., WeChat chat windows) must always be assigned to the same container as their parent window, following the same size-handling chain above.

  6. Non-resizable windows participate in the container's ring buffer and can be cycled to via keyboard shortcuts (`<`/`>`). When a non-resizable window is focused:

     * It appears centered on top of the accordion (overlay behavior).

     * The accordion underneath freezes — positions stay based on the last focused resizable window.

     * Cycling past the non-resizable window to a resizable window restores normal accordion behavior.

* Windows are never positioned beyond the visible area of the container.

Window Lifecycle Rules

* **Window close / app quit:** If the last window in a container closes, the container remains empty. No rebalancing or redistribution occurs. This is equivalent to the window being hidden.

* **Window hidden (app hidden via Cmd+H or minimized):** The window is removed from its container's accordion. The container may become empty; this is acceptable.

* **Window reappears (app unhidden / window unminimized):** The window returns to its last-known container. If that container no longer exists (e.g., layout changed), the center-coordinate fallback from the layout switch algorithm applies.

* **New window created:** Assigned to the same container as the currently focused window on that monitor (existing rule).

Window State Persistence

* State is persisted **per monitor**, identified by a unique monitor ID (not just display name). Two monitors of the same model are tracked independently.

* Per monitor, the following is persisted:

  * The last active built-in layout.

  * Per-layout memory: which windows were assigned to which containers in each built-in layout that has been used on that monitor.

  * Per-container accordion direction (horizontal or vertical) for each built-in layout.

  * The focused window per container.

* On app relaunch or monitor reconnect, the monitor restores to its last known **built-in** layout with its remembered window→container assignments.

* If the monitor was in a dynamic layout state when disconnected or the app quit, it falls back to the last selected built-in layout on restore. Dynamic layout container sizes are not persisted.

### Management of Floating and Ignored Windows

Auto-Ignored Windows

The following window types are completely invisible to Tiller — never tiled, never floated, never tracked. Tiller does not interact with them in any way:

* Menu bar popovers (e.g., 1Password dropdown, Bartender, system menu extras)
* System UI elements (Spotlight, Notification Center, Control Center)
* Transient/ephemeral windows (tooltips, autocomplete dropdowns, hover popups)

Detection uses macOS Accessibility APIs (window role, subrole, and level attributes). These windows are excluded unconditionally and cannot be opted into tiling.

Auto-Floated Windows

* Tiller automatically marks windows as 'floating' if they are:

  * Dialogs
  * Modals
  * Palettes/tool windows

* Floating windows are visually above tiled containers and excluded from tiling actions.

* Auto-floated windows are distinct from auto-ignored windows: floated windows are still tracked by Tiller (they appear above containers and respond to focus), while ignored windows are invisible to Tiller entirely.

User Control of Floating Windows

* Users may add applications to a global float list via menu bar GUI or a leader-key shortcut.

* The list is always visible and editable in the configuration UI.

* A "completely ignore" list allows excluding apps from Tiller control entirely (not tiled or floated) — removal is only possible from the configuration UI. These apps cannot be "unfloated".

## Keyboard and Shortcut Infrastructure

### Leader Key Standards

* **Definition:**

  * The leader key is the root trigger for all shortcuts; default is Option+Space.

* **Assignment Constraints:**

  * Must consist of both a modifier (Cmd/Ctrl/Option/Shift or combination) and a standard key (A–Z, 0–9, F1–F19).

  * Assignment and changes are made via the GUI, which validates for compliance and refutes improper assignments with instant user feedback.

* **Leader Timeout:**

  * Leader mode auto-dismisses after a configurable timeout. Default: 5 seconds. Allowed range: 0–30 seconds, where 0 means infinite (no timeout).

  * The timeout resets on each keypress within the leader sequence (not a hard timer from initial activation).

  * Configurable in the General settings tab.

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

* **Container Resize:** `-` (shrink horizontal), `=` (grow horizontal), `_` (shrink vertical), `+` (grow vertical) (remains in leader mode)

* **Toggle Accordion Direction:** `a` (toggles focused container between horizontal/vertical accordion) (remains in leader mode)

* **Peek Mode:** `f` (toggles peek on focused window; exits leader mode)

* **Switch Layout:** 1–9

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

* Opening displays a three-tab UI: **General**, **Key Bindings**, **About**.

### Live Configuration Editing

* All configuration changes are saved instantly and trigger a live reload—no app restart.

* Upon successful save, users receive immediate visual confirmation (checkmark/banner).

* Validation errors are shown inline; invalid changes are discarded and do not alter live state.

### General Tab Contents

The General settings tab contains:

* Open at login (toggle)
* Enable/disable Tiller tiling (toggle)
* UI hint display enable/disable (toggle)
* Show Dock icon / menu bar only (toggle)
* Leader key default binding (shortcut picker)
* Leader timeout (slider/input, 0–30 seconds, default 5)
* Resize increment value and unit selector (percent/pixels, default 5%)
* Margin (container outer gap): 0–20px (default 8px)
* Padding (gap between containers): 0–20px (default 8px)
* Accordion offset: 4–64px (default 32px)
* Animation duration: 150–300ms (default 200ms)

### Key Bindings Tab

The Key Bindings tab provides a table of all actions with three columns per action:

* **Leader layer toggle (checkbox):** When checked, the action requires the leader key to be pressed first. When unchecked, the key binding acts as a global direct hotkey accessible at any time.

* **Sub-layer key (optional, single character):** An intermediate key pressed after the leader key but before the action key. Creates a grouping layer (e.g., `m` for monitor actions). Sub-layers are one level deep only — no nesting. The sub-layer column is only available when the leader layer toggle is checked.

* **Key binding:** The actual key or key combination for the action. Uses a macOS-style shortcut picker.

An action can be bound through leader mode OR as a direct hotkey, but not both simultaneously. Toggling the leader checkbox switches between the two modes.

**Hint text** is displayed both in the Key Bindings config UI and in the runtime command palette overlay:

* "Press leader key again or Escape to exit leader layer"
* "Press Escape to exit sub-layer"

### Config File Management

* **Location:** `~/.config/tiller`

* **Format:** User-selectable, JSON or YAML

* **Supported Settings:** See General and Key Bindings tabs for the full settings list. All settings enumerated in those tabs are serialized to the config file.

## Configuration Schema and Validation

### Strict Schema Enforcement

* All config files (JSON/YAML) are schema-validated on load and save.

* Public schema specification is provided for validation.

* If config is invalid/malformed, only affected features are disabled and a banner/popup notifies the user of fallbacks. Application remains stable for unaffected features.

## Animations, Visual Feedback, and Responsiveness

### Animated Behavior

* All window moves, resizes, layout changes are animated with an ease-in-out curve and use a 200ms default duration (user-configurable from 150–300ms).

* All related containers and windows animate together for each change.

* Target containers are briefly outlined in a subtle sea blue when animating window moves.

### Visual Communication

* All errors, configuration saves, and command palette commands provide prompt, visible feedback (banners, overlays, color cues).

* Design upholds WCAG AA contrast requirements throughout overlays, focus rings, and command palettes.

* Forced-float due to resize failure triggers a single notification per app (never a modal).

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

* All windows on the main monitor are immediately tiled in the monocle layout.

1. Accessing Configuration:

* Opening config editor presents an initial welcome/permission explanation once.

* Users can access General, Key Bindings, and About tabs.

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

## Planned Features (TBC)

* **Cross-Monitor Window Movement:** Moving windows between monitors via keyboard shortcuts is planned but not yet specified. Details TBC.

## Feature Exclusions

* No virtual desktop (workspace) switching.

* No plugin or scripting capabilities.

* macOS-only support for MVP; no Windows or Linux support.

## Configuration Option Table

| Setting | Type | Allowed Values | Default | Live Reload | Validation/Feedback |
|---|---|---|---|---|---|
| Layout | Enum | Monocle, Half, etc. (9 layouts) | Monocle | Yes | Invalid: Error banner |
| Margin (container gap) | Integer (px) | 0–20 | 8 | Yes | Out-of-range: Red border |
| Padding (between containers) | Integer (px) | 0–20 | 8 | Yes | Out-of-range: Red border |
| Accordion Offset | Integer (px) | 4–64 | 32 | Yes | Out-of-range: Red border |
| Container Resize Increment | String (% or px) | e.g., "5%", "50px" | "5%" | Yes | Invalid format: Red border |
| Leader Key | String | See key rules | unset | Yes | Conflict: Warning popover |
| Direct Hotkey Bindings | Mapping | Per action | None | Yes | Conflict: Warning popover |
| Leader Timeout | Integer (seconds) | 0–30 (0 = infinite) | 5 | Yes | Out-of-range: Red border |
| Open at Login | Boolean | true/false | false | Yes | — |
| UI Hint Display | Boolean | true/false | true | Yes | — |
| Show Dock Icon | Boolean | true/false | false | Yes | — |
| Animation Duration | Integer (ms) | 150–300 | 200 | Yes | Out-of-range: Red border |
| Floating App List | List | App names | None | Yes | Typos: Suggest correction |

## Performance and Scalability

* Supports simultaneous management of up to 6 displays and 40+ windows.

* Animation performance target: 60fps on modern MacBook models.

## macOS Integration Details

* Uses macOS Accessibility APIs for all window management.

* Leverages menu bar API for config editor and app access.

* No networking; configuration strictly local.

---

**End of Tiller Window Manager: Functional & UX Specification**
