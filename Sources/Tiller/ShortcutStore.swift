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
            Log.event(.settingsChanged, ["setting": "showKeyBar", "value": .bool(showKeyBar)])
        }
    }
    private static let showKeyBarKey = "showKeyBar"
    @Published var showIn: ShowIn {
        didSet {
            defaults.set(showIn.rawValue, forKey: Self.showInKey)
            Log.event(.settingsChanged, ["setting": "showIn", "value": .string(showIn.rawValue)])
        }
    }
    private static let showInKey = "showIn"
    /// When false, the leader key goes to the focused app and windows don't move. On by default.
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: Self.enabledKey)
            Log.event(enabled ? .appEnabled : .appDisabled, ["source": .string(enabledSource)])
            enabledSource = "settings"
        }
    }
    /// Where the next change of `enabled` comes from, for the log: `settings`, `menu`, `dock`, `globalShortcut` or `leaderKey`.
    private var enabledSource = "settings"

    func setEnabled(_ on: Bool, source: String) {
        enabledSource = source
        enabled = on
    }
    private static let enabledKey = "enabled"
    /// "Debug logging" is on until this time. nil when it is off.
    @Published private(set) var debugLoggingUntil: Date?
    private static let debugLoggingUntilKey = "debugLoggingUntil"
    private var debugLoggingTimer: Timer?
    var debugLogging: Bool { DebugLogging.hoursLeft(until: debugLoggingUntil, now: Date()) != nil }
    /// "Include window titles in logs". Off by default.
    @Published var logTitles: Bool {
        didSet {
            defaults.set(logTitles, forKey: Self.logTitlesKey)
            applyLogSettings()
            Log.event(.settingsChanged, ["setting": "logTitles", "value": .bool(logTitles)])
        }
    }
    private static let logTitlesKey = "logTitles"

    /// Turns debug logging on for `duration`, or off. `reason` is `settings`, or `expired` when the timer turns it off.
    func setDebugLogging(_ on: Bool, duration: TimeInterval = DebugLogging.duration, reason: String = "settings") {
        debugLoggingUntil = on ? Date().addingTimeInterval(duration) : nil
        defaults.set(debugLoggingUntil, forKey: Self.debugLoggingUntilKey)
        applyLogSettings()
        Log.event(.settingsChanged, ["setting": "debugLogging", "value": .bool(on), "reason": .string(reason),
                                     "until": debugLoggingUntil.map { .string(Date.ISO8601FormatStyle().format($0)) } ?? .null])
    }

    /// Sets the log settings and the timer that turns debug logging off.
    private func applyLogSettings() {
        Log.shared.set(debugToFile: debugLogging, titles: logTitles)
        debugLoggingTimer?.invalidate()
        guard let until = debugLoggingUntil else { return }
        debugLoggingTimer = Timer(fire: until, interval: 0, repeats: false) { [weak self] _ in self?.setDebugLogging(false, reason: "expired") }
        RunLoop.main.add(debugLoggingTimer!, forMode: .common)
    }
    /// The Tiller defaults, or the proof defaults domain in a proof run.
    let defaults: UserDefaults
    private static let key = "shortcuts"

    /// `--proof` uses its own defaults domain, so that a proof run doesn't change your settings. The domain is emptied at launch.
    /// `--leader <spec>` and `--keys <action id>=<spec>,...` replace saved shortcuts for one launch.
    /// `--global <action id>=<spec>,...` sets global shortcuts for one launch.
    init(arguments: [String]) {
        let proof = arguments.contains("--proof")
        defaults = proof ? UserDefaults(suiteName: "com.tiller.Tiller.proof")! : .standard
        if proof { defaults.removePersistentDomain(forName: "com.tiller.Tiller.proof") }
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
        for pair in (value("--global") ?? "").split(separator: ",") {
            let parts = pair.split(separator: "=").map(String.init)
            guard parts.count == 2, let id = ActionID(rawValue: parts[0]) else { continue }
            shortcuts.global[id] = KeyChord(spec: parts[1])
        }
        self.shortcuts = shortcuts
        showKeyBar = defaults.object(forKey: Self.showKeyBarKey) as? Bool ?? true
        showIn = defaults.string(forKey: Self.showInKey).flatMap(ShowIn.init) ?? .menuBar
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        logTitles = defaults.bool(forKey: Self.logTitlesKey)
        // A time in the past is cleared at once by the timer.
        debugLoggingUntil = defaults.object(forKey: Self.debugLoggingUntilKey) as? Date
        applyLogSettings()
    }

    func setLeader(_ chord: KeyChord?) {
        shortcuts.leader = chord
        save("leader", .string(chord?.spec ?? "none"))
    }

    func set(_ chord: KeyChord?, for action: ActionID) {
        shortcuts.set(chord, for: action)
        save("key.\(action.rawValue)", .string(chord?.spec ?? "none"))
    }

    func setToggle(_ chord: KeyChord?) {
        shortcuts.toggle = chord
        save("toggle", .string(chord?.spec ?? "none"))
    }

    func setGlobal(_ chord: KeyChord?, for action: ActionID) {
        shortcuts.global[action] = chord
        save("global.\(action.rawValue)", .string(chord?.spec ?? "none"))
    }

    func setExitAfter(_ exits: Bool, for action: ActionID) {
        shortcuts.exitAfter[action] = exits
        save("exitAfter.\(action.rawValue)", .bool(exits))
    }

    private func save(_ setting: String, _ value: LogValue) {
        defaults.set(try? JSONEncoder().encode(shortcuts), forKey: Self.key)
        Log.event(.settingsChanged, ["setting": .string(setting), "value": value])
    }

    /// All settings, for the log and the diagnostics zip. Chords are text, for example `ctrl+opt+shift+cmd+l`.
    var logFields: [String: LogValue] {
        let spacing = Spacing.standard
        return [
            "leader": .string(shortcuts.leader?.spec ?? "none"),
            "toggle": .string(shortcuts.toggle?.spec ?? "none"),
            "keys": .object(Dictionary(uniqueKeysWithValues: shortcuts.actions.map { ($0.key.rawValue, .string($0.value.spec)) })),
            "global": .object(Dictionary(uniqueKeysWithValues: shortcuts.global.map { ($0.key.rawValue, .string($0.value.spec)) })),
            "exitAfter": .object(Dictionary(uniqueKeysWithValues: ActionID.allCases.map { ($0.rawValue, .bool(shortcuts.exits(after: $0))) })),
            "showKeyBar": .bool(showKeyBar),
            "showIn": .string(showIn.rawValue),
            "enabled": .bool(enabled),
            "debugLogging": .bool(debugLogging),
            "debugLoggingUntil": debugLoggingUntil.map { .string(Date.ISO8601FormatStyle().format($0)) } ?? .null,
            "logTitles": .bool(logTitles),
            "spacing": ["workspaceMargin": .double(spacing.workspaceMargin), "containerMargin": .double(spacing.containerMargin),
                        "carouselSpacing": .double(spacing.carouselSpacing)],
        ]
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
        case .moveWindowPreviousContainer: .moveWindow(-1)
        case .moveWindowNextContainer: .moveWindow(1)
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
        case .moveWindowPreviousContainer: "Move to previous container"
        case .moveWindowNextContainer: "Move to next container"
        case .raiseFloating: "Raise floating windows"
        case .turnOff: "Turn Tiller off"
        }
    }
}
