//
//  WindowAnimationTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

@MainActor
final class WindowAnimationTests: XCTestCase {
    private var mockAnimationService: MockWindowAnimationService!
    private var mockPositioner: MockWindowPositioner!

    override func setUp() async throws {
        try await super.setUp()
        mockAnimationService = MockWindowAnimationService()
        mockPositioner = MockWindowPositioner()
    }

    override func tearDown() async throws {
        mockAnimationService = nil
        mockPositioner = nil
        try await super.tearDown()
    }

    // MARK: - Easing Function Tests

    func testEasingFunctionLinear() {
        let easing = EasingFunction.linear
        XCTAssertEqual(easing.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(easing.apply(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(easing.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testEasingFunctionEaseOutCubic() {
        let easing = EasingFunction.easeOutCubic
        XCTAssertEqual(easing.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(easing.apply(0.5), 0.875, accuracy: 0.001)  // 1 - pow(0.5, 3) = 0.875
        XCTAssertEqual(easing.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testEasingFunctionEaseInOutCubic() {
        let easing = EasingFunction.easeInOutCubic
        XCTAssertEqual(easing.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(easing.apply(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(easing.apply(1.0), 1.0, accuracy: 0.001)
    }

    // MARK: - Frame Interpolation Tests

    func testInterpolateFrameAtStart() {
        let from = CGRect(x: 0, y: 0, width: 100, height: 100)
        let to = CGRect(x: 200, y: 200, width: 400, height: 400)
        let result = interpolateFrame(from: from, to: to, progress: 0.0)

        XCTAssertEqual(result.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(result.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(result.width, 100, accuracy: 0.001)
        XCTAssertEqual(result.height, 100, accuracy: 0.001)
    }

    func testInterpolateFrameAtEnd() {
        let from = CGRect(x: 0, y: 0, width: 100, height: 100)
        let to = CGRect(x: 200, y: 200, width: 400, height: 400)
        let result = interpolateFrame(from: from, to: to, progress: 1.0)

        XCTAssertEqual(result.origin.x, 200, accuracy: 0.001)
        XCTAssertEqual(result.origin.y, 200, accuracy: 0.001)
        XCTAssertEqual(result.width, 400, accuracy: 0.001)
        XCTAssertEqual(result.height, 400, accuracy: 0.001)
    }

    func testInterpolateFrameAtMidpoint() {
        let from = CGRect(x: 0, y: 0, width: 100, height: 100)
        let to = CGRect(x: 200, y: 200, width: 400, height: 400)
        let result = interpolateFrame(from: from, to: to, progress: 0.5)

        XCTAssertEqual(result.origin.x, 100, accuracy: 0.001)
        XCTAssertEqual(result.origin.y, 100, accuracy: 0.001)
        XCTAssertEqual(result.width, 250, accuracy: 0.001)
        XCTAssertEqual(result.height, 250, accuracy: 0.001)
    }

    // MARK: - Animation Target Tests

    func testWindowAnimationTargetEquality() {
        let target1 = WindowAnimationTarget(
            windowID: WindowID(rawValue: 1),
            pid: 1234,
            startFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            endFrame: CGRect(x: 200, y: 200, width: 400, height: 400)
        )
        let target2 = WindowAnimationTarget(
            windowID: WindowID(rawValue: 1),
            pid: 1234,
            startFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            endFrame: CGRect(x: 200, y: 200, width: 400, height: 400)
        )
        let target3 = WindowAnimationTarget(
            windowID: WindowID(rawValue: 2),
            pid: 1234,
            startFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            endFrame: CGRect(x: 200, y: 200, width: 400, height: 400)
        )

        XCTAssertEqual(target1, target2)
        XCTAssertNotEqual(target1, target3)
    }


    // MARK: - Mock Animation Service Tests

    func testSingleWindowAnimationCompletes() async {
        let windowID = WindowID(rawValue: 1)
        let startFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let endFrame = CGRect(x: 200, y: 200, width: 400, height: 400)

        let result = await mockAnimationService.animate(
            windowID: windowID,
            pid: 1234,
            from: startFrame,
            to: endFrame,
            duration: 0.2
        )

        XCTAssertEqual(result, .completed)
        XCTAssertEqual(mockAnimationService.singleAnimationCalls.count, 1)
        XCTAssertEqual(mockAnimationService.singleAnimationCalls.first?.windowID, windowID)
        XCTAssertEqual(mockAnimationService.singleAnimationCalls.first?.startFrame, startFrame)
        XCTAssertEqual(mockAnimationService.singleAnimationCalls.first?.targetFrame, endFrame)
    }

    func testBatchAnimationMovesAllWindows() async {
        let animations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)] = [
            (WindowID(rawValue: 1), 1234, CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 200, y: 0, width: 100, height: 100)),
            (WindowID(rawValue: 2), 1234, CGRect(x: 200, y: 0, width: 100, height: 100), CGRect(x: 400, y: 0, width: 100, height: 100)),
            (WindowID(rawValue: 3), 5678, CGRect(x: 400, y: 0, width: 100, height: 100), CGRect(x: 600, y: 0, width: 100, height: 100))
        ]

        let result = await mockAnimationService.animateBatch(animations, duration: 0.2)

        XCTAssertEqual(result, .completed)
        XCTAssertEqual(mockAnimationService.batchAnimationCalls.count, 1)
        XCTAssertEqual(mockAnimationService.batchAnimationCalls.first?.animations.count, 3)
    }

    func testAnimationCancellation() async {
        let windowID = WindowID(rawValue: 1)

        mockAnimationService.shouldCompleteInstantly = false
        mockAnimationService.animationDelay = 0.5

        Task {
            _ = await mockAnimationService.animate(
                windowID: windowID,
                pid: 1234,
                from: CGRect(x: 0, y: 0, width: 100, height: 100),
                to: CGRect(x: 200, y: 200, width: 400, height: 400),
                duration: 0.2
            )
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertTrue(mockAnimationService.isAnimating(windowID))

        mockAnimationService.cancelAnimation(for: windowID)

        XCTAssertFalse(mockAnimationService.isAnimating(windowID))
        XCTAssertTrue(mockAnimationService.cancelledWindows.contains(windowID))
    }

    func testCancelAllAnimations() async {
        mockAnimationService.cancelAllAnimations()
        XCTAssertTrue(mockAnimationService.cancelAllCalled)
    }

    func testMockAnimationServiceReset() async {
        let windowID = WindowID(rawValue: 1)

        _ = await mockAnimationService.animate(
            windowID: windowID,
            pid: 1234,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 200, y: 200, width: 400, height: 400),
            duration: 0.2
        )

        XCTAssertEqual(mockAnimationService.singleAnimationCalls.count, 1)

        mockAnimationService.reset()

        XCTAssertEqual(mockAnimationService.singleAnimationCalls.count, 0)
        XCTAssertEqual(mockAnimationService.batchAnimationCalls.count, 0)
        XCTAssertEqual(mockAnimationService.cancelledWindows.count, 0)
        XCTAssertFalse(mockAnimationService.cancelAllCalled)
    }

    func testAnimationResultCanBeCancelled() async {
        mockAnimationService.resultToReturn = .cancelled

        let result = await mockAnimationService.animate(
            windowID: WindowID(rawValue: 1),
            pid: 1234,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 200, y: 200, width: 400, height: 400),
            duration: 0.2
        )

        XCTAssertEqual(result, .cancelled)
    }

    func testAnimationResultCanFail() async {
        let error = AnimationError.windowNotFound(WindowID(rawValue: 1))
        mockAnimationService.resultToReturn = .failed(error)

        let result = await mockAnimationService.animate(
            windowID: WindowID(rawValue: 1),
            pid: 1234,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 200, y: 200, width: 400, height: 400),
            duration: 0.2
        )

        XCTAssertEqual(result, .failed(error))
    }

    // MARK: - Mock Positioner Tests

    func testMockPositionerSetFrame() {
        let windowID = WindowID(rawValue: 1)
        let frame = CGRect(x: 100, y: 100, width: 400, height: 300)

        let result = mockPositioner.setFrame(frame, for: windowID, pid: 1234)

        switch result {
        case .success:
            break  // Expected
        case .failure(let error):
            XCTFail("Expected success but got failure: \(error)")
        }
        XCTAssertEqual(mockPositioner.setFrameCalls.count, 1)
        XCTAssertEqual(mockPositioner.setFrameCalls.first?.windowID, windowID)
        XCTAssertEqual(mockPositioner.setFrameCalls.first?.frame, frame)
        XCTAssertEqual(mockPositioner.setFrameCalls.first?.pid, 1234)
    }

    func testMockPositionerFailure() {
        let windowID = WindowID(rawValue: 1)
        mockPositioner.resultToReturn = .failure(.windowElementNotFound(windowID))

        let result = mockPositioner.setFrame(
            CGRect(x: 100, y: 100, width: 400, height: 300),
            for: windowID,
            pid: 1234
        )

        if case .failure(let error) = result {
            XCTAssertEqual(error, .windowElementNotFound(windowID))
        } else {
            XCTFail("Expected failure result")
        }
    }

    func testMockPositionerReset() {
        let windowID = WindowID(rawValue: 1)
        _ = mockPositioner.setFrame(CGRect(x: 100, y: 100, width: 400, height: 300), for: windowID, pid: 1234)

        XCTAssertEqual(mockPositioner.setFrameCalls.count, 1)

        mockPositioner.reset()

        XCTAssertEqual(mockPositioner.setFrameCalls.count, 0)
    }

    // MARK: - Animation Error Tests

    func testAnimationErrorEquality() {
        let error1 = AnimationError.windowNotFound(WindowID(rawValue: 1))
        let error2 = AnimationError.windowNotFound(WindowID(rawValue: 1))
        let error3 = AnimationError.windowNotFound(WindowID(rawValue: 2))
        let error4 = AnimationError.accessibilityError(Int32(-25204))

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error1, error4)
    }

    // MARK: - Animation Result Tests

    func testAnimationResultEquality() {
        XCTAssertEqual(AnimationResult.completed, AnimationResult.completed)
        XCTAssertEqual(AnimationResult.cancelled, AnimationResult.cancelled)
        XCTAssertNotEqual(AnimationResult.completed, AnimationResult.cancelled)

        let error = AnimationError.windowNotFound(WindowID(rawValue: 1))
        XCTAssertEqual(AnimationResult.failed(error), AnimationResult.failed(error))
    }

    // MARK: - Empty Batch Animation Tests

    func testEmptyBatchAnimationCompletes() async {
        let result = await mockAnimationService.animateBatch([], duration: 0.2)
        XCTAssertEqual(result, .completed)
    }

    // MARK: - Current Frame Tracking Tests

    func testMockServiceTracksCurrentFrame() async {
        let windowID = WindowID(rawValue: 1)
        let startFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let endFrame = CGRect(x: 200, y: 200, width: 400, height: 400)

        _ = await mockAnimationService.animate(
            windowID: windowID,
            pid: 1234,
            from: startFrame,
            to: endFrame,
            duration: 0.2
        )

        let currentFrame = mockAnimationService.getCurrentFrame(for: windowID)
        XCTAssertEqual(currentFrame, endFrame)
    }

    // MARK: - Real WindowAnimationService Integration Tests
    // These test the actual AnimationState through the real service

    func testRealServiceSingleAnimation() async {
        let positioner = MockWindowPositioner()
        let service = WindowAnimationService(positioner: positioner, easing: .linear)

        let windowID = WindowID(rawValue: 1)
        let startFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let endFrame = CGRect(x: 200, y: 200, width: 400, height: 400)

        let result = await service.animate(
            windowID: windowID,
            pid: 1234,
            from: startFrame,
            to: endFrame,
            duration: 0.05  // Short duration for test
        )

        XCTAssertEqual(result, .completed)
        // Verify positioner was called multiple times (frame updates)
        XCTAssertGreaterThan(positioner.setFrameCalls.count, 0)
        // Verify final frame was set
        if let lastCall = positioner.setFrameCalls.last {
            XCTAssertEqual(lastCall.windowID, windowID)
            // Final frame should be close to endFrame
            XCTAssertEqual(lastCall.frame.origin.x, endFrame.origin.x, accuracy: 1)
            XCTAssertEqual(lastCall.frame.origin.y, endFrame.origin.y, accuracy: 1)
        }
    }

    func testRealServiceBatchAnimation() async {
        let positioner = MockWindowPositioner()
        let service = WindowAnimationService(positioner: positioner, easing: .linear)

        let animations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)] = [
            (WindowID(rawValue: 1), 1234, CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 100, y: 0, width: 100, height: 100)),
            (WindowID(rawValue: 2), 1234, CGRect(x: 100, y: 0, width: 100, height: 100), CGRect(x: 200, y: 0, width: 100, height: 100))
        ]

        let result = await service.animateBatch(animations, duration: 0.05)

        XCTAssertEqual(result, .completed)
        // Verify both windows were animated
        let window1Calls = positioner.setFrameCalls.filter { $0.windowID == WindowID(rawValue: 1) }
        let window2Calls = positioner.setFrameCalls.filter { $0.windowID == WindowID(rawValue: 2) }
        XCTAssertGreaterThan(window1Calls.count, 0)
        XCTAssertGreaterThan(window2Calls.count, 0)
    }

    func testRealServiceContinuesOnPositionerError() async {
        // Animation continues even if positioner fails (for robustness)
        let positioner = MockWindowPositioner()
        let windowID = WindowID(rawValue: 1)
        positioner.resultToReturn = .failure(.windowElementNotFound(windowID))

        let service = WindowAnimationService(positioner: positioner, easing: .linear)

        let result = await service.animate(
            windowID: windowID,
            pid: 1234,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 200, y: 200, width: 400, height: 400),
            duration: 0.05
        )

        // Animation completes even if positioning fails (we don't stop other windows)
        XCTAssertEqual(result, .completed)
        // Positioner was still called (multiple times during animation)
        XCTAssertGreaterThan(positioner.setFrameCalls.count, 0)
    }

    func testRealServiceIsAnimatingDuringAnimation() async {
        let positioner = MockWindowPositioner()
        let service = WindowAnimationService(positioner: positioner, easing: .linear)
        let windowID = WindowID(rawValue: 1)

        // Start animation but don't await it
        let task = Task {
            await service.animate(
                windowID: windowID,
                pid: 1234,
                from: CGRect(x: 0, y: 0, width: 100, height: 100),
                to: CGRect(x: 200, y: 200, width: 400, height: 400),
                duration: 0.1
            )
        }

        // Give it time to start
        try? await Task.sleep(nanoseconds: 20_000_000)

        // Should be animating
        XCTAssertTrue(service.isAnimating(windowID))

        // Wait for completion
        _ = await task.value

        // Should no longer be animating
        XCTAssertFalse(service.isAnimating(windowID))
    }

    func testRealServiceCancellation() async {
        let positioner = MockWindowPositioner()
        let service = WindowAnimationService(positioner: positioner, easing: .linear)
        let windowID = WindowID(rawValue: 1)

        // Start a longer animation
        let task = Task {
            await service.animate(
                windowID: windowID,
                pid: 1234,
                from: CGRect(x: 0, y: 0, width: 100, height: 100),
                to: CGRect(x: 200, y: 200, width: 400, height: 400),
                duration: 0.5
            )
        }

        // Wait for animation to start
        try? await Task.sleep(nanoseconds: 20_000_000)

        // Cancel it
        service.cancelAnimation(for: windowID)

        // Wait for result
        let result = await task.value

        XCTAssertEqual(result, .cancelled)
    }
}
