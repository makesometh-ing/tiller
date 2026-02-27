//
//  TillerConfig.swift
//  Tiller
//

import Foundation

// MARK: - Container Highlight Config

struct ContainerHighlightConfig: Codable, Equatable, Sendable {
    var enabled: Bool
    var activeBorderWidth: Double
    var activeBorderColor: String
    var activeGlowRadius: Double
    var activeGlowOpacity: Double
    var inactiveBorderWidth: Double
    var inactiveBorderColor: String

    static let `default` = ContainerHighlightConfig(
        enabled: true,
        activeBorderWidth: 2,
        activeBorderColor: "#007AFF",
        activeGlowRadius: 8,
        activeGlowOpacity: 0.6,
        inactiveBorderWidth: 1,
        inactiveBorderColor: "#FFFFFF66"
    )

    init(enabled: Bool = true, activeBorderWidth: Double = 2, activeBorderColor: String = "#007AFF",
         activeGlowRadius: Double = 8, activeGlowOpacity: Double = 0.6,
         inactiveBorderWidth: Double = 1, inactiveBorderColor: String = "#FFFFFF66") {
        self.enabled = enabled
        self.activeBorderWidth = activeBorderWidth
        self.activeBorderColor = activeBorderColor
        self.activeGlowRadius = activeGlowRadius
        self.activeGlowOpacity = activeGlowOpacity
        self.inactiveBorderWidth = inactiveBorderWidth
        self.inactiveBorderColor = inactiveBorderColor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        activeBorderWidth = try c.decodeIfPresent(Double.self, forKey: .activeBorderWidth) ?? 2
        activeBorderColor = try c.decodeIfPresent(String.self, forKey: .activeBorderColor) ?? "#007AFF"
        activeGlowRadius = try c.decodeIfPresent(Double.self, forKey: .activeGlowRadius) ?? 8
        activeGlowOpacity = try c.decodeIfPresent(Double.self, forKey: .activeGlowOpacity) ?? 0.6
        inactiveBorderWidth = try c.decodeIfPresent(Double.self, forKey: .inactiveBorderWidth) ?? 1
        inactiveBorderColor = try c.decodeIfPresent(String.self, forKey: .inactiveBorderColor) ?? "#FFFFFF66"
    }
}

// MARK: - Keybinding Types

struct ActionBinding: Codable, Equatable, Sendable {
    var keys: [String]
    var leaderLayer: Bool
    var subLayer: String?
    var staysInLeader: Bool
}

struct KeybindingsConfig: Codable, Equatable, Sendable {
    var leaderTrigger: [String]
    var actions: [String: ActionBinding]

    static let `default` = KeybindingsConfig(
        leaderTrigger: ["option", "space"],
        actions: [
            "switchLayout.monocle": ActionBinding(keys: ["1"], leaderLayer: true, subLayer: nil, staysInLeader: false),
            "switchLayout.splitHalves": ActionBinding(keys: ["2"], leaderLayer: true, subLayer: nil, staysInLeader: false),
            "moveWindow.left": ActionBinding(keys: ["h"], leaderLayer: true, subLayer: nil, staysInLeader: true),
            "moveWindow.right": ActionBinding(keys: ["l"], leaderLayer: true, subLayer: nil, staysInLeader: true),
            "focusContainer.left": ActionBinding(keys: ["shift", "h"], leaderLayer: true, subLayer: nil, staysInLeader: true),
            "focusContainer.right": ActionBinding(keys: ["shift", "l"], leaderLayer: true, subLayer: nil, staysInLeader: true),
            "cycleWindow.previous": ActionBinding(keys: ["shift", ","], leaderLayer: true, subLayer: nil, staysInLeader: true),
            "cycleWindow.next": ActionBinding(keys: ["shift", "."], leaderLayer: true, subLayer: nil, staysInLeader: true),
            "exitLeader": ActionBinding(keys: ["escape"], leaderLayer: true, subLayer: nil, staysInLeader: false),
        ]
    )
}

// MARK: - Config

struct TillerConfig: Codable, Equatable, Sendable {
    static let currentVersion = 2

    var version: Int
    var margin: Int
    var padding: Int
    var accordionOffset: Int
    var leaderTimeout: Double = 5.0
    var containerHighlights: ContainerHighlightConfig = .default
    var floatingApps: [String]
    var logLocation: String?
    var keybindings: KeybindingsConfig

    init(
        version: Int = Self.currentVersion,
        margin: Int,
        padding: Int,
        accordionOffset: Int,
        leaderTimeout: Double = 5.0,
        containerHighlights: ContainerHighlightConfig = .default,
        floatingApps: [String],
        logLocation: String? = nil,
        keybindings: KeybindingsConfig = .default
    ) {
        self.version = version
        self.margin = margin
        self.padding = padding
        self.accordionOffset = accordionOffset
        self.leaderTimeout = leaderTimeout
        self.containerHighlights = containerHighlights
        self.floatingApps = floatingApps
        self.logLocation = logLocation
        self.keybindings = keybindings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
        margin = try container.decode(Int.self, forKey: .margin)
        padding = try container.decode(Int.self, forKey: .padding)
        accordionOffset = try container.decode(Int.self, forKey: .accordionOffset)
        leaderTimeout = try container.decodeIfPresent(Double.self, forKey: .leaderTimeout) ?? 5.0
        containerHighlights = try container.decodeIfPresent(ContainerHighlightConfig.self, forKey: .containerHighlights) ?? .default
        floatingApps = try container.decode([String].self, forKey: .floatingApps)
        logLocation = try container.decodeIfPresent(String.self, forKey: .logLocation)
        keybindings = try container.decodeIfPresent(KeybindingsConfig.self, forKey: .keybindings) ?? .default
    }

    static let defaultLogPath: String = {
        let home = NSHomeDirectory()
        return (home as NSString).appendingPathComponent(".tiller/logs/tiller-debug.log")
    }()

    static let `default` = TillerConfig(
        margin: 8,
        padding: 8,
        accordionOffset: 16,
        leaderTimeout: 5.0,
        floatingApps: [
            "pro.betterdisplay.BetterDisplay"  // Overlay/utility windows that can't be positioned
        ],
        logLocation: nil,  // nil = use default: ~/.tiller/logs/tiller-debug.log
        keybindings: .default
    )

    enum ValidationRange {
        static let margin = 0...20
        static let padding = 0...20
        static let accordionOffset = 4...24
        static let leaderTimeout = 0.0...30.0
        static let borderWidth = 0.5...10.0
        static let glowRadius = 0.0...30.0
        static let glowOpacity = 0.0...1.0
    }
}
