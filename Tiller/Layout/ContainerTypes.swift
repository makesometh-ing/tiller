//
//  ContainerTypes.swift
//  Tiller
//

import CoreGraphics

struct ContainerID: Hashable, Equatable, Sendable {
    let rawValue: UInt
}

enum LayoutID: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case monocle
    case splitHalves
}

typealias LayoutDefinition = @Sendable (_ monitorFrame: CGRect, _ margin: Int, _ padding: Int) -> [CGRect]

struct Container: Equatable, Sendable {
    let id: ContainerID
    let frame: CGRect
    private(set) var windowIDs: [WindowID]
    private(set) var focusedWindowID: WindowID?

    init(id: ContainerID, frame: CGRect, windowIDs: [WindowID] = [], focusedWindowID: WindowID? = nil) {
        self.id = id
        self.frame = frame
        self.windowIDs = windowIDs
        self.focusedWindowID = focusedWindowID
    }

    // MARK: - Ring Buffer Operations

    /// Appends a window to the ring buffer. Sets focus if this is the first window.
    /// No-op if the window is already in the ring.
    mutating func addWindow(_ windowID: WindowID) {
        guard !windowIDs.contains(windowID) else { return }
        windowIDs.append(windowID)
        if focusedWindowID == nil {
            focusedWindowID = windowID
        }
    }

    /// Removes a window from the ring buffer. If the removed window was focused,
    /// focus advances to the next window (wrapping around), or nil if empty.
    /// No-op if the window is not in the ring.
    mutating func removeWindow(_ windowID: WindowID) {
        guard let index = windowIDs.firstIndex(of: windowID) else { return }

        let wasFocused = focusedWindowID == windowID
        windowIDs.remove(at: index)

        if wasFocused {
            if windowIDs.isEmpty {
                focusedWindowID = nil
            } else {
                let nextIndex = index < windowIDs.count ? index : 0
                focusedWindowID = windowIDs[nextIndex]
            }
        }
    }

    /// Cycles focus to the next window in the ring buffer (wraps around).
    /// No-op if 0 or 1 windows.
    mutating func cycleNext() {
        guard windowIDs.count > 1,
              let focused = focusedWindowID,
              let index = windowIDs.firstIndex(of: focused) else { return }
        let nextIndex = (index + 1) % windowIDs.count
        focusedWindowID = windowIDs[nextIndex]
    }

    /// Cycles focus to the previous window in the ring buffer (wraps around).
    /// No-op if 0 or 1 windows.
    mutating func cyclePrevious() {
        guard windowIDs.count > 1,
              let focused = focusedWindowID,
              let index = windowIDs.firstIndex(of: focused) else { return }
        let prevIndex = (index - 1 + windowIDs.count) % windowIDs.count
        focusedWindowID = windowIDs[prevIndex]
    }

    /// Removes the focused window from the ring and advances focus.
    /// Returns the removed window ID, or nil if no window is focused.
    mutating func moveFocusedWindow() -> WindowID? {
        guard let focused = focusedWindowID else { return nil }
        removeWindow(focused)
        return focused
    }
}
