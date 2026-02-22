//
//  FullscreenLayoutEngine.swift
//  Tiller
//

import CoreGraphics

/// Horizontal accordion layout.
/// All windows same size, overlapping. Focused centered, prev/next offset to show edges.
final class FullscreenLayoutEngine: LayoutEngineProtocol, Sendable {

    func calculate(input: LayoutInput) -> LayoutResult {
        TillerLogger.debug("layout","Received \(input.windows.count) windows, focused=\(input.focusedWindowID?.rawValue ?? 0)")

        let tileableWindows = input.windows.filter { window in
            !window.isFloating && window.isResizable
        }

        let nonResizableWindows = input.windows.filter { window in
            !window.isFloating && !window.isResizable
        }

        TillerLogger.debug("layout","Tileable: \(tileableWindows.count), non-resizable: \(nonResizableWindows.count)")

        guard !tileableWindows.isEmpty || !nonResizableWindows.isEmpty else {
            return LayoutResult(placements: [])
        }

        var placements: [WindowPlacement] = []
        let container = input.containerFrame

        // --- Accordion placements for resizable (tileable) windows ---

        if !tileableWindows.isEmpty {
            var focusedIndex = 0
            if let focusedID = input.focusedWindowID,
               let idx = tileableWindows.firstIndex(where: { $0.id == focusedID }) {
                focusedIndex = idx
            }

            let offset = CGFloat(input.accordionOffset)
            let windowCount = tileableWindows.count

            // Window dimensions depend on count
            // 1 window: fills container
            // 2 windows: width = container - offset
            // 3+ windows: width = container - 2*offset
            let windowWidth: CGFloat
            let windowHeight = container.height

            switch windowCount {
            case 1:
                windowWidth = container.width
            case 2:
                windowWidth = container.width - offset
            default:
                windowWidth = container.width - (2 * offset)
            }

            // Ring buffer indices for prev/next
            let prevIndex = (focusedIndex - 1 + windowCount) % windowCount
            let nextIndex = (focusedIndex + 1) % windowCount

            TillerLogger.debug("layout","Ring: prev=\(prevIndex) focused=\(focusedIndex) next=\(nextIndex)")
            TillerLogger.debug("layout","Container: \(String(describing: container)), offset=\(offset), windowWidth=\(windowWidth)")

            for (index, window) in tileableWindows.enumerated() {
                let targetX: CGFloat

                switch windowCount {
                case 1:
                    // Single window fills container
                    targetX = container.minX
                case 2:
                    // Two windows: focused left-aligned, other offset right
                    if index == focusedIndex {
                        targetX = container.minX
                    } else {
                        targetX = container.minX + offset
                    }
                default:
                    // 3+ windows: prev at minX, focused at minX+offset, next at minX+2*offset
                    // Others hidden behind focused at minX+offset
                    if index == prevIndex {
                        targetX = container.minX
                    } else if index == focusedIndex {
                        targetX = container.minX + offset
                    } else if index == nextIndex {
                        targetX = container.minX + (2 * offset)
                    } else {
                        // Others: same position as focused (hidden behind)
                        targetX = container.minX + offset
                    }
                }

                let targetFrame = CGRect(
                    x: targetX,
                    y: container.minY,
                    width: windowWidth,
                    height: windowHeight
                )

                placements.append(WindowPlacement(
                    windowID: window.id,
                    pid: window.ownerPID,
                    targetFrame: targetFrame
                ))
            }
        }

        // --- Centered placements for non-resizable windows ---

        for window in nonResizableWindows {
            let windowSize = window.frame.size

            // If window fits within the container, center it (preserve original size)
            // If too large, skip — no placement means auto-float per PRD
            if windowSize.width <= container.width && windowSize.height <= container.height {
                let centeredX = container.minX + (container.width - windowSize.width) / 2
                let centeredY = container.minY + (container.height - windowSize.height) / 2

                let centeredFrame = CGRect(
                    x: centeredX,
                    y: centeredY,
                    width: windowSize.width,
                    height: windowSize.height
                )

                TillerLogger.debug("layout","Centering non-resizable window \(window.id.rawValue) (\(window.appName)) at \(String(describing: centeredFrame))")

                placements.append(WindowPlacement(
                    windowID: window.id,
                    pid: window.ownerPID,
                    targetFrame: centeredFrame
                ))
            } else {
                TillerLogger.debug("layout","Non-resizable window \(window.id.rawValue) (\(window.appName)) too large for container, skipping")
            }
        }

        return LayoutResult(placements: placements)
    }
}
