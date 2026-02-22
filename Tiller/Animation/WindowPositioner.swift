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
            TillerLogger.animation.debug("Skipping minimized window \(windowID.rawValue)")
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
            TillerLogger.animation.debug("Size-set failed for window \(windowID.rawValue) (error \(sizeResult.rawValue)), position was set — tolerating")
            return .success(())
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
            TillerLogger.animation.debug("Skipping raise for minimized window \(windowID.rawValue)")
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
            TillerLogger.animation.info("AXIsProcessTrusted() = \(self.isTrustedCache!)")
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

        TillerLogger.animation.debug("Window \(windowID.rawValue) not found in \(windows.count) AX windows for pid \(pid)")
        return nil
    }

    func clearCache() {
        windowElementCache.removeAll()
    }

    func clearCache(for windowID: WindowID) {
        windowElementCache.removeValue(forKey: windowID)
    }
}
