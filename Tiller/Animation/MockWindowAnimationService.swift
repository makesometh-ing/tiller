//
//  MockWindowAnimationService.swift
//  Tiller
//

import ApplicationServices
import CoreGraphics
import Foundation

final class MockWindowAnimationService: WindowAnimationServiceProtocol {
    // Track all animation calls for testing
    struct AnimationCall: Equatable {
        let windowID: WindowID
        let pid: pid_t
        let startFrame: CGRect
        let targetFrame: CGRect
        let duration: TimeInterval
    }

    struct BatchAnimationCall: Equatable {
        let animations: [AnimationCall]
        let duration: TimeInterval

        static func == (lhs: BatchAnimationCall, rhs: BatchAnimationCall) -> Bool {
            lhs.animations == rhs.animations && lhs.duration == rhs.duration
        }
    }

    private(set) var singleAnimationCalls: [AnimationCall] = []
    private(set) var batchAnimationCalls: [BatchAnimationCall] = []
    private(set) var cancelledWindows: [WindowID] = []
    private(set) var cancelAllCalled = false
    private(set) var raiseOrderCalls: [[(windowID: WindowID, pid: pid_t)]] = []

    private var animatingWindows: Set<WindowID> = []
    private var currentFrames: [WindowID: CGRect] = [:]

    // Configurable behavior for tests
    var resultToReturn: AnimationResult = .completed
    var shouldCompleteInstantly: Bool = true
    var animationDelay: TimeInterval = 0

    func animate(
        windowID: WindowID,
        pid: pid_t,
        from startFrame: CGRect,
        to targetFrame: CGRect,
        duration: TimeInterval
    ) async -> AnimationResult {
        let call = AnimationCall(
            windowID: windowID,
            pid: pid,
            startFrame: startFrame,
            targetFrame: targetFrame,
            duration: duration
        )
        singleAnimationCalls.append(call)

        animatingWindows.insert(windowID)
        currentFrames[windowID] = startFrame

        if shouldCompleteInstantly {
            currentFrames[windowID] = targetFrame
            animatingWindows.remove(windowID)
            return resultToReturn
        }

        if animationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(animationDelay * 1_000_000_000))
        }

        currentFrames[windowID] = targetFrame
        animatingWindows.remove(windowID)
        return resultToReturn
    }

    func animateBatch(
        _ animations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)],
        duration: TimeInterval
    ) async -> AnimationResult {
        let calls = animations.map { animation in
            AnimationCall(
                windowID: animation.windowID,
                pid: animation.pid,
                startFrame: animation.startFrame,
                targetFrame: animation.targetFrame,
                duration: duration
            )
        }

        batchAnimationCalls.append(BatchAnimationCall(animations: calls, duration: duration))

        for animation in animations {
            animatingWindows.insert(animation.windowID)
            currentFrames[animation.windowID] = animation.startFrame
        }

        if shouldCompleteInstantly {
            for animation in animations {
                currentFrames[animation.windowID] = animation.targetFrame
                animatingWindows.remove(animation.windowID)
            }
            return resultToReturn
        }

        if animationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(animationDelay * 1_000_000_000))
        }

        for animation in animations {
            currentFrames[animation.windowID] = animation.targetFrame
            animatingWindows.remove(animation.windowID)
        }
        return resultToReturn
    }

    func cancelAnimation(for windowID: WindowID) {
        cancelledWindows.append(windowID)
        animatingWindows.remove(windowID)
    }

    func cancelAllAnimations() {
        cancelAllCalled = true
        animatingWindows.removeAll()
    }

    func isAnimating(_ windowID: WindowID) -> Bool {
        return animatingWindows.contains(windowID)
    }

    func raiseWindowsInOrder(_ windows: [(windowID: WindowID, pid: pid_t)]) {
        raiseOrderCalls.append(windows)
    }

    // Configurable resize-rejected set for tests
    var _mockResizeRejectedWindowIDs: Set<WindowID> = []

    var resizeRejectedWindowIDs: Set<WindowID> {
        return _mockResizeRejectedWindowIDs
    }

    func clearResizeRejected() {
        _mockResizeRejectedWindowIDs.removeAll()
    }

    // MARK: - Test Helpers

    func reset() {
        singleAnimationCalls.removeAll()
        batchAnimationCalls.removeAll()
        cancelledWindows.removeAll()
        cancelAllCalled = false
        raiseOrderCalls.removeAll()
        animatingWindows.removeAll()
        currentFrames.removeAll()
        resultToReturn = .completed
        shouldCompleteInstantly = true
        animationDelay = 0
        _mockResizeRejectedWindowIDs.removeAll()
    }

    func getCurrentFrame(for windowID: WindowID) -> CGRect? {
        return currentFrames[windowID]
    }

    var totalAnimationCount: Int {
        return singleAnimationCalls.count + batchAnimationCalls.reduce(0) { $0 + $1.animations.count }
    }
}

// MARK: - Mock Positioner for Testing

final class MockWindowPositioner: WindowPositionerProtocol {
    struct SetFrameCall: Equatable {
        let frame: CGRect
        let windowID: WindowID
        let pid: pid_t
    }

    private(set) var setFrameCalls: [SetFrameCall] = []
    private(set) var getWindowElementCalls: [(WindowID, pid_t)] = []

    var resultToReturn: Result<Void, AnimationError> = .success(())
    var windowElementToReturn: AXUIElement?

    func setFrame(_ frame: CGRect, for windowID: WindowID, pid: pid_t) -> Result<Void, AnimationError> {
        setFrameCalls.append(SetFrameCall(frame: frame, windowID: windowID, pid: pid))
        return resultToReturn
    }

    func getWindowElement(for windowID: WindowID, pid: pid_t) -> AXUIElement? {
        getWindowElementCalls.append((windowID, pid))
        return windowElementToReturn
    }

    func raiseWindow(_ windowID: WindowID, pid: pid_t) -> Result<Void, AnimationError> {
        return .success(())
    }

    func reset() {
        setFrameCalls.removeAll()
        getWindowElementCalls.removeAll()
        resultToReturn = .success(())
        windowElementToReturn = nil
    }
}
