import AppKit
import TillerCore

/// What the leader key overlay shows on one screen. Frames use the Accessibility coordinate space.
struct OverlayScreen {
    struct ContainerItem: Identifiable {
        let id: Int
        let frame: CGRect
        let axis: CarouselAxis
        let windowCount: Int
        let focused: Bool
    }

    /// Where the pill of a window is drawn.
    enum Place {
        /// Full pill at the bottom-right corner of the window.
        case front
        /// App icon only, in the visible edge at the start of the carousel axis (left or top).
        case startEdge
        /// App icon only, in the visible edge at the end of the carousel axis (right or bottom).
        case endEdge
    }

    struct WindowItem: Identifiable {
        let id: WindowID
        let frame: CGRect
        let appName: String
        let pid: pid_t
        let floating: Bool
        let place: Place
        let axis: CarouselAxis
    }

    let uuid: String
    let frame: CGRect
    let spacing: CGFloat
    var containers: [ContainerItem] = []
    var windows: [WindowItem] = []
}
