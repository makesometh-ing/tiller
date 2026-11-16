import CoreGraphics

public enum CarouselAxis: String, Codable, Sendable {
    case horizontal
    case vertical

    public var toggled: CarouselAxis { self == .horizontal ? .vertical : .horizontal }
}

/// Window frames of a horizontal carousel, in ring order.
/// `focused` is the ring index of the focused window F. `spacing` is the carousel spacing S.
public func horizontalCarouselFrames(container c: CGRect, count n: Int, focused f: Int, spacing s: CGFloat) -> [CGRect] {
    carouselFrames(container: c, count: n, focused: f, spacing: s, axis: .horizontal)
}

/// Window frames of a carousel, in ring order. A vertical carousel uses the same rules as a
/// horizontal carousel, with y and height in place of x and width.
public func carouselFrames(container c: CGRect, count n: Int, focused f: Int, spacing s: CGFloat, axis: CarouselAxis) -> [CGRect] {
    func frame(offset: CGFloat, length: CGFloat) -> CGRect {
        switch axis {
        case .horizontal: CGRect(x: c.minX + offset, y: c.minY, width: length, height: c.height)
        case .vertical: CGRect(x: c.minX, y: c.minY + offset, width: c.width, height: length)
        }
    }
    let size = axis == .horizontal ? c.width : c.height
    switch n {
    case ..<1:
        return []
    case 1:
        return [c]
    case 2:
        return (0..<2).map { i in frame(offset: i == f ? 0 : s, length: size - s) }
    default:
        let next = (f + 1) % n
        let previous = (f - 1 + n) % n
        return (0..<n).map { i in
            let offset: CGFloat = i == previous ? 0 : (i == next ? 2 * s : s)
            return frame(offset: offset, length: size - 2 * s)
        }
    }
}
