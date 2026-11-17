import CoreGraphics

public struct Rect: Codable, Equatable, Sendable {
    public var x, y, w, h: Double
    public init(_ r: CGRect) { (x, y, w, h) = (r.minX, r.minY, r.width, r.height) }

    /// True when each value differs by 1 point or less.
    public func matches(_ other: Rect) -> Bool {
        abs(x - other.x) <= 1 && abs(y - other.y) <= 1 && abs(w - other.w) <= 1 && abs(h - other.h) <= 1
    }
}

/// The result of one action, sent from Tiller to the proof runner.
public struct ActionReport: Codable, Sendable {
    public struct Window: Codable, Sendable {
        public var id: WindowID
        public var title: String
        public var container: Int
        public var expected: Rect
        public var actual: Rect?
        public var bundleID: String?
        public init(id: WindowID, title: String, container: Int, expected: Rect, actual: Rect?, bundleID: String? = nil) {
            (self.id, self.title, self.container, self.expected, self.actual, self.bundleID) = (id, title, container, expected, actual, bundleID)
        }
    }
    public var action: String
    /// Time from the key press in the event tap to the last window move, in milliseconds.
    public var latencyMs: Double
    public var movedWindows: Int
    public var layout: String?
    public var expectedFocused: WindowID?
    public var actualFocused: WindowID?
    public var windows: [Window]
    /// Floating windows of the managed apps, with their actual frame in `actual`. Tiller must not change these frames.
    public var floating: [Window]
    /// The focused window of each container that isn't empty, in container order.
    public var fronts: [WindowID]?

    public init(action: String, latencyMs: Double, movedWindows: Int, layout: String?,
                expectedFocused: WindowID?, actualFocused: WindowID?, windows: [Window], floating: [Window], fronts: [WindowID]? = nil) {
        self.action = action
        self.latencyMs = latencyMs
        self.movedWindows = movedWindows
        self.layout = layout
        self.expectedFocused = expectedFocused
        self.actualFocused = actualFocused
        self.windows = windows
        self.floating = floating
        self.fronts = fronts
    }
}
