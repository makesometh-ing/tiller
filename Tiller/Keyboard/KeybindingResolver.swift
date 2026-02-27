//
//  KeybindingResolver.swift
//  Tiller
//

import Foundation

nonisolated struct KeybindingResolver: Sendable {

    struct BindingKey: Hashable, Sendable {
        let keyCode: UInt16
        let shift: Bool
    }

    struct ResolvedAction: Sendable {
        let action: KeyAction
        let staysInLeader: Bool
    }

    let leaderKeyCode: UInt16
    let leaderModifierMask: UInt64 // Modifier flags required for leader trigger

    private let leaderBindings: [BindingKey: ResolvedAction]

    init(config: KeybindingsConfig) {
        let triggerKey = config.leaderTrigger.last ?? "space"
        let triggerModifiers = config.leaderTrigger.dropLast()
        self.leaderKeyCode = Self.keyCode(for: triggerKey)
        self.leaderModifierMask = Self.modifierMask(for: triggerModifiers)

        var bindings: [BindingKey: ResolvedAction] = [:]
        for (actionID, binding) in config.actions where binding.leaderLayer && binding.subLayer == nil {
            guard let action = Self.parseActionID(actionID) else { continue }
            let keyName = binding.keys.last ?? ""
            let code = Self.keyCode(for: keyName)
            let shift = binding.keys.dropLast().contains("shift")
            let key = BindingKey(keyCode: code, shift: shift)
            bindings[key] = ResolvedAction(action: action, staysInLeader: binding.staysInLeader)
        }
        self.leaderBindings = bindings
    }

    func resolve(keyCode: UInt16, shift: Bool) -> ResolvedAction? {
        leaderBindings[BindingKey(keyCode: keyCode, shift: shift)]
    }

    func isLeaderTrigger(keyCode: UInt16, flags: UInt64) -> Bool {
        keyCode == leaderKeyCode && (flags & leaderModifierMask) == leaderModifierMask
    }

    // MARK: - Key Name → Virtual Key Code

    static func keyCode(for name: String) -> UInt16 {
        switch name.lowercased() {
        case "a": return 0
        case "s": return 1
        case "d": return 2
        case "f": return 3
        case "h": return 4
        case "g": return 5
        case "z": return 6
        case "x": return 7
        case "c": return 8
        case "v": return 9
        case "b": return 11
        case "q": return 12
        case "w": return 13
        case "e": return 14
        case "r": return 15
        case "y": return 16
        case "t": return 17
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "5": return 23
        case "6": return 22
        case "7": return 26
        case "8": return 28
        case "9": return 25
        case "0": return 29
        case "o": return 31
        case "u": return 32
        case "i": return 34
        case "p": return 35
        case "l": return 37
        case "j": return 38
        case "k": return 40
        case "n": return 45
        case "m": return 46
        case ",": return 43
        case ".": return 47
        case "/": return 44
        case ";": return 41
        case "'": return 39
        case "[": return 33
        case "]": return 30
        case "\\": return 42
        case "`": return 50
        case "-": return 27
        case "=": return 24
        case "space": return 49
        case "return": return 36
        case "tab": return 48
        case "delete", "backspace": return 51
        case "forward_delete", "forwarddelete": return 117
        case "escape": return 53
        case "f1": return 122
        case "f2": return 120
        case "f3": return 99
        case "f4": return 118
        case "f5": return 96
        case "f6": return 97
        case "f7": return 98
        case "f8": return 100
        case "f9": return 101
        case "f10": return 109
        case "f11": return 103
        case "f12": return 111
        default: return UInt16.max
        }
    }

    // MARK: - Modifier Names → Mask

    static func modifierMask(for modifiers: some Sequence<String>) -> UInt64 {
        var mask: UInt64 = 0
        for mod in modifiers {
            switch mod.lowercased() {
            case "cmd", "command": mask |= 0x100000   // CGEventFlags.maskCommand
            case "ctrl", "control": mask |= 0x40000   // CGEventFlags.maskControl
            case "option", "alt": mask |= 0x80000     // CGEventFlags.maskAlternate
            case "shift": mask |= 0x20000             // CGEventFlags.maskShift
            default: break
            }
        }
        return mask
    }

    // MARK: - Action ID → KeyAction

    static func parseActionID(_ id: String) -> KeyAction? {
        switch id {
        case "switchLayout.monocle": return .switchLayout(.monocle)
        case "switchLayout.splitHalves": return .switchLayout(.splitHalves)
        case "moveWindow.left": return .moveWindow(.left)
        case "moveWindow.right": return .moveWindow(.right)
        case "focusContainer.left": return .focusContainer(.left)
        case "focusContainer.right": return .focusContainer(.right)
        case "cycleWindow.previous": return .cycleWindow(.previous)
        case "cycleWindow.next": return .cycleWindow(.next)
        case "exitLeader": return .exitLeader
        default: return nil
        }
    }
}
