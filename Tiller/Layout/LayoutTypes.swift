//
//  LayoutTypes.swift
//  Tiller
//

import CoreGraphics

nonisolated struct LayoutInput: Equatable, Sendable {
    let windows: [WindowInfo]
    let focusedWindowID: WindowID?
    /// The actually focused window (may differ from focusedWindowID when a non-resizable window
    /// is focused and the accordion freezes on the last focused tileable window).
    let actualFocusedWindowID: WindowID?
    let containerFrame: CGRect
    let accordionOffset: Int
}

nonisolated struct WindowPlacement: Equatable, Sendable {
    let windowID: WindowID
    let pid: pid_t
    let targetFrame: CGRect
}

nonisolated struct LayoutResult: Equatable, Sendable {
    let placements: [WindowPlacement]
}

nonisolated protocol LayoutEngineProtocol: Sendable {
    func calculate(input: LayoutInput) -> LayoutResult
}
