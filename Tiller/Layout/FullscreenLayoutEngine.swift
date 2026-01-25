//
//  FullscreenLayoutEngine.swift
//  Tiller
//

import CoreGraphics

/// Horizontal accordion layout.
/// All windows same size, overlapping. Focused centered, prev/next offset to show edges.
final class FullscreenLayoutEngine: LayoutEngineProtocol, Sendable {

    func calculate(input: LayoutInput) -> LayoutResult {
        print("[LayoutEngine] Received \(input.windows.count) windows, focused=\(input.focusedWindowID?.rawValue ?? 0)")

        let tileableWindows = input.windows.filter { window in
            !window.isFloating && window.isResizable
        }

        print("[LayoutEngine] Tileable: \(tileableWindows.count), mode=\(tileableWindows.count == 1 ? "1" : tileableWindows.count == 2 ? "2" : "3+")")

        guard !tileableWindows.isEmpty else {
            return LayoutResult(placements: [])
        }

        var focusedIndex = 0
        if let focusedID = input.focusedWindowID,
           let idx = tileableWindows.firstIndex(where: { $0.id == focusedID }) {
            focusedIndex = idx
        }

        var placements: [WindowPlacement] = []
        let container = input.containerFrame
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

        print("[LayoutEngine] Ring: prev=\(prevIndex) focused=\(focusedIndex) next=\(nextIndex)")
        print("[LayoutEngine] Container: \(container), offset=\(offset), windowWidth=\(windowWidth)")

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

        return LayoutResult(placements: placements)
    }
}
