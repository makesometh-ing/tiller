//
//  TillerConfig.swift
//  Tiller
//

import Foundation

struct TillerConfig: Codable, Equatable, Sendable {
    var margin: Int
    var padding: Int
    var accordionOffset: Int
    var floatingApps: [String]
    var logLocation: String?

    static let defaultLogPath: String = {
        let home = NSHomeDirectory()
        return (home as NSString).appendingPathComponent(".tiller/logs/tiller-debug.log")
    }()

    static let `default` = TillerConfig(
        margin: 8,
        padding: 8,
        accordionOffset: 16,
        floatingApps: [
            "pro.betterdisplay.BetterDisplay"  // Overlay/utility windows that can't be positioned
        ],
        logLocation: nil  // nil = use default: ~/.tiller/logs/tiller-debug.log
    )

    enum ValidationRange {
        static let margin = 0...20
        static let padding = 0...20
        static let accordionOffset = 4...24
    }
}
