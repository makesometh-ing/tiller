//
//  LayoutTypes.swift
//  Tiller
//

import CoreGraphics

struct LayoutInput: Equatable, Sendable {
    let windows: [WindowInfo]
    let focusedWindowID: WindowID?
    /// The actually focused window (may differ from focusedWindowID when a non-resizable window
    /// is focused and the accordion freezes on the last focused tileable window).
    let actualFocusedWindowID: WindowID?
    let containerFrame: CGRect
    let accordionOffset: Int
}

struct WindowPlacement: Equatable, Sendable {
    let windowID: WindowID
    let pid: pid_t
    let targetFrame: CGRect
}

struct LayoutResult: Equatable, Sendable {
    let placements: [WindowPlacement]
}

protocol LayoutEngineProtocol: Sendable {
    func calculate(input: LayoutInput) -> LayoutResult
}
