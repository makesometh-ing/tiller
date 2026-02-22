//
//  TillerConfig.swift
//  Tiller
//

import Foundation

struct TillerConfig: Codable, Equatable, Sendable {
    var margin: Int
    var padding: Int
    var accordionOffset: Int
    var leaderTimeout: Double = 5.0
    var floatingApps: [String]
    var logLocation: String?

    init(
        margin: Int,
        padding: Int,
        accordionOffset: Int,
        leaderTimeout: Double = 5.0,
        floatingApps: [String],
        logLocation: String? = nil
    ) {
        self.margin = margin
        self.padding = padding
        self.accordionOffset = accordionOffset
        self.leaderTimeout = leaderTimeout
        self.floatingApps = floatingApps
        self.logLocation = logLocation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        margin = try container.decode(Int.self, forKey: .margin)
        padding = try container.decode(Int.self, forKey: .padding)
        accordionOffset = try container.decode(Int.self, forKey: .accordionOffset)
        leaderTimeout = try container.decodeIfPresent(Double.self, forKey: .leaderTimeout) ?? 5.0
        floatingApps = try container.decode([String].self, forKey: .floatingApps)
        logLocation = try container.decodeIfPresent(String.self, forKey: .logLocation)
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
        logLocation: nil  // nil = use default: ~/.tiller/logs/tiller-debug.log
    )

    enum ValidationRange {
        static let margin = 0...20
        static let padding = 0...20
        static let accordionOffset = 4...24
        static let leaderTimeout = 0.0...30.0
    }
}
