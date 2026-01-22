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

    static let `default` = TillerConfig(
        margin: 8,
        padding: 8,
        accordionOffset: 16,
        floatingApps: []
    )

    enum ValidationRange {
        static let margin = 0...20
        static let padding = 0...20
        static let accordionOffset = 4...24
    }
}
