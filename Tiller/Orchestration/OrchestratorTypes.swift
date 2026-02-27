//
//  OrchestratorTypes.swift
//  Tiller
//

import Foundation

struct OrchestratorConfig: Equatable, Sendable {
    let debounceDelay: TimeInterval
    let animationDuration: TimeInterval
    let animateOnInitialTile: Bool

    static let `default` = OrchestratorConfig(
        debounceDelay: 0.05,
        animationDuration: 0.15,
        animateOnInitialTile: false
    )
}

enum TilingResult: Equatable, Sendable {
    case success(tiledCount: Int)
    case noWindowsToTile
    case cancelled
    case failed(reason: String)
}
