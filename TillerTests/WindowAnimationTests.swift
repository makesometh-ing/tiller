//
//  WindowAnimationTests.swift
//  TillerTests
//

import CoreGraphics
import Testing
@testable import Tiller

struct WindowAnimationTests {
    private let mockAnimationService: MockWindowAnimationService
    private let mockPositioner: MockWindowPositioner

    init() {
        mockAnimationService = MockWindowAnimationService()
        mockPositioner = MockWindowPositioner()
    }

    // MARK: - Easing Function Tests

    @Test func easingFunctionLinear() {
        let easing = EasingFunction.linear
        #expect(abs(easing.apply(0.0) - 0.0) <= 0.001)
        #expect(abs(easing.apply(0.5) - 0.5) <= 0.001)
        #expect(abs(easing.apply(1.0) - 1.0) <= 0.001)
    }

    @Test func easingFunctionEaseOutCubic() {
        let easing = EasingFunction.easeOutCubic
        #expect(abs(easing.apply(0.0) - 0.0) <= 0.001)
        #expect(abs(easing.apply(0.5) - 0.875) <= 0.001)  // 1 - pow(0.5, 3) = 0.875
        #expect(abs(easing.apply(1.0) - 1.0) <= 0.001)
    }

    @Test func easingFunctionEaseInOutCubic() {
        let easing = EasingFunction.easeInOutCubic
        #expect(abs(easing.apply(0.0) - 0.0) <= 0.001)
        #expect(abs(easing.apply(0.5) - 0.5) <= 0.001)
        #expect(abs(easing.apply(1.0) - 1.0) <= 0.001)
    }

    // MARK: - Frame Interpolation Tests

    @Test func interpolateFrameAtStart() {
        let from = CGRect(x: 0, y: 0, width: 100, height: 100)
        let to = CGRect(x: 200, y: 200, width: 400, height: 400)
        let result = interpolateFrame(from: from, to: to, progress: 0.0)

        #expect(abs(result.origin.x - 0) <= 0.001)
        #expect(abs(result.origin.y - 0) <= 0.001)
        #expect(abs(result.width - 100) <= 0.001)
        #expect(abs(result.height - 100) <= 0.001)
    }

    @Test func interpolateFrameAtEnd() {
        let from = CGRect(x: 0, y: 0, width: 100, height: 100)
        let to = CGRect(x: 200, y: 200, width: 400, height: 400)
        let result = interpolateFrame(from: from, to: to, progress: 1.0)

        #expect(abs(result.origin.x - 200) <= 0.001)
        #expect(abs(result.origin.y - 200) <= 0.001)
        #expect(abs(result.width - 400) <= 0.001)
        #expect(abs(result.height - 400) <= 0.001)
    }

    @Test func interpolateFrameAtMidpoint() {
        let from = CGRect(x: 0, y: 0, width: 100, height: 100)
        let to = CGRect(x: 200, y: 200, width: 400, height: 400)
        let result = interpolateFrame(from: from, to: to, progress: 0.5)

        #expect(abs(result.origin.x - 100) <= 0.001)
        #expect(abs(result.origin.y - 100) <= 0.001)
        #expect(abs(result.width - 250) <= 0.001)
        #expect(abs(result.height - 250) <= 0.001)
    }

    // MARK: - Animation Target Tests

    @Test func windowAnimationTargetEquality() {
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

        #expect(target1 == target2)
        #expect(target1 != target3)
    }


    // MARK: - Mock Animation Service Tests

    @Test func singleWindowAnimationCompletes() async {
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

        #expect(result == .completed)
        #expect(mockAnimationService.singleAnimationCalls.count == 1)
        #expect(mockAnimationService.singleAnimationCalls.first?.windowID == windowID)
        #expect(mockAnimationService.singleAnimationCalls.first?.startFrame == startFrame)
        #expect(mockAnimationService.singleAnimationCalls.first?.targetFrame == endFrame)
    }

    @Test func batchAnimationMovesAllWindows() async {
        let animations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)] = [
            (WindowID(rawValue: 1), 1234, CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 200, y: 0, width: 100, height: 100)),
            (WindowID(rawValue: 2), 1234, CGRect(x: 200, y: 0, width: 100, height: 100), CGRect(x: 400, y: 0, width: 100, height: 100)),
            (WindowID(rawValue: 3), 5678, CGRect(x: 400, y: 0, width: 100, height: 100), CGRect(x: 600, y: 0, width: 100, height: 100))
        ]

        let result = await mockAnimationService.animateBatch(animations, duration: 0.2)

        #expect(result == .completed)
        #expect(mockAnimationService.batchAnimationCalls.count == 1)
        #expect(mockAnimationService.batchAnimationCalls.first?.animations.count == 3)
    }

    @Test func animationCancellation() async {
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

        #expect(mockAnimationService.isAnimating(windowID))

        mockAnimationService.cancelAnimation(for: windowID)

        #expect(!mockAnimationService.isAnimating(windowID))
        #expect(mockAnimationService.cancelledWindows.contains(windowID))
    }

    @Test func cancelAllAnimations() async {
        mockAnimationService.cancelAllAnimations()
        #expect(mockAnimationService.cancelAllCalled)
    }

    @Test func mockAnimationServiceReset() async {
        let windowID = WindowID(rawValue: 1)

        _ = await mockAnimationService.animate(
            windowID: windowID,
            pid: 1234,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 200, y: 200, width: 400, height: 400),
            duration: 0.2
        )

        #expect(mockAnimationService.singleAnimationCalls.count == 1)

        mockAnimationService.reset()

        #expect(mockAnimationService.singleAnimationCalls.count == 0)
        #expect(mockAnimationService.batchAnimationCalls.count == 0)
        #expect(mockAnimationService.cancelledWindows.count == 0)
        #expect(!mockAnimationService.cancelAllCalled)
    }

    @Test func animationResultCanBeCancelled() async {
        mockAnimationService.resultToReturn = .cancelled

        let result = await mockAnimationService.animate(
            windowID: WindowID(rawValue: 1),
            pid: 1234,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 200, y: 200, width: 400, height: 400),
            duration: 0.2
        )

        #expect(result == .cancelled)
    }

    @Test func animationResultCanFail() async {
        let error = AnimationError.windowNotFound(WindowID(rawValue: 1))
        mockAnimationService.resultToReturn = .failed(error)

        let result = await mockAnimationService.animate(
            windowID: WindowID(rawValue: 1),
            pid: 1234,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 200, y: 200, width: 400, height: 400),
            duration: 0.2
        )

        #expect(result == .failed(error))
    }

    // MARK: - Mock Positioner Tests

    @Test func mockPositionerSetFrame() {
        let windowID = WindowID(rawValue: 1)
        let frame = CGRect(x: 100, y: 100, width: 400, height: 300)

        let result = mockPositioner.setFrame(frame, for: windowID, pid: 1234)

        switch result {
        case .success:
            break  // Expected
        case .failure(let error):
            Issue.record("Expected success but got failure: \(error)")
        }
        #expect(mockPositioner.setFrameCalls.count == 1)
        #expect(mockPositioner.setFrameCalls.first?.windowID == windowID)
        #expect(mockPositioner.setFrameCalls.first?.frame == frame)
        #expect(mockPositioner.setFrameCalls.first?.pid == 1234)
    }

    @Test func mockPositionerFailure() {
        let windowID = WindowID(rawValue: 1)
        mockPositioner.resultToReturn = .failure(.windowElementNotFound(windowID))

        let result = mockPositioner.setFrame(
            CGRect(x: 100, y: 100, width: 400, height: 300),
            for: windowID,
            pid: 1234
        )

        if case .failure(let error) = result {
            #expect(error == .windowElementNotFound(windowID))
        } else {
            Issue.record("Expected failure result")
        }
    }

    @Test func mockPositionerReset() {
        let windowID = WindowID(rawValue: 1)
        _ = mockPositioner.setFrame(CGRect(x: 100, y: 100, width: 400, height: 300), for: windowID, pid: 1234)

        #expect(mockPositioner.setFrameCalls.count == 1)

        mockPositioner.reset()

        #expect(mockPositioner.setFrameCalls.count == 0)
    }

    // MARK: - Animation Error Tests

    @Test func animationErrorEquality() {
        let error1 = AnimationError.windowNotFound(WindowID(rawValue: 1))
        let error2 = AnimationError.windowNotFound(WindowID(rawValue: 1))
        let error3 = AnimationError.windowNotFound(WindowID(rawValue: 2))
        let error4 = AnimationError.accessibilityError(Int32(-25204))

        #expect(error1 == error2)
        #expect(error1 != error3)
        #expect(error1 != error4)
    }

    // MARK: - Animation Result Tests

    @Test func animationResultEquality() {
        #expect(AnimationResult.completed == AnimationResult.completed)
        #expect(AnimationResult.cancelled == AnimationResult.cancelled)
        #expect(AnimationResult.completed != AnimationResult.cancelled)

        let error = AnimationError.windowNotFound(WindowID(rawValue: 1))
        #expect(AnimationResult.failed(error) == AnimationResult.failed(error))
    }

    // MARK: - Empty Batch Animation Tests

    @Test func emptyBatchAnimationCompletes() async {
        let result = await mockAnimationService.animateBatch([], duration: 0.2)
        #expect(result == .completed)
    }

    // MARK: - Current Frame Tracking Tests

    @Test func mockServiceTracksCurrentFrame() async {
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
        #expect(currentFrame == endFrame)
    }

    // MARK: - Real WindowAnimationService Integration Tests
    // These test the actual AnimationState through the real service

    @Test func realServiceSingleAnimation() async {
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

        #expect(result == .completed)
        // Verify positioner was called multiple times (frame updates)
        #expect(positioner.setFrameCalls.count > 0)
        // Verify final frame was set
        if let lastCall = positioner.setFrameCalls.last {
            #expect(lastCall.windowID == windowID)
            // Final frame should be close to endFrame
            #expect(abs(lastCall.frame.origin.x - endFrame.origin.x) <= 1)
            #expect(abs(lastCall.frame.origin.y - endFrame.origin.y) <= 1)
        }
    }

    @Test func realServiceBatchAnimation() async {
        let positioner = MockWindowPositioner()
        let service = WindowAnimationService(positioner: positioner, easing: .linear)

        let animations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)] = [
            (WindowID(rawValue: 1), 1234, CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 100, y: 0, width: 100, height: 100)),
            (WindowID(rawValue: 2), 1234, CGRect(x: 100, y: 0, width: 100, height: 100), CGRect(x: 200, y: 0, width: 100, height: 100))
        ]

        let result = await service.animateBatch(animations, duration: 0.05)

        #expect(result == .completed)
        // Verify both windows were animated
        let window1Calls = positioner.setFrameCalls.filter { $0.windowID == WindowID(rawValue: 1) }
        let window2Calls = positioner.setFrameCalls.filter { $0.windowID == WindowID(rawValue: 2) }
        #expect(window1Calls.count > 0)
        #expect(window2Calls.count > 0)
    }

    @Test func realServiceContinuesOnPositionerError() async {
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
        #expect(result == .completed)
        // Positioner was still called (multiple times during animation)
        #expect(positioner.setFrameCalls.count > 0)
    }

    @Test func realServiceIsAnimatingDuringAnimation() async {
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
        #expect(service.isAnimating(windowID))

        // Wait for completion
        _ = await task.value

        // Should no longer be animating
        #expect(!service.isAnimating(windowID))
    }

    @Test func realServiceCancellation() async {
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

        #expect(result == .cancelled)
    }
}
