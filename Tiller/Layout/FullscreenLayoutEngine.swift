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
        let focusedMargin = CGFloat(input.accordionOffset)  // 16px - margin for focused window
        let peekAmount = focusedMargin / 2  // 8px - how much of prev/next is visible

        // All windows are the same size
        let windowWidth = container.width - (focusedMargin * 2)
        let windowHeight = container.height

        // Focused window position
        let focusedX = container.minX + focusedMargin

        // Ring buffer indices
        let prevIndex = (focusedIndex - 1 + tileableWindows.count) % tileableWindows.count
        let nextIndex = (focusedIndex + 1) % tileableWindows.count

        for (index, window) in tileableWindows.enumerated() {
            let targetFrame: CGRect

            if index == focusedIndex {
                // Focused: centered with margins
                targetFrame = CGRect(
                    x: focusedX,
                    y: container.minY,
                    width: windowWidth,
                    height: windowHeight
                )
            } else if index == prevIndex && tileableWindows.count > 1 {
                // Previous: offset left by peekAmount, shows 8px on left edge
                targetFrame = CGRect(
                    x: focusedX - peekAmount,
                    y: container.minY,
                    width: windowWidth,
                    height: windowHeight
                )
            } else if index == nextIndex && tileableWindows.count > 2 {
                // Next: offset right by peekAmount, shows 8px on right edge
                targetFrame = CGRect(
                    x: focusedX + peekAmount,
                    y: container.minY,
                    width: windowWidth,
                    height: windowHeight
                )
            } else {
                // Others: same position as focused (hidden behind)
                targetFrame = CGRect(
                    x: focusedX,
                    y: container.minY,
                    width: windowWidth,
                    height: windowHeight
                )
            }

            placements.append(WindowPlacement(
                windowID: window.id,
                pid: window.ownerPID,
                targetFrame: targetFrame
            ))
        }

        return LayoutResult(placements: placements)
    }
}
