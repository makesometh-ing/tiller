import CoreGraphics

/// How Tiller handles a window.
public enum WindowKind: Equatable, Sendable {
    /// Put in a container. Tiller sets its frame.
    case tiled
    /// Not put in a container. Tiller doesn't move or resize it, and doesn't change focus for it.
    case floating
    /// Not handled at all: popups, panels above the normal window layer, minimized windows and windows on other Spaces.
    case ignored
}

/// Accessibility and window server attributes of a window that decide its `WindowKind`.
public struct WindowTraits: Equatable, Sendable {
    public var subrole: String?
    public var minimized: Bool
    /// False for windows with a fixed size, for example the Xcode welcome window and the WeChat update window.
    public var sizeSettable: Bool
    /// False for windows on another Space and for hidden windows.
    public var onScreen: Bool
    /// The window server layer. Normal windows are at layer 0.
    public var layer: Int
    public var modal: Bool
    /// True when AXParent of the window is the app. A child window returns another window.
    public var parentIsApp: Bool

    public init(subrole: String?, minimized: Bool = false, sizeSettable: Bool, onScreen: Bool = true,
                layer: Int = 0, modal: Bool = false, parentIsApp: Bool = true) {
        self.subrole = subrole
        self.minimized = minimized
        self.sizeSettable = sizeSettable
        self.onScreen = onScreen
        self.layer = layer
        self.modal = modal
        self.parentIsApp = parentIsApp
    }

    public var kind: WindowKind {
        if minimized || !onScreen || layer != 0 || subrole == nil || subrole == "AXUnknown" { return .ignored }
        if subrole == "AXStandardWindow" && sizeSettable && parentIsApp && !modal { return .tiled }
        return .floating
    }
}

/// True when a window in front of the window with `id` contains `point`.
/// `frontToBack` lists the on-screen windows and their frames, front first.
public func isCovered(_ point: CGPoint, window id: WindowID, frontToBack: [(id: WindowID, frame: CGRect)]) -> Bool {
    for entry in frontToBack {
        if entry.id == id { return false }
        if entry.frame.contains(point) { return true }
    }
    return false
}
