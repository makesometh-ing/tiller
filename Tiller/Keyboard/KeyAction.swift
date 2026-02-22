//
//  KeyAction.swift
//  Tiller
//

enum KeyAction: Equatable, Sendable {
    case switchLayout(LayoutID)
    case moveWindow(MoveDirection)
    case focusContainer(MoveDirection)
    case cycleWindow(CycleDirection)
    case exitLeader

    var staysInLeader: Bool {
        switch self {
        case .switchLayout:
            return false
        case .moveWindow, .focusContainer, .cycleWindow:
            return true
        case .exitLeader:
            return false
        }
    }
}
