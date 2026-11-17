import CoreGraphics

/// The `CGWindowID` of a window.
public typealias WindowID = UInt32

public struct Spacing: Equatable, Codable, Sendable {
    public var workspaceMargin: CGFloat
    public var containerMargin: CGFloat
    public var carouselSpacing: CGFloat

    public init(workspaceMargin: CGFloat, containerMargin: CGFloat, carouselSpacing: CGFloat) {
        self.workspaceMargin = workspaceMargin
        self.containerMargin = containerMargin
        self.carouselSpacing = carouselSpacing
    }

    public static let standard = Spacing(workspaceMargin: 10, containerMargin: 10, carouselSpacing: 30)
}

public struct Container: Equatable, Sendable {
    public var frame: CGRect
    /// Windows in ring order.
    public var windows: [WindowID] = []
    public var focusedIndex = 0
    public var axis: CarouselAxis = .horizontal

    public var focusedWindow: WindowID? { windows.isEmpty ? nil : windows[focusedIndex] }

    public func windowFrames(spacing: CGFloat) -> [WindowID: CGRect] {
        let frames = carouselFrames(container: frame, count: windows.count, focused: focusedIndex, spacing: spacing, axis: axis)
        return Dictionary(uniqueKeysWithValues: zip(windows, frames))
    }
}

/// The container and the ring index of a window when it was removed from its carousel, and the layout at that time.
public struct RingPosition: Equatable, Sendable {
    public var layout: LayoutKind
    public var container: Int
    public var index: Int
    public init(layout: LayoutKind, container: Int, index: Int) { (self.layout, self.container, self.index) = (layout, container, index) }
}

/// The workspace of one screen. Each screen has its own workspace.
public struct Workspace: Equatable, Sendable {
    /// The display UUID from macOS. It stays the same when the screen is disconnected and connected again.
    public let displayID: String
    /// The desktop of the screen, inset by the workspace margin.
    public let frame: CGRect
    public let spacing: Spacing
    public private(set) var layout: LayoutKind = .fullScreen
    public private(set) var containers: [Container]
    public private(set) var focusedContainerIndex = 0
    /// The carousel mode of each container, for each layout that had a carousel mode switched. A layout that is applied again gets these modes.
    public var savedAxes: [LayoutKind: [CarouselAxis]] = [:]
    /// The ring position of each minimized window and each window of a hidden app. `restore` puts the window back at this position.
    public var savedPositions: [WindowID: RingPosition] = [:]

    public init(displayID: String, desktop: CGRect, spacing: Spacing = .standard) {
        self.displayID = displayID
        self.spacing = spacing
        self.frame = desktop.insetBy(dx: spacing.workspaceMargin, dy: spacing.workspaceMargin)
        self.containers = [Container(frame: frame)]
    }

    public var focusedWindow: WindowID? { containers[focusedContainerIndex].focusedWindow }

    /// Replaces the containers with the containers of `layout`.
    /// `focused` goes into the first container. The other windows are put in the containers
    /// round-robin, from the second container.
    public mutating func apply(_ layout: LayoutKind, windows: [WindowID], focused: WindowID?) {
        self.layout = layout
        let axes = savedAxes[layout] ?? []
        containers = layout.containerFrames(in: frame, gap: spacing.containerMargin).enumerated().map { i, frame in
            Container(frame: frame, axis: i < axes.count ? axes[i] : .horizontal)
        }
        focusedContainerIndex = 0
        var next = 0
        if let focused, windows.contains(focused) {
            containers[0].windows.append(focused)
            next = 1
        }
        for window in windows where window != focused {
            containers[next % containers.count].windows.append(window)
            next += 1
        }
    }

    /// Moves focus by `offset` positions in the ring of the focused container.
    public mutating func focusWindow(offset: Int) {
        let count = containers[focusedContainerIndex].windows.count
        guard count > 0 else { return }
        let index = containers[focusedContainerIndex].focusedIndex
        containers[focusedContainerIndex].focusedIndex = ((index + offset) % count + count) % count
    }

    /// Moves focus by `offset` containers in container order. Empty containers are skipped.
    public mutating func focusContainer(offset: Int) {
        let n = containers.count
        let step = offset >= 0 ? 1 : -1
        var index = focusedContainerIndex
        for _ in 0..<(abs(offset) * n) {
            index = ((index + step) % n + n) % n
            if !containers[index].windows.isEmpty { break }
        }
        if !containers[index].windows.isEmpty { focusedContainerIndex = index }
    }

    /// Moves focus to `window`, for example after a click on a window. Returns false if `window` isn't in the workspace.
    @discardableResult
    public mutating func focus(window: WindowID) -> Bool {
        for i in containers.indices {
            guard let index = containers[i].windows.firstIndex(of: window) else { continue }
            focusedContainerIndex = i
            containers[i].focusedIndex = index
            return true
        }
        return false
    }

    /// Switches the carousel of the focused container between horizontal and vertical.
    public mutating func toggleAxis() {
        containers[focusedContainerIndex].axis = containers[focusedContainerIndex].axis.toggled
        savedAxes[layout] = containers.map(\.axis)
    }

    public func contains(_ window: WindowID) -> Bool {
        containers.contains { $0.windows.contains(window) }
    }

    /// Puts `window` in the focused container, after the focused window, and focuses it.
    public mutating func insert(_ window: WindowID) {
        guard !contains(window) else { return }
        let i = focusedContainerIndex
        let index = containers[i].windows.isEmpty ? 0 : containers[i].focusedIndex + 1
        containers[i].windows.insert(window, at: index)
        containers[i].focusedIndex = index
    }

    /// Removes a window that was closed, floated or moved off the workspace.
    public mutating func remove(_ window: WindowID) {
        for i in containers.indices {
            guard let index = containers[i].windows.firstIndex(of: window) else { continue }
            containers[i].windows.remove(at: index)
            let count = containers[i].windows.count
            if index < containers[i].focusedIndex || containers[i].focusedIndex >= count {
                containers[i].focusedIndex = max(0, containers[i].focusedIndex - 1)
            }
        }
    }

    public func position(of window: WindowID) -> RingPosition? {
        for (i, c) in containers.enumerated() {
            if let index = c.windows.firstIndex(of: window) { return RingPosition(layout: layout, container: i, index: index) }
        }
        return nil
    }

    /// Removes `windows` and saves the ring position of each. All positions are read before the first window is removed.
    public mutating func removeSavingPositions(_ windows: [WindowID]) {
        for window in windows { savedPositions[window] = position(of: window) ?? savedPositions[window] }
        for window in windows { remove(window) }
    }

    /// Puts each window of `windows` with a saved position back into its container, at its ring index, as the focused window
    /// of that container. The windows are put back in ring index order, so that windows removed together get their old order.
    /// When several windows go back into one container, the first of them in `windows` becomes the focused window. Pass the windows front to back.
    /// When the layout changed or the container doesn't exist, the window is inserted into the focused container.
    /// Returns the windows that had a saved position.
    @discardableResult
    public mutating func restore(_ windows: [WindowID]) -> [WindowID] {
        let saved = windows.compactMap { w in savedPositions[w].map { (w, $0) } }.sorted { $0.1.index < $1.1.index }
        for (window, p) in saved {
            savedPositions[window] = nil
            guard !contains(window) else { continue }
            guard p.layout == layout, containers.indices.contains(p.container) else { insert(window); continue }
            let index = min(p.index, containers[p.container].windows.count)
            containers[p.container].windows.insert(window, at: index)
        }
        let restored = saved.map(\.0)
        for window in windows.reversed() where restored.contains(window) {
            if let p = position(of: window) { containers[p.container].focusedIndex = p.index }
        }
        return restored
    }

    public func windowFrames() -> [WindowID: CGRect] {
        containers.reduce(into: [:]) { result, container in
            result.merge(container.windowFrames(spacing: spacing.carouselSpacing)) { $1 }
        }
    }
}
