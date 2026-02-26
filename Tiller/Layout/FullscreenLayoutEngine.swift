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

        // All non-floating windows participate in the accordion ring
        let allWindows = input.windows.filter { !$0.isFloating }

        TillerLogger.debug("layout","Non-floating: \(allWindows.count)")

        guard !allWindows.isEmpty else {
            return LayoutResult(placements: [])
        }

        var placements: [WindowPlacement] = []
        let container = input.containerFrame
        let offset = CGFloat(input.accordionOffset)
        let windowCount = allWindows.count

        // Determine focused index in the unified ring
        var focusedIndex = 0
        if let focusedID = input.focusedWindowID,
           let idx = allWindows.firstIndex(where: { $0.id == focusedID }) {
            focusedIndex = idx
        }

        // Ring buffer indices for prev/next
        let prevIndex = (focusedIndex - 1 + windowCount) % windowCount
        let nextIndex = (focusedIndex + 1) % windowCount

        // Accordion dimensions for resizable windows
        let accordionWidth: CGFloat
        switch windowCount {
        case 1: accordionWidth = container.width
        case 2: accordionWidth = container.width - offset
        default: accordionWidth = container.width - (2 * offset)
        }
        let accordionHeight = container.height

        TillerLogger.debug("layout","Ring: prev=\(prevIndex) focused=\(focusedIndex) next=\(nextIndex)")
        TillerLogger.debug("layout","Container: \(String(describing: container)), offset=\(offset), accordionWidth=\(accordionWidth)")

        for (index, window) in allWindows.enumerated() {
            // Calculate the accordion X position for this ring slot
            let targetX: CGFloat
            switch windowCount {
            case 1:
                targetX = container.minX
            case 2:
                if index == focusedIndex {
                    targetX = container.minX
                } else {
                    targetX = container.minX + offset
                }
            default:
                if index == prevIndex {
                    targetX = container.minX
                } else if index == focusedIndex {
                    targetX = container.minX + offset
                } else if index == nextIndex {
                    targetX = container.minX + (2 * offset)
                } else {
                    targetX = container.minX + offset
                }
            }

            if window.isResizable {
                // Resizable: standard accordion frame
                let targetFrame = CGRect(
                    x: targetX,
                    y: container.minY,
                    width: accordionWidth,
                    height: accordionHeight
                )
                placements.append(WindowPlacement(
                    windowID: window.id,
                    pid: window.ownerPID,
                    targetFrame: targetFrame
                ))
            } else {
                let windowSize = window.frame.size

                // Skip non-resizable windows that don't fit the container
                guard windowSize.width <= container.width && windowSize.height <= container.height else {
                    TillerLogger.debug("layout","Non-resizable window \(window.id.rawValue) (\(window.appName)) too large for container, skipping")
                    continue
                }

                let isActualFocused = input.actualFocusedWindowID == window.id

                let targetFrame: CGRect
                if isActualFocused {
                    // Focused non-resizable: centered in container (overlay per PRD)
                    let centeredX = container.minX + (container.width - windowSize.width) / 2
                    let centeredY = container.minY + (container.height - windowSize.height) / 2
                    targetFrame = CGRect(x: centeredX, y: centeredY, width: windowSize.width, height: windowSize.height)
                    TillerLogger.debug("layout","Centering focused non-resizable window \(window.id.rawValue) (\(window.appName)) at \(String(describing: targetFrame))")
                } else {
                    // Non-focused non-resizable: at accordion ring position, natural size, centered vertically
                    let centeredY = container.minY + (container.height - windowSize.height) / 2
                    targetFrame = CGRect(x: targetX, y: centeredY, width: windowSize.width, height: windowSize.height)
                    TillerLogger.debug("layout","Non-resizable window \(window.id.rawValue) (\(window.appName)) at ring position x=\(targetX), frame=\(String(describing: targetFrame))")
                }

                placements.append(WindowPlacement(
                    windowID: window.id,
                    pid: window.ownerPID,
                    targetFrame: targetFrame
                ))
            }
        }

        return LayoutResult(placements: placements)
    }
}
