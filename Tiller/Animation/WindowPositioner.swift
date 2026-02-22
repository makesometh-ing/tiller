//
//  WindowPositioner.swift
//  Tiller
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import os

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

protocol WindowPositionerProtocol {
    func setFrame(_ frame: CGRect, for windowID: WindowID, pid: pid_t) -> Result<Void, AnimationError>
    func raiseWindow(_ windowID: WindowID, pid: pid_t) -> Result<Void, AnimationError>
    func getWindowElement(for windowID: WindowID, pid: pid_t) -> AXUIElement?
}

final class WindowPositioner: WindowPositionerProtocol {
    private var windowElementCache: [WindowID: AXUIElement] = [:]
    private var isTrustedCache: Bool?
    private var lastTrustedCheck: Date?

    /// Windows where size-set was rejected. Thread-safe (written from display link thread).
    private let _resizeRejectedLock = NSLock()
    private var _resizeRejectedWindowIDs: Set<WindowID> = []

    /// Returns the set of window IDs that rejected resize since last clear.
    var resizeRejectedWindowIDs: Set<WindowID> {
        _resizeRejectedLock.lock()
        defer { _resizeRejectedLock.unlock() }
        return _resizeRejectedWindowIDs
    }

    /// Clears the resize-rejected set (called by orchestrator after reclassification).
    func clearResizeRejected() {
        _resizeRejectedLock.lock()
        _resizeRejectedWindowIDs.removeAll()
        _resizeRejectedLock.unlock()
    }

    func setFrame(_ frame: CGRect, for windowID: WindowID, pid: pid_t) -> Result<Void, AnimationError> {
        guard let windowElement = getWindowElement(for: windowID, pid: pid) else {
            return .failure(.windowElementNotFound(windowID))
        }

        // Check if window is minimized - don't position minimized windows
        var minimizedRef: CFTypeRef?
        let minimizedResult = AXUIElementCopyAttributeValue(
            windowElement,
            kAXMinimizedAttribute as CFString,
            &minimizedRef
        )
        if minimizedResult == .success,
           let isMinimized = minimizedRef as? Bool,
           isMinimized {
            TillerLogger.debug("animation", "Skipping minimized window \(windowID.rawValue)")
            return .success(())  // Treat as success but don't position
        }

        // Set position
        var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        guard let positionValue = AXValueCreate(.cgPoint, &position) else {
            return .failure(.accessibilityError(Int32(AXError.failure.rawValue)))
        }

        let positionResult = AXUIElementSetAttributeValue(
            windowElement,
            kAXPositionAttribute as CFString,
            positionValue
        )

        if positionResult != .success {
            return .failure(.accessibilityError(positionResult.rawValue))
        }

        // Set size
        var size = CGSize(width: frame.width, height: frame.height)
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            return .failure(.accessibilityError(Int32(AXError.failure.rawValue)))
        }

        let sizeResult = AXUIElementSetAttributeValue(
            windowElement,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        if sizeResult != .success {
            // Non-resizable windows can be positioned but not resized — this is expected.
            // Position was already set successfully above, so treat this as success.
            // Record the rejection so the orchestrator can reclassify this window.
            _resizeRejectedLock.lock()
            _resizeRejectedWindowIDs.insert(windowID)
            _resizeRejectedLock.unlock()
            TillerLogger.debug("animation", "Size-set failed for window \(windowID.rawValue) (error \(sizeResult.rawValue)), position was set — marked as resize-rejected")
            return .success(())
        }

        // Detect silent resize clamping: macOS returns .success but clamps to minimum size.
        // Read back actual size and compare to requested size.
        var actualSizeRef: CFTypeRef?
        let readBack = AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &actualSizeRef)
        if readBack == .success, let actualSizeValue = actualSizeRef {
            var actualSize = CGSize.zero
            if AXValueGetValue(actualSizeValue as! AXValue, .cgSize, &actualSize) {
                let tolerance: CGFloat = 2
                if abs(actualSize.width - frame.width) > tolerance || abs(actualSize.height - frame.height) > tolerance {
                    _resizeRejectedLock.lock()
                    _resizeRejectedWindowIDs.insert(windowID)
                    _resizeRejectedLock.unlock()
                    TillerLogger.debug("animation", "Size-set silently clamped for window \(windowID.rawValue): requested \(frame.width)x\(frame.height), actual \(actualSize.width)x\(actualSize.height) — marked as resize-rejected")
                    return .success(())
                }
            }
        }

        return .success(())
    }

    func raiseWindow(_ windowID: WindowID, pid: pid_t) -> Result<Void, AnimationError> {
        guard let windowElement = getWindowElement(for: windowID, pid: pid) else {
            return .failure(.windowElementNotFound(windowID))
        }

        // Check if window is minimized - don't raise minimized windows
        var minimizedRef: CFTypeRef?
        let minimizedResult = AXUIElementCopyAttributeValue(
            windowElement,
            kAXMinimizedAttribute as CFString,
            &minimizedRef
        )
        if minimizedResult == .success,
           let isMinimized = minimizedRef as? Bool,
           isMinimized {
            TillerLogger.debug("animation", "Skipping raise for minimized window \(windowID.rawValue)")
            return .success(())
        }

        let result = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
        if result != .success {
            TillerLogger.animation.error("Failed to raise window \(windowID.rawValue): \(result.rawValue)")
            return .failure(.accessibilityError(result.rawValue))
        }

        return .success(())
    }

    func getWindowElement(for windowID: WindowID, pid: pid_t) -> AXUIElement? {
        // Check accessibility trust (cached for 10 seconds to avoid spam)
        let now = Date()
        if isTrustedCache == nil || lastTrustedCheck == nil || now.timeIntervalSince(lastTrustedCheck!) > 10 {
            isTrustedCache = AXIsProcessTrusted()
            lastTrustedCheck = now
            TillerLogger.debug("animation", "AXIsProcessTrusted() = \(self.isTrustedCache!)")
        }

        guard isTrustedCache == true else {
            TillerLogger.animation.error("Not trusted, cannot position windows")
            return nil
        }

        // Check cache first
        if let cached = windowElementCache[windowID] {
            var currentWindowID: CGWindowID = 0
            if _AXUIElementGetWindow(cached, &currentWindowID) == .success,
               currentWindowID == windowID.rawValue {
                return cached
            }
            windowElementCache.removeValue(forKey: windowID)
        }

        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )

        guard result == .success,
              let windows = windowsRef as? [AXUIElement] else {
            TillerLogger.animation.error("Failed to get windows for pid \(pid), result: \(result.rawValue)")
            return nil
        }

        for window in windows {
            var currentWindowID: CGWindowID = 0
            let getResult = _AXUIElementGetWindow(window, &currentWindowID)
            if getResult == .success,
               currentWindowID == windowID.rawValue {
                windowElementCache[windowID] = window
                return window
            }
        }

        TillerLogger.debug("animation", "Window \(windowID.rawValue) not found in \(windows.count) AX windows for pid \(pid)")
        return nil
    }

    func clearCache() {
        windowElementCache.removeAll()
    }

    func clearCache(for windowID: WindowID) {
        windowElementCache.removeValue(forKey: windowID)
    }
}
