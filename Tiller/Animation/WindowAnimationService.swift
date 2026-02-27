//
//  WindowAnimationService.swift
//  Tiller
//

import CoreGraphics
import CoreVideo
import Foundation
import os
import QuartzCore

nonisolated protocol WindowAnimationServiceProtocol {
    func animate(
        windowID: WindowID,
        pid: pid_t,
        from startFrame: CGRect,
        to targetFrame: CGRect,
        duration: TimeInterval
    ) async -> AnimationResult

    func animateBatch(
        _ animations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)],
        duration: TimeInterval
    ) async -> AnimationResult

    func cancelAnimation(for windowID: WindowID)
    func cancelAllAnimations()
    func isAnimating(_ windowID: WindowID) -> Bool

    /// Raise windows in z-order (first = back, last = front)
    func raiseWindowsInOrder(_ windows: [(windowID: WindowID, pid: pid_t)])

    /// Window IDs that rejected resize (size-set failed). Check after each tile.
    var resizeRejectedWindowIDs: Set<WindowID> { get }

    /// Clear the resize-rejected set after reclassification.
    func clearResizeRejected()
}

nonisolated final class WindowAnimationService: WindowAnimationServiceProtocol, @unchecked Sendable {
    private var displayLink: CVDisplayLink?
    private let positioner: WindowPositionerProtocol
    private let easing: EasingFunction

    private var activeAnimations: [UUID: AnimationState]
    private var windowToAnimationID: [WindowID: UUID]
    private var animationContinuations: [UUID: CheckedContinuation<AnimationResult, Never>]

    private let lock = NSLock()

    init(positioner: WindowPositionerProtocol = WindowPositioner(), easing: EasingFunction = .easeOutCubic) {
        self.positioner = positioner
        self.easing = easing
        self.activeAnimations = [:]
        self.windowToAnimationID = [:]
        self.animationContinuations = [:]
    }

    deinit {
        stopDisplayLink()
    }

    // MARK: - Public API

    func animate(
        windowID: WindowID,
        pid: pid_t,
        from startFrame: CGRect,
        to targetFrame: CGRect,
        duration: TimeInterval
    ) async -> AnimationResult {
        return await animateBatch(
            [(windowID: windowID, pid: pid, startFrame: startFrame, targetFrame: targetFrame)],
            duration: duration
        )
    }

    func animateBatch(
        _ animations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)],
        duration: TimeInterval
    ) async -> AnimationResult {
        guard !animations.isEmpty else {
            return .completed
        }

        // Fast path for instant positioning (duration = 0)
        if duration <= 0 {
            TillerLogger.debug("animation","Instant positioning (duration=0)")
            var successCount = 0
            for animation in animations {
                let result = positioner.setFrame(
                    animation.targetFrame,
                    for: animation.windowID,
                    pid: animation.pid
                )
                if case .success = result {
                    successCount += 1
                } else {
                    TillerLogger.animation.error("Failed to position window \(animation.windowID.rawValue)")
                }
            }
            TillerLogger.debug("animation","Instant positioning complete: \(successCount)/\(animations.count) succeeded")
            return .completed
        }

        // Cancel any existing animations for these windows
        for animation in animations {
            cancelAnimation(for: animation.windowID)
        }

        let animationID = UUID()
        let targets = animations.map { animation in
            WindowAnimationTarget(
                windowID: animation.windowID,
                pid: animation.pid,
                startFrame: animation.startFrame,
                endFrame: animation.targetFrame
            )
        }

        let state = AnimationState(
            targets: targets,
            startTime: CACurrentMediaTime(),
            duration: duration
        )

        return await withCheckedContinuation { continuation in
            lock.lock()
            activeAnimations[animationID] = state
            for target in targets {
                windowToAnimationID[target.windowID] = animationID
            }
            animationContinuations[animationID] = continuation
            lock.unlock()

            startDisplayLinkIfNeeded()
        }
    }

    func cancelAnimation(for windowID: WindowID) {
        lock.lock()
        defer { lock.unlock() }

        guard let animationID = windowToAnimationID[windowID],
              let state = activeAnimations[animationID] else {
            return
        }

        state.cancel()
    }

    func cancelAllAnimations() {
        lock.lock()
        let states = activeAnimations.values
        lock.unlock()

        for state in states {
            state.cancel()
        }
    }

    func isAnimating(_ windowID: WindowID) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let animationID = windowToAnimationID[windowID],
              let state = activeAnimations[animationID] else {
            return false
        }

        return !state.isCancelled && state.progress < 1.0
    }

    func raiseWindowsInOrder(_ windows: [(windowID: WindowID, pid: pid_t)]) {
        // Raise windows from back to front (first in list = backmost)
        for window in windows {
            _ = positioner.raiseWindow(window.windowID, pid: window.pid)
        }
    }

    var resizeRejectedWindowIDs: Set<WindowID> {
        (positioner as? WindowPositioner)?.resizeRejectedWindowIDs ?? []
    }

    func clearResizeRejected() {
        (positioner as? WindowPositioner)?.clearResizeRejected()
    }

    // MARK: - Display Link Management

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }

        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)

        guard let displayLink = link else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let service = Unmanaged<WindowAnimationService>.fromOpaque(userInfo).takeUnretainedValue()
            service.displayLinkCallback()
            return kCVReturnSuccess
        }

        CVDisplayLinkSetOutputCallback(
            displayLink,
            callback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        self.displayLink = displayLink
        CVDisplayLinkStart(displayLink)
    }

    private func stopDisplayLink() {
        guard let displayLink = displayLink else { return }
        CVDisplayLinkStop(displayLink)
        self.displayLink = nil
    }

    private func displayLinkCallback() {
        let currentTime = CACurrentMediaTime()

        lock.lock()
        let animationsToProcess = activeAnimations
        lock.unlock()

        var completedAnimations: [(UUID, AnimationResult)] = []

        for (animationID, state) in animationsToProcess {
            if state.isCancelled {
                completedAnimations.append((animationID, .cancelled))
                continue
            }

            let elapsed = currentTime - state.startTime
            let rawProgress = min(elapsed / state.duration, 1.0)
            let easedProgress = easing.apply(rawProgress)

            state.updateProgress(easedProgress)

            // Update all window positions (continue even if some fail)
            var successCount = 0
            for target in state.targets {
                let currentFrame = interpolateFrame(
                    from: target.startFrame,
                    to: target.endFrame,
                    progress: easedProgress
                )

                let result = positioner.setFrame(currentFrame, for: target.windowID, pid: target.pid)
                if case .success = result {
                    successCount += 1
                }
                // Continue with other windows even if one fails
            }

            if rawProgress >= 1.0 {
                completedAnimations.append((animationID, .completed))
            }
        }

        // Clean up completed animations
        for (animationID, result) in completedAnimations {
            lock.lock()
            if let state = activeAnimations.removeValue(forKey: animationID) {
                for target in state.targets {
                    windowToAnimationID.removeValue(forKey: target.windowID)
                }
            }
            let continuation = animationContinuations.removeValue(forKey: animationID)
            let shouldStopDisplayLink = activeAnimations.isEmpty
            lock.unlock()

            continuation?.resume(returning: result)

            if shouldStopDisplayLink {
                DispatchQueue.main.async { [weak self] in
                    self?.stopDisplayLinkIfIdle()
                }
            }
        }
    }

    private func stopDisplayLinkIfIdle() {
        lock.lock()
        let isEmpty = activeAnimations.isEmpty
        lock.unlock()

        if isEmpty {
            stopDisplayLink()
        }
    }
}
