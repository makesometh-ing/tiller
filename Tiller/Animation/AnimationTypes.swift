//
//  AnimationTypes.swift
//  Tiller
//

import CoreGraphics
import Foundation

struct WindowAnimationTarget: Sendable, Equatable {
    let windowID: WindowID
    let pid: pid_t
    let startFrame: CGRect
    let endFrame: CGRect
}

final class AnimationState: @unchecked Sendable {
    let targets: [WindowAnimationTarget]
    let startTime: CFTimeInterval
    let duration: CFTimeInterval

    private let lock = NSLock()
    private var _progress: Double = 0.0
    private var _isCancelled: Bool = false

    var progress: Double {
        lock.lock()
        defer { lock.unlock() }
        return _progress
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }

    init(targets: [WindowAnimationTarget], startTime: CFTimeInterval, duration: CFTimeInterval) {
        self.targets = targets
        self.startTime = startTime
        self.duration = duration
    }

    func updateProgress(_ newProgress: Double) {
        lock.lock()
        defer { lock.unlock() }
        _progress = newProgress
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        _isCancelled = true
    }
}

enum EasingFunction: Sendable {
    case linear
    case easeOutCubic
    case easeInOutCubic

    func apply(_ t: Double) -> Double {
        switch self {
        case .linear:
            return t
        case .easeOutCubic:
            return 1 - pow(1 - t, 3)
        case .easeInOutCubic:
            if t < 0.5 {
                return 4 * t * t * t
            } else {
                return 1 - pow(-2 * t + 2, 3) / 2
            }
        }
    }
}

enum AnimationError: Error, Equatable {
    case windowNotFound(WindowID)
    case accessibilityError(Int32)  // AXError raw value
    case windowElementNotFound(WindowID)
    case animationAlreadyInProgress(WindowID)
}

enum AnimationResult: Equatable {
    case completed
    case cancelled
    case failed(AnimationError)
}

func interpolateFrame(from: CGRect, to: CGRect, progress: Double) -> CGRect {
    CGRect(
        x: from.origin.x + (to.origin.x - from.origin.x) * progress,
        y: from.origin.y + (to.origin.y - from.origin.y) * progress,
        width: from.width + (to.width - from.width) * progress,
        height: from.height + (to.height - from.height) * progress
    )
}
