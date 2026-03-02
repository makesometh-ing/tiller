# Tiller UI Component Specs

Detailed specs for each Tiller UI component. Read this file when mocking up a specific component.

## Table of Contents

1. [App Icon](#app-icon)
2. [Menu Bar Icon & Status Text](#menu-bar-icon--status-text)
3. [Menu Bar Dropdown](#menu-bar-dropdown)
4. [Settings Window](#settings-window)
5. [Leader Key Overlay](#leader-key-overlay)
6. [Container Highlights](#container-highlights)

---

## App Icon

**Sizes**: 1024x1024 master, scales to 512, 256, 128, 32, 16.

**Design constraints**:
- Must be recognizable at 16x16
- Should communicate "tiling" or "window management"
- macOS icon conventions: rounded-rect superellipse mask applied by the OS — design the interior only
- Keep detail minimal — the icon must read clearly in Spotlight, Dock, and Finder sidebar

**Current state**: Icon assets exist but may need visual refresh.

---

## Menu Bar Icon & Status Text

**Icon**: 18x18 template image (single color, system handles light/dark). Rendered at 1x and 2x.

**Status text** displayed next to the icon in the menu bar:
- Format: `<monitor> | <layout> | <layer>`
- Example states:
  - `1 | 3 | -` — Monitor 1, Layout 3, leader inactive
  - `2 | D | *` — Monitor 2, Dynamic layout, leader active
  - `1 | 1 | m` — Monitor 1, Layout 1, in monitor sub-layer
  - `! 1 | 1 | -` — Config error indicator
- Font: Monospaced, 12pt

**Design notes**:
- The icon + status text sit in the macOS menu bar (height ~24px, dark or light depending on system)
- Template rendering means the icon must be a single shape — no color, just alpha channel

---

## Menu Bar Dropdown

The dropdown appears when clicking the menu bar icon. It's a SwiftUI `MenuBarExtra` popover.

**Menu items (top to bottom)**:

1. **Enable/Disable Toggle**
   - Enabled: `✓ Tiller is tiling your windows...`
   - Disabled: `✗ Tiller is sleeping...`

2. *Divider*

3. **Per-Monitor Layout Groups** (one group per connected monitor)
   - Group header: `[1] MacBook Pro` (monitor index + display name)
   - 9 layout items per monitor:
     - `1-Monocle`
     - `2-Left Half / Right Half`
     - `3-Right Half / Left Half`
     - `4-Left Third / Right Two Thirds`
     - `5-Left Two Thirds / Right Third`
     - `6-Three Columns`
     - `7-Left Half / Right Quarter / Right Quarter`
     - `8-Center Main / Side Columns`
     - `9-Four Quarters`
   - Active layout shows checkmark prefix
   - If layout was manually resized: `D-Dynamic` appended

4. *Divider*

5. **Settings...** (disabled in Phase 1)

6. **Reload Config**
   - Normal: `Reload Config`
   - Error state: `Reload Config — <error message>` in red

7. **Reset to Defaults** — triggers confirmation alert

8. *Divider*

9. **Quit Tiller** — `⌘Q`

---

## Settings Window

Phase 1 uses JSON config, but the settings GUI mockup should show what Phase 2 will look like.

**Window structure**: Sidebar-navigated settings window (520x600) with four sections: General, Appearance, Keybindings, Floating Apps. Sidebar uses macOS standard styling — selected item gets accent-color highlight with white text.

### General Section

**Toggles group:**
| Setting | Control | Default |
|---------|---------|---------|
| Enable Tiller | Toggle | On |
| Launch at login | Toggle | Off |

**Leader Key group:**
| Setting | Control | Default | Range |
|---------|---------|---------|-------|
| Leader trigger | Key recorder | Option + Space | — |
| Timeout | Stepper + Slider | 5s | 0–30 (0 = infinite) |

### Appearance Section

**Spacing group:**
| Setting | Control | Default | Range |
|---------|---------|---------|-------|
| Container margin | Slider + value | 8px | 0–20 |
| Container padding | Slider + value | 8px | 0–20 |
| Accordion offset | Slider + value | 16px | 4–24 |

**Container Settings group** (with inline sub-headers for Active/Inactive):
| Setting | Sub-group | Control | Default | Range |
|---------|-----------|---------|---------|-------|
| Enabled | — | Toggle | On | — |
| Corner radius | — (shared) | Slider + value | 8pt | 0–20 |
| Border color | Active | Color well + hex | #007AFF | — |
| Border width | Active | Value label | 2pt | — |
| Glow opacity | Active | Slider + value | 0.6 | 0–1 |
| Border color | Inactive | Color well + hex | #FFFFFF66 | — |
| Border width | Inactive | Value label | 1pt | — |

**Animation group:**
| Setting | Control | Default | Range |
|---------|---------|---------|-------|
| Duration | Slider + value | 200ms | 50–500 |

### Keybindings Section
| Setting | Control | Default |
|---------|---------|---------|
| Leader trigger | Key recorder | Option + Space |
| Action bindings | Table with key recorder per row | Various |

Each action binding row shows:
- Action name (e.g., "Cycle Next", "Move Left", "Focus Right")
- Current keybinding
- Whether it requires leader key (toggle)
- Sub-layer assignment (optional)

### Floating Apps Section
- List of bundle identifiers with add/remove buttons
- Each row: app icon + app name + bundle ID

---

## Leader Key Overlay

**Appearance**: Floating `NSPanel`, non-activating, ignores mouse events.

**Positioning**: Centered horizontally on active monitor, 8px below the top edge.

**Visual style**:
- Ultra-thin material background (vibrancy/blur)
- 12px corner radius
- Subtle shadow

**Animation**:
- In: slide up + fade, 150ms ease-out
- Out: fade, 100ms ease-in

**Content — two rows:**

**Top row — Action hints** (4 groups):
| Group | Keys |
|-------|------|
| Cycle | `< >` |
| Move | `h l` |
| Focus | `H L` |
| Exit | `esc` |

Each group: label in secondary text, keys in monospaced keycaps.

**Bottom row — Layout numbers**:
- Numbers 1 through 9
- Each in a keycap-style box
- Active layout highlighted with tinted background (accent color)
- Monospaced font

**Keycap styling**: Inline rounded rect (4px radius), slight border, monospaced text. Think of actual keyboard key appearance.

---

## Container Highlights

When leader key is active, containers on screen get border highlights.

**Focused container**:
- Border: 2pt solid #007AFF (configurable)
- Outward glow: 8pt radius, 0.6 opacity (configurable)
- Corner radius: 8pt (configurable)

**Other containers**:
- Border: 1pt solid #FFFFFF66 (configurable)
- No glow
- Same corner radius

**Mockup approach**: Show a desktop screenshot or wireframe with 2-3 tiled windows, one highlighted as focused (blue glow) and others with subtle white borders.
