import AppKit
import TillerCore

/// Where the Tiller icon is shown: the menu bar, the Dock or both.
enum ShowIn: String, CaseIterable, Identifiable {
    case menuBar, dock, both
    var id: String { rawValue }
    var title: String {
        switch self {
        case .menuBar: "Menu bar"
        case .dock: "Dock"
        case .both: "Both"
        }
    }
}

/// The saved shortcuts and the settings of the General page and the Shortcuts page. Read and written on the main thread.
final class ShortcutStore: ObservableObject {
    @Published private(set) var shortcuts: Shortcuts
    /// When false, leader key mode shows the containers and window pills without the key bar. On by default.
    @Published var showKeyBar: Bool {
        didSet {
            defaults.set(showKeyBar, forKey: Self.showKeyBarKey)
            Log.write("setting showKeyBar=\(showKeyBar)")
        }
    }
    private static let showKeyBarKey = "showKeyBar"
    @Published var showIn: ShowIn {
        didSet {
            defaults.set(showIn.rawValue, forKey: Self.showInKey)
            Log.write("setting showIn=\(showIn.rawValue)")
        }
    }
    private static let showInKey = "showIn"
    /// When false, the leader key goes to the focused app and windows don't move. On by default.
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: Self.enabledKey)
            Log.write("setting enabled=\(enabled)")
        }
    }
    private static let enabledKey = "enabled"
    private let defaults: UserDefaults
    private static let key = "shortcuts"

    /// `--proof` uses its own defaults domain, so that a proof run doesn't change your shortcuts.
    /// `--leader <spec>` and `--keys <action id>=<spec>,...` replace saved shortcuts for one launch.
    init(arguments: [String]) {
        let proof = arguments.contains("--proof")
        defaults = proof ? UserDefaults(suiteName: "com.tiller.Tiller.proof")! : .standard
        if proof {
            defaults.removeObject(forKey: Self.key)
            defaults.removeObject(forKey: Self.showKeyBarKey)
            defaults.removeObject(forKey: Self.showInKey)
            defaults.removeObject(forKey: Self.enabledKey)
        }
        var shortcuts = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Shortcuts.self, from: $0) } ?? .standard
        func value(_ name: String) -> String? {
            arguments.firstIndex(of: name).flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        }
        if let spec = value("--leader") { shortcuts.leader = KeyChord(spec: spec) }
        for pair in (value("--keys") ?? "").split(separator: ",") {
            let parts = pair.split(separator: "=").map(String.init)
            guard parts.count == 2, let id = ActionID(rawValue: parts[0]) else { continue }
            shortcuts.set(KeyChord(spec: parts[1]), for: id)
        }
        self.shortcuts = shortcuts
        showKeyBar = defaults.object(forKey: Self.showKeyBarKey) as? Bool ?? true
        showIn = defaults.string(forKey: Self.showInKey).flatMap(ShowIn.init) ?? .menuBar
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    func setLeader(_ chord: KeyChord?) {
        shortcuts.leader = chord
        save()
    }

    func set(_ chord: KeyChord?, for action: ActionID) {
        shortcuts.set(chord, for: action)
        save()
    }

    func setToggle(_ chord: KeyChord?) {
        shortcuts.toggle = chord
        save()
    }

    func setExitAfter(_ exits: Bool, for action: ActionID) {
        shortcuts.exitAfter[action] = exits
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(shortcuts), forKey: Self.key)
        Log.write("shortcuts saved leader=\(shortcuts.leader?.spec ?? "none") toggle=\(shortcuts.toggle?.spec ?? "none") "
                  + "exitAfter=\(ActionID.allCases.filter(shortcuts.exits(after:)).map(\.rawValue).joined(separator: ",")) " + shortcuts.actions.map { "\($0.key.rawValue)=\($0.value.spec)" }.sorted().joined(separator: " "))
    }
}

extension Modifiers {
    init(_ flags: CGEventFlags) {
        self = []
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskShift) { insert(.shift) }
        if flags.contains(.maskCommand) { insert(.command) }
    }

    var eventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.command) { flags.insert(.maskCommand) }
        return flags
    }
}

extension ActionID {
    var action: Action {
        switch self {
        case .layoutFullScreen: .layout(.fullScreen)
        case .layoutVerticalSplit: .layout(.verticalSplit)
        case .layoutLeftTwoThirds: .layout(.leftTwoThirds)
        case .layoutRightTwoThirds: .layout(.rightTwoThirds)
        case .focusPreviousContainer: .focusContainer(-1)
        case .focusNextContainer: .focusContainer(1)
        case .toggleAxis: .toggleAxis
        case .focusPreviousWindow: .focusWindow(-1)
        case .focusNextWindow: .focusWindow(1)
        case .toggleFloat: .toggleFloat
        case .raiseFloating: .raiseFloating
        case .turnOff: .turnOff
        }
    }

    var title: String {
        switch self {
        case .layoutFullScreen: "Full screen layout"
        case .layoutVerticalSplit: "Vertical split layout"
        case .layoutLeftTwoThirds: "Left two-thirds layout"
        case .layoutRightTwoThirds: "Right two-thirds layout"
        case .focusPreviousContainer: "Focus previous container"
        case .focusNextContainer: "Focus next container"
        case .toggleAxis: "Switch carousel mode"
        case .focusPreviousWindow: "Focus previous window"
        case .focusNextWindow: "Focus next window"
        case .toggleFloat: "Float or tile"
        case .raiseFloating: "Raise floating windows"
        case .turnOff: "Turn Tiller off"
        }
    }
}
