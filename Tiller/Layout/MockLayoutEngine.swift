//
//  MockLayoutEngine.swift
//  Tiller
//

import CoreGraphics

/// Test mock for LayoutEngineProtocol that tracks calls and returns configurable results.
final class MockLayoutEngine: LayoutEngineProtocol, @unchecked Sendable {

    // MARK: - Call Tracking

    private(set) var calculateCallCount = 0
    private(set) var lastInput: LayoutInput?
    private(set) var allInputs: [LayoutInput] = []

    // MARK: - Configurable Result

    var resultToReturn = LayoutResult(placements: [])

    // MARK: - LayoutEngineProtocol

    func calculate(input: LayoutInput) -> LayoutResult {
        calculateCallCount += 1
        lastInput = input
        allInputs.append(input)
        return resultToReturn
    }

    // MARK: - Test Helpers

    func reset() {
        calculateCallCount = 0
        lastInput = nil
        allInputs = []
        resultToReturn = LayoutResult(placements: [])
    }
}
