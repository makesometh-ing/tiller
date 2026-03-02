---
name: paper-mockup
description: "Create visual UI mockups for Tiller in Paper, and use existing mockups as visual references when implementing UI in SwiftUI. Use whenever the user asks to design, mock up, sketch, or visualize any Tiller UI component — including the app icon, menu bar icon, status bar, dropdown menu, settings screen, leader key overlay, or container highlights. Also triggers on requests to explore visual directions, try a new look, or iterate on existing Tiller designs. ALSO triggers in reverse: when the user asks to implement or build a UI component in SwiftUI, use this skill to check Paper for existing mockups and screenshot them as a visual guide for implementation. This skill requires the Paper MCP server to be connected."
---

# Paper Mockup — Tiller UI Design

Create macOS-native UI mockups for Tiller using Paper's design canvas. Tiller is a menu bar tiling window manager — its UI is minimal, keyboard-centric, and lives entirely in the menu bar and floating overlays.

## Before You Start

1. Confirm Paper is connected: call `get_basic_info`. If it fails, ask the user to open a Paper file.
2. Read `docs/PRD.md` for the product spec of the component being mocked up. The PRD is the starting point, but it may lag behind the implementation — when in doubt, cross-reference with the actual codebase and flag discrepancies to the user.
3. Read `references/tiller-ui-specs.md` for macOS design conventions and SwiftUI element mappings specific to Paper rendering.
4. Check available fonts with `get_font_family_info` — prefer **SF Pro Display** for text and **SF Mono** for code/keycaps. Fall back to **Inter** or **System Sans-Serif** if unavailable.

## macOS Native Look in Paper

Paper renders HTML/CSS, but Tiller mockups should look like native macOS SwiftUI. Follow these conventions:

### Visual Language

- **Background materials**: Use semi-transparent backgrounds with backdrop blur to suggest vibrancy (`rgba(246,246,246,0.95)` for light, `rgba(40,40,40,0.85)` for dark)
- **Corner radius**: 10px for windows/panels, 6px for buttons/controls, 4px for inline elements
- **Shadows**: Subtle, layered — `0 2px 12px rgba(0,0,0,0.15), 0 0 1px rgba(0,0,0,0.1)` for floating panels
- **Separators**: 1px solid `rgba(0,0,0,0.1)` (light mode) or `rgba(255,255,255,0.1)` (dark mode)
- **Accent color**: macOS system blue `#007AFF` for selection, toggles, and active states

### SwiftUI Element Mapping

When mocking up UI, use HTML that visually matches these SwiftUI components:

| SwiftUI | HTML Approximation |
|---------|-------------------|
| `Toggle` | 51x31px pill with 27px circle knob, `#34C759` when on |
| `Picker` (segmented) | Row of equal-width segments with 1px border, active segment filled |
| `Form` / `List` | Full-width rows with 12px vertical padding, grouped with rounded container |
| `Section(header:)` | Uppercase 11px gray label above a grouped block |
| `TextField` | 28px height, 1px border `rgba(0,0,0,0.1)`, 6px corner radius, 8px horizontal padding |
| `Stepper` | Value display flanked by `−`/`+` buttons |
| `Button` | 6px radius, 8px/16px padding, `.borderedProminent` = filled blue, `.bordered` = subtle gray |
| `Slider` | 4px track with rounded knob, blue fill for active portion |
| `Menu` item | Full-width row, 28px height, 6px corner radius hover highlight |
| `Divider` | 1px separator with 8px vertical margin |
| `Label` with icon | 16x16 icon + 8px gap + text, vertically centered |

### Typography Scale (macOS Native)

| Role | Size | Weight | Mapping |
|------|------|--------|---------|
| Window title | 13px | Semibold | `.headline` |
| Section header | 11px | Regular, uppercase, tracking 0.06em | `.caption` |
| Body / menu item | 13px | Regular | `.body` |
| Secondary text | 11px | Regular | `.caption` |
| Status bar text | 12px | Medium, monospaced | Custom |
| Keyboard shortcut | 12px | Regular, monospaced | `.caption` monospaced |

### Color Palette

| Role | Light | Dark |
|------|-------|------|
| Window background | `rgba(246,246,246,0.95)` | `rgba(40,40,40,0.85)` |
| Text primary | `#1D1D1F` | `#F5F5F7` |
| Text secondary | `#86868B` | `#A1A1A6` |
| Accent | `#007AFF` | `#0A84FF` |
| Success/On | `#34C759` | `#30D158` |
| Destructive | `#FF3B30` | `#FF453A` |
| Separator | `rgba(0,0,0,0.1)` | `rgba(255,255,255,0.1)` |
| Hover/selection | `rgba(0,122,255,0.1)` | `rgba(10,132,255,0.15)` |

## Artboard Sizes

Use the appropriate size for each component type:

| Component | Artboard Size | Notes |
|-----------|--------------|-------|
| App icon | 512x512 | Design at 512, scales down to 16/32/128/256 |
| Menu bar icon | 80x36 | 18x18 icon area centered, template rendering (single color) |
| Menu bar dropdown | 300x500 | Approximate — adjust height to content |
| Settings window | 520x600 | Standard macOS preferences size |
| Leader key overlay | 600x80 | Wide and short, horizontally centered |
| Container highlights | 1440x900 | Full desktop mockup showing highlighted containers |

## Workflow

1. **Clarify scope**: Which component? Light mode, dark mode, or both?
2. **Create artboard** at the appropriate size (see table above)
3. **Build incrementally** — one visual group per `write_html` call
4. **Screenshot and review** after every 2-3 modifications
5. **Iterate** based on user feedback
6. **Always call `finish_working_on_nodes`** when done

## Component-Specific Guidance

For UI content and structure, always start with `docs/PRD.md` — it defines what each component contains and how it should behave. The PRD may not reflect the latest implementation decisions, so when the user corrects something, trust their direction over the PRD and flag that the PRD needs updating.

`references/tiller-ui-specs.md` supplements the PRD with macOS-specific visual conventions that aren't in the product spec (icon sizes, keycap styling, color well rendering, etc.).

## Using Mockups as Implementation References

This skill works in both directions:

**Design → Code**: When the user asks to implement a UI component in SwiftUI, check Paper for existing mockups before writing code:

1. Call `get_basic_info` to list artboards — look for one matching the component being implemented.
2. If found, `get_screenshot` the relevant artboard at 2x scale to see the visual target clearly.
3. Use `get_tree_summary` and `get_computed_styles` to extract exact spacing, colors, font sizes, and layout details from the mockup.
4. Reference these values in your SwiftUI implementation rather than guessing.
5. If no mockup exists, offer to create one first — a quick visual reference prevents implementation guesswork.

This ensures implementation matches the designed intent. The mockup is the source of truth for visual decisions; the PRD is the source of truth for behavior.

## Dark Mode

Tiller is a developer tool — users likely prefer dark mode. Default to **dark mode** unless the user asks for light. When mocking both, create two artboards side by side.
