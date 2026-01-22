//
//  WindowPositioner.swift
//  Tiller
//

import ApplicationServices
import CoreGraphics
import Foundation

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

protocol WindowPositionerProtocol {
    func setFrame(_ frame: CGRect, for windowID: WindowID, pid: pid_t) -> Result<Void, AnimationError>
    func getWindowElement(for windowID: WindowID, pid: pid_t) -> AXUIElement?
}

final class WindowPositioner: WindowPositionerProtocol {
    private var windowElementCache: [WindowID: AXUIElement] = [:]

    func setFrame(_ frame: CGRect, for windowID: WindowID, pid: pid_t) -> Result<Void, AnimationError> {
        guard let windowElement = getWindowElement(for: windowID, pid: pid) else {
            return .failure(.windowElementNotFound(windowID))
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
            return .failure(.accessibilityError(sizeResult.rawValue))
        }

        return .success(())
    }

    func getWindowElement(for windowID: WindowID, pid: pid_t) -> AXUIElement? {
        // Check cache first
        if let cached = windowElementCache[windowID] {
            // Verify the cached element is still valid
            var currentWindowID: CGWindowID = 0
            if _AXUIElementGetWindow(cached, &currentWindowID) == .success,
               currentWindowID == windowID.rawValue {
                return cached
            }
            // Cache invalid, remove it
            windowElementCache.removeValue(forKey: windowID)
        }

        // Look up the window element
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )

        guard result == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return nil
        }

        for window in windows {
            var currentWindowID: CGWindowID = 0
            if _AXUIElementGetWindow(window, &currentWindowID) == .success,
               currentWindowID == windowID.rawValue {
                // Cache the element
                windowElementCache[windowID] = window
                return window
            }
        }

        return nil
    }

    func clearCache() {
        windowElementCache.removeAll()
    }

    func clearCache(for windowID: WindowID) {
        windowElementCache.removeValue(forKey: windowID)
    }
}
