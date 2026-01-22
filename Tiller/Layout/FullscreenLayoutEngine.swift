//
//  FullscreenLayoutEngine.swift
//  Tiller
//

import CoreGraphics

/// Pure calculation engine for fullscreen layout with horizontal accordion.
/// Focused window fills the container, neighbors peek from edges.
final class FullscreenLayoutEngine: LayoutEngineProtocol, Sendable {

    func calculate(input: LayoutInput) -> LayoutResult {
        // Filter to only include tileable windows (not floating, is resizable)
        let tileableWindows = input.windows.filter { window in
            !window.isFloating && window.isResizable
        }

        guard !tileableWindows.isEmpty else {
            return LayoutResult(placements: [])
        }

        // Find the focused window or default to first tileable
        let focusedWindow: WindowInfo
        if let focusedID = input.focusedWindowID,
           let found = tileableWindows.first(where: { $0.id == focusedID }) {
            focusedWindow = found
        } else {
            focusedWindow = tileableWindows[0]
        }

        // Find focused index in tileable list
        let focusedIndex = tileableWindows.firstIndex(where: { $0.id == focusedWindow.id }) ?? 0

        var placements: [WindowPlacement] = []
        let container = input.containerFrame
        let offset = CGFloat(input.accordionOffset)

        for (index, window) in tileableWindows.enumerated() {
            let targetFrame: CGRect

            if window.id == focusedWindow.id {
                // Focused window fills the container
                targetFrame = container
            } else if index == focusedIndex - 1 {
                // Left neighbor peeks from left edge
                targetFrame = CGRect(
                    x: container.minX - container.width + offset,
                    y: container.minY,
                    width: container.width,
                    height: container.height
                )
            } else if index == focusedIndex + 1 {
                // Right neighbor peeks from right edge
                targetFrame = CGRect(
                    x: container.maxX - offset,
                    y: container.minY,
                    width: container.width,
                    height: container.height
                )
            } else if index < focusedIndex {
                // Windows to the left of left neighbor: hidden offscreen left
                targetFrame = CGRect(
                    x: container.minX - container.width * 2,
                    y: container.minY,
                    width: container.width,
                    height: container.height
                )
            } else {
                // Windows to the right of right neighbor: hidden offscreen right
                targetFrame = CGRect(
                    x: container.maxX + container.width,
                    y: container.minY,
                    width: container.width,
                    height: container.height
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
