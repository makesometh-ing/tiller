/// Modifier keys of a key chord. Hyper is all four modifiers together.
public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = Modifiers(rawValue: 1)
    public static let option = Modifiers(rawValue: 2)
    public static let shift = Modifiers(rawValue: 4)
    public static let command = Modifiers(rawValue: 8)
    public static let hyper: Modifiers = [.control, .option, .shift, .command]

    /// The macOS symbols in the standard order, for example ⌃⌥⇧⌘ for Hyper.
    public var symbols: String {
        [(Modifiers.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { contains($0.0) }.map(\.1).joined()
    }
}

/// A key with modifiers, for example ⌃⌥ Space, or Hyper L. Key codes are macOS virtual key codes.
public struct KeyChord: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Reads a chord from text such as "hyper+l", "ctrl+opt+space", "cmd+shift+4" or "?".
    public init?(spec: String) {
        let parts = spec.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let keyName = parts.last else { return nil }
        if keyName == "?" && parts.count == 1 {
            self.init(keyCode: 44, modifiers: .shift)
            return
        }
        guard let code = KeyNames.codes[keyName] else { return nil }
        var modifiers: Modifiers = []
        for name in parts.dropLast() {
            switch name {
            case "ctrl", "control": modifiers.insert(.control)
            case "opt", "option", "alt": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            case "cmd", "command": modifiers.insert(.command)
            case "hyper": modifiers.formUnion(.hyper)
            default: return nil
            }
        }
        self.init(keyCode: code, modifiers: modifiers)
    }

    /// The text form that `init(spec:)` reads.
    public var spec: String {
        var names: [String] = []
        if modifiers == .hyper { names.append("hyper") } else {
            if modifiers.contains(.control) { names.append("ctrl") }
            if modifiers.contains(.option) { names.append("opt") }
            if modifiers.contains(.shift) { names.append("shift") }
            if modifiers.contains(.command) { names.append("cmd") }
        }
        return (names + [KeyNames.name(for: keyCode)]).joined(separator: "+")
    }

    /// The key cap labels, for example ["⌃⌥⇧⌘", "L"] or ["⌃⌥", "Space"].
    public var labels: [String] {
        let key = KeyNames.label(for: keyCode)
        return modifiers.isEmpty ? [key] : [modifiers.symbols, key]
    }
}

/// Virtual key codes of the US keyboard layout.
public enum KeyNames {
    public static let codes: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13,
        "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25,
        "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
        "tab": 48, "space": 49, "`": 50, "esc": 53,
    ]
    private static let names = Dictionary(codes.map { ($1, $0) }, uniquingKeysWith: { a, _ in a })

    public static func name(for code: UInt16) -> String { names[code] ?? "key\(code)" }

    public static func label(for code: UInt16) -> String {
        let name = name(for: code)
        return name.count == 1 ? name.uppercased() : name.capitalized
    }
}

/// The ids of the actions in leader key mode.
public enum ActionID: String, Codable, CaseIterable, Sendable {
    case layoutFullScreen, layoutVerticalSplit, layoutLeftTwoThirds, layoutRightTwoThirds
    case focusPreviousContainer, focusNextContainer, toggleAxis
    case focusPreviousWindow, focusNextWindow, toggleFloat
    case raiseFloating
    case turnOff

    /// The focus actions keep leader key mode by default, so that their keys can be pressed in a row.
    // TODO: add the actions that move a window to the previous or next container.
    public var exitsByDefault: Bool {
        ![.focusPreviousContainer, .focusNextContainer, .focusPreviousWindow, .focusNextWindow].contains(self)
    }
}

/// The leader key and the key of each action in leader key mode.
public struct Shortcuts: Codable, Equatable, Sendable {
    public var leader: KeyChord?
    /// Turns Tiller off and on, in every app and also while Tiller is off.
    public var toggle: KeyChord?
    public var actions: [ActionID: KeyChord]
    /// Actions whose chord was cleared. They don't get their standard chord when saved shortcuts are read.
    public var cleared: Set<ActionID> = []
    /// The "Exit after" setting of each action that was changed on the Shortcuts page.
    public var exitAfter: [ActionID: Bool] = [:]

    public init(leader: KeyChord?, toggle: KeyChord?, actions: [ActionID: KeyChord]) {
        self.leader = leader
        self.toggle = toggle
        self.actions = actions
    }

    enum CodingKeys: CodingKey { case leader, toggle, actions, cleared, exitAfter }

    /// A cleared `toggle` is written as null. Saved shortcuts without the `toggle` key get the standard toggle chord.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(leader, forKey: .leader)
        try c.encode(toggle, forKey: .toggle)
        try c.encode(actions, forKey: .actions)
        try c.encode(cleared, forKey: .cleared)
        try c.encode(exitAfter, forKey: .exitAfter)
    }

    /// Saved shortcuts don't contain the actions that were added after the save. Each of these actions gets its standard chord,
    /// if another action doesn't use that chord.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        leader = try c.decodeIfPresent(KeyChord.self, forKey: .leader)
        actions = try c.decode([ActionID: KeyChord].self, forKey: .actions)
        cleared = try c.decodeIfPresent(Set<ActionID>.self, forKey: .cleared) ?? []
        toggle = c.contains(.toggle) ? try c.decodeIfPresent(KeyChord.self, forKey: .toggle) : Self.standard.toggle
        exitAfter = try c.decodeIfPresent([ActionID: Bool].self, forKey: .exitAfter) ?? [:]
        for (id, chord) in Self.standard.actions where actions[id] == nil && !cleared.contains(id) && !actions.values.contains(chord) {
            actions[id] = chord
        }
    }

    public static let standard = Shortcuts(
        leader: KeyChord(spec: "ctrl+opt+space"),
        // ⇧⌘T, ⌃⌥T and ⌥⌘T are used by browsers, Finder and Rectangle.
        toggle: KeyChord(spec: "ctrl+opt+cmd+t"),
        actions: [
            .layoutFullScreen: KeyChord(spec: "1")!, .layoutVerticalSplit: KeyChord(spec: "2")!,
            .layoutLeftTwoThirds: KeyChord(spec: "3")!, .layoutRightTwoThirds: KeyChord(spec: "4")!,
            .focusPreviousContainer: KeyChord(spec: "k")!, .focusNextContainer: KeyChord(spec: "j")!,
            .toggleAxis: KeyChord(spec: "v")!, .focusPreviousWindow: KeyChord(spec: "h")!,
            .focusNextWindow: KeyChord(spec: "l")!, .toggleFloat: KeyChord(spec: "f")!,
            .raiseFloating: KeyChord(spec: "r")!, .turnOff: KeyChord(spec: "q")!,
        ])

    /// True when leader key mode ends after the action. `turnOff` always ends it.
    public func exits(after action: ActionID) -> Bool {
        action == .turnOff || (exitAfter[action] ?? action.exitsByDefault)
    }

    public func isLeader(keyCode: UInt16, modifiers: Modifiers) -> Bool {
        leader == KeyChord(keyCode: keyCode, modifiers: modifiers)
    }

    /// The action of a key press in leader key mode. A chord with the same modifiers is used first.
    /// A key without modifiers also matches while modifiers are held, for example `1` while Hyper is still held after Hyper L.
    public func action(keyCode: UInt16, modifiers: Modifiers) -> ActionID? {
        let pressed = KeyChord(keyCode: keyCode, modifiers: modifiers)
        if let exact = actions.first(where: { $0.value == pressed })?.key { return exact }
        return actions.first(where: { $0.value.keyCode == keyCode && $0.value.modifiers.isEmpty })?.key
    }

    /// Sets the chord of an action. Another action with the same chord loses its chord, so that one chord has one action.
    public mutating func set(_ chord: KeyChord?, for action: ActionID) {
        if let chord {
            for (id, other) in actions where other == chord && id != action {
                actions[id] = nil
                cleared.insert(id)
            }
        }
        actions[action] = chord
        if chord == nil { cleared.insert(action) } else { cleared.remove(action) }
    }
}
