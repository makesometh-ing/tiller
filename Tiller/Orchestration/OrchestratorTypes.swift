//
//  OrchestratorTypes.swift
//  Tiller
//

import Foundation

nonisolated struct OrchestratorConfig: Equatable, Sendable {
    let debounceDelay: TimeInterval
    let animationDuration: TimeInterval
    let animateOnInitialTile: Bool

    static let `default` = OrchestratorConfig(
        debounceDelay: 0.05,
        animationDuration: 0.05,
        animateOnInitialTile: false
    )
}

nonisolated enum TilingResult: Equatable, Sendable {
    case success(tiledCount: Int)
    case noWindowsToTile
    case cancelled
    case failed(reason: String)
}
