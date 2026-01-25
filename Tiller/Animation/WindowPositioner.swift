//
//  WindowPositioner.swift
//  Tiller
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

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
            print("[WindowPositioner] Skipping minimized window \(windowID.rawValue)")
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
            return .failure(.accessibilityError(sizeResult.rawValue))
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
            print("[WindowPositioner] Skipping raise for minimized window \(windowID.rawValue)")
            return .success(())
        }

        let result = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
        if result != .success {
            print("[WindowPositioner] Failed to raise window \(windowID.rawValue): \(result.rawValue)")
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
            print("[WindowPositioner] AXIsProcessTrusted() = \(isTrustedCache!)")
        }

        guard isTrustedCache == true else {
            print("[WindowPositioner] Not trusted, cannot position windows")
            return nil
        }

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

        // Verify the PID is valid
        if let app = NSRunningApplication(processIdentifier: pid) {
            print("[WindowPositioner] PID \(pid) is valid: \(app.localizedName ?? "unknown") (bundle: \(app.bundleIdentifier ?? "nil"))")
        } else {
            print("[WindowPositioner] PID \(pid) is NOT a valid running application!")
        }

        // Test system-wide element first
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppRef)
        print("[WindowPositioner] System-wide focused app check: result=\(focusedResult.rawValue)")

        // Look up the window element
        let appElement = AXUIElementCreateApplication(pid)

        // First check if we can get the app's role (basic connectivity test)
        var roleRef: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &roleRef)
        print("[WindowPositioner] App role check for pid \(pid): result=\(roleResult.rawValue), role=\(roleRef ?? "nil" as CFTypeRef)")

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )

        guard result == .success,
              let windows = windowsRef as? [AXUIElement] else {
            print("[WindowPositioner] Failed to get windows for pid \(pid), result: \(result.rawValue)")
            return nil
        }

        print("[WindowPositioner] Looking for window \(windowID.rawValue) in \(windows.count) windows from pid \(pid)")

        for window in windows {
            var currentWindowID: CGWindowID = 0
            let getResult = _AXUIElementGetWindow(window, &currentWindowID)
            print("[WindowPositioner]   - AX window ID: \(currentWindowID), getResult: \(getResult.rawValue)")
            if getResult == .success,
               currentWindowID == windowID.rawValue {
                // Cache the element
                windowElementCache[windowID] = window
                return window
            }
        }

        print("[WindowPositioner] Window \(windowID.rawValue) not found in AX windows")
        return nil
    }

    func clearCache() {
        windowElementCache.removeAll()
    }

    func clearCache(for windowID: WindowID) {
        windowElementCache.removeValue(forKey: windowID)
    }
}
