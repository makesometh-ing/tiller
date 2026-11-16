import CoreGraphics

/// All rects use the Accessibility coordinate space: the origin is the top-left corner
/// of the primary screen and y increases downward.
public enum LayoutKind: String, CaseIterable, Codable, Sendable {
    case fullScreen
    case verticalSplit
    case leftTwoThirds
    case rightTwoThirds

    /// Container frames in container order: left to right, then top to bottom.
    /// `gap` is the container margin. Container edges on the workspace edge don't get a margin.
    public func containerFrames(in workspace: CGRect, gap: CGFloat) -> [CGRect] {
        switch self {
        case .fullScreen: [workspace]
        case .verticalSplit: Self.columns(workspace, gap: gap, leftFraction: 1.0 / 2)
        case .leftTwoThirds: Self.columns(workspace, gap: gap, leftFraction: 2.0 / 3)
        case .rightTwoThirds: Self.columns(workspace, gap: gap, leftFraction: 1.0 / 3)
        }
    }

    private static func columns(_ r: CGRect, gap: CGFloat, leftFraction: CGFloat) -> [CGRect] {
        // Widths are rounded to whole points so that window edges don't land on half pixels.
        let leftWidth = ((r.width - gap) * leftFraction).rounded()
        let left = CGRect(x: r.minX, y: r.minY, width: leftWidth, height: r.height)
        let rightX = left.maxX + gap
        let right = CGRect(x: rightX, y: r.minY, width: r.maxX - rightX, height: r.height)
        return [left, right]
    }
}
