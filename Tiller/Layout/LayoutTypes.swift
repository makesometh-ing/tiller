//
//  LayoutTypes.swift
//  Tiller
//

import CoreGraphics

struct LayoutInput: Equatable, Sendable {
    let windows: [WindowInfo]
    let focusedWindowID: WindowID?
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
