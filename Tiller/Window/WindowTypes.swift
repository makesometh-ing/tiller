//
//  WindowTypes.swift
//  Tiller
//

import CoreGraphics
import Foundation

nonisolated struct WindowID: Hashable, Equatable, Sendable {
    let rawValue: CGWindowID  // UInt32
}

nonisolated struct WindowInfo: Equatable, Identifiable, Sendable {
    let id: WindowID
    let title: String
    let appName: String
    let bundleID: String?
    let frame: CGRect
    let isResizable: Bool
    let isFloating: Bool
    let ownerPID: pid_t
}

nonisolated enum WindowChangeEvent: Equatable, Sendable {
    case windowOpened(WindowInfo)
    case windowClosed(WindowID)
    case windowFocused(WindowID)
    case windowMoved(WindowID, newFrame: CGRect)
    case windowResized(WindowID, newFrame: CGRect)
}

nonisolated struct FocusedWindowInfo: Equatable, Sendable {
    let windowID: WindowID
    let appName: String
    let bundleID: String?
}
