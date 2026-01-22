//
//  FullscreenLayoutEngine.swift
//  Tiller
//

import CoreGraphics

/// Horizontal accordion layout.
/// All windows same size, overlapping. Focused centered, prev/next offset to show edges.
final class FullscreenLayoutEngine: LayoutEngineProtocol, Sendable {

    func calculate(input: LayoutInput) -> LayoutResult {
        let tileableWindows = input.windows.filter { window in
            !window.isFloating && window.isResizable
        }

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
        let accordionOffset = CGFloat(input.accordionOffset)

        // All windows same size: container minus accordionOffset
        let windowWidth = container.width - accordionOffset
        let windowHeight = container.height

        // Ring buffer indices
        let prevIndex = (focusedIndex - 1 + tileableWindows.count) % tileableWindows.count
        let nextIndex = (focusedIndex + 1) % tileableWindows.count

        for (index, window) in tileableWindows.enumerated() {
            let targetX: CGFloat

            if index == focusedIndex {
                // Focused: centered
                targetX = container.minX + (accordionOffset / 2)
            } else if index == prevIndex && tileableWindows.count > 1 {
                // Previous: left aligned
                targetX = container.minX
            } else if index == nextIndex && tileableWindows.count > 2 {
                // Next: right aligned
                targetX = container.minX + accordionOffset
            } else {
                // Others: centered (hidden behind focused)
                targetX = container.minX + (accordionOffset / 2)
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
