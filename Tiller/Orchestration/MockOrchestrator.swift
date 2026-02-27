//
//  MockOrchestrator.swift
//  Tiller
//

import Foundation

/// Mock orchestrator for integration tests. Tracks start/stop/retile calls.
final class MockOrchestrator {

    // MARK: - Call Tracking

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var performTileCallCount = 0
    private(set) var allTileResults: [TilingResult] = []

    // MARK: - Configurable Behavior

    var resultToReturn: TilingResult = .success(tiledCount: 0)
    var isRunning: Bool = false

    // MARK: - Public API

    func start() async {
        startCallCount += 1
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }

    @discardableResult
    func performTile() async -> TilingResult {
        performTileCallCount += 1
        allTileResults.append(resultToReturn)
        return resultToReturn
    }

    // MARK: - Test Helpers

    func reset() {
        startCallCount = 0
        stopCallCount = 0
        performTileCallCount = 0
        allTileResults = []
        resultToReturn = .success(tiledCount: 0)
        isRunning = false
    }
}
