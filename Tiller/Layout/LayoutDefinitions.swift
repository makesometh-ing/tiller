//
//  LayoutDefinitions.swift
//  Tiller
//

import CoreGraphics

enum LayoutDefinitions {

    /// Returns the container frames for a given layout within a monitor frame.
    static func containerFrames(
        for layout: LayoutID,
        in monitorFrame: CGRect,
        margin: CGFloat,
        padding: CGFloat
    ) -> [CGRect] {
        switch layout {
        case .monocle:
            return monocle(in: monitorFrame, margin: margin)
        case .splitHalves:
            return splitHalves(in: monitorFrame, margin: margin, padding: padding)
        }
    }

    // MARK: - Layout Implementations

    private static func monocle(in monitorFrame: CGRect, margin: CGFloat) -> [CGRect] {
        [monitorFrame.insetBy(dx: margin, dy: margin)]
    }

    private static func splitHalves(
        in monitorFrame: CGRect,
        margin: CGFloat,
        padding: CGFloat
    ) -> [CGRect] {
        let totalWidth = monitorFrame.width
        let containerWidth = (totalWidth - 2 * margin - padding) / 2
        let height = monitorFrame.height - 2 * margin

        let left = CGRect(
            x: monitorFrame.minX + margin,
            y: monitorFrame.minY + margin,
            width: containerWidth,
            height: height
        )

        let right = CGRect(
            x: monitorFrame.minX + margin + containerWidth + padding,
            y: monitorFrame.minY + margin,
            width: containerWidth,
            height: height
        )

        return [left, right]
    }
}
