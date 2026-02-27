//
//  MockWindowService.swift
//  Tiller
//

import CoreGraphics
import Foundation

final class MockWindowService: WindowServiceProtocol {
    var windows: [WindowInfo] = []
    var focusedWindow: FocusedWindowInfo?
    private var eventCallback: (@MainActor (WindowChangeEvent) -> Void)?

    func getVisibleWindows() -> [WindowInfo] {
        return windows
    }

    func getWindow(byID id: WindowID) -> WindowInfo? {
        return windows.first { $0.id == id }
    }

    func getFocusedWindow() -> FocusedWindowInfo? {
        return focusedWindow
    }

    func getWindows(forBundleID bundleID: String) -> [WindowInfo] {
        return windows.filter { $0.bundleID == bundleID }
    }

    func startObserving(callback: @escaping @MainActor (WindowChangeEvent) -> Void) {
        self.eventCallback = callback
    }

    func stopObserving() {
        eventCallback = nil
    }

    // MARK: - Simulation Methods (Async - for non-MainActor contexts)

    func simulateWindowOpen(_ window: WindowInfo) {
        windows.append(window)
        Task { @MainActor in
            eventCallback?(.windowOpened(window))
        }
    }

    func simulateWindowClose(_ id: WindowID) {
        windows.removeAll { $0.id == id }
        Task { @MainActor in
            eventCallback?(.windowClosed(id))
        }
    }

    func simulateWindowFocus(_ id: WindowID) {
        if let window = windows.first(where: { $0.id == id }) {
            focusedWindow = FocusedWindowInfo(
                windowID: id,
                appName: window.appName,
                bundleID: window.bundleID
            )
            Task { @MainActor in
                eventCallback?(.windowFocused(id))
            }
        }
    }

    func simulateWindowMove(_ id: WindowID, newFrame: CGRect) {
        if let index = windows.firstIndex(where: { $0.id == id }) {
            let oldWindow = windows[index]
            let updatedWindow = WindowInfo(
                id: oldWindow.id,
                title: oldWindow.title,
                appName: oldWindow.appName,
                bundleID: oldWindow.bundleID,
                frame: newFrame,
                isResizable: oldWindow.isResizable,
                isFloating: oldWindow.isFloating,
                ownerPID: oldWindow.ownerPID
            )
            windows[index] = updatedWindow
            Task { @MainActor in
                eventCallback?(.windowMoved(id, newFrame: newFrame))
            }
        }
    }

    func simulateWindowResize(_ id: WindowID, newFrame: CGRect) {
        if let index = windows.firstIndex(where: { $0.id == id }) {
            let oldWindow = windows[index]
            let updatedWindow = WindowInfo(
                id: oldWindow.id,
                title: oldWindow.title,
                appName: oldWindow.appName,
                bundleID: oldWindow.bundleID,
                frame: newFrame,
                isResizable: oldWindow.isResizable,
                isFloating: oldWindow.isFloating,
                ownerPID: oldWindow.ownerPID
            )
            windows[index] = updatedWindow
            Task { @MainActor in
                eventCallback?(.windowResized(id, newFrame: newFrame))
            }
        }
    }

    // MARK: - Synchronous Simulation Methods

    func simulateWindowOpenSync(_ window: WindowInfo) {
        windows.append(window)
        eventCallback?(.windowOpened(window))
    }

    func simulateWindowCloseSync(_ id: WindowID) {
        windows.removeAll { $0.id == id }
        eventCallback?(.windowClosed(id))
    }

    func simulateWindowFocusSync(_ id: WindowID) {
        if let window = windows.first(where: { $0.id == id }) {
            focusedWindow = FocusedWindowInfo(
                windowID: id,
                appName: window.appName,
                bundleID: window.bundleID
            )
            eventCallback?(.windowFocused(id))
        }
    }

    func simulateWindowMoveSync(_ id: WindowID, newFrame: CGRect) {
        if let index = windows.firstIndex(where: { $0.id == id }) {
            let oldWindow = windows[index]
            let updatedWindow = WindowInfo(
                id: oldWindow.id,
                title: oldWindow.title,
                appName: oldWindow.appName,
                bundleID: oldWindow.bundleID,
                frame: newFrame,
                isResizable: oldWindow.isResizable,
                isFloating: oldWindow.isFloating,
                ownerPID: oldWindow.ownerPID
            )
            windows[index] = updatedWindow
            eventCallback?(.windowMoved(id, newFrame: newFrame))
        }
    }

    func simulateWindowResizeSync(_ id: WindowID, newFrame: CGRect) {
        if let index = windows.firstIndex(where: { $0.id == id }) {
            let oldWindow = windows[index]
            let updatedWindow = WindowInfo(
                id: oldWindow.id,
                title: oldWindow.title,
                appName: oldWindow.appName,
                bundleID: oldWindow.bundleID,
                frame: newFrame,
                isResizable: oldWindow.isResizable,
                isFloating: oldWindow.isFloating,
                ownerPID: oldWindow.ownerPID
            )
            windows[index] = updatedWindow
            eventCallback?(.windowResized(id, newFrame: newFrame))
        }
    }

    // MARK: - Test Factory Methods

    static func createTestWindow(
        id: CGWindowID = 1,
        title: String = "Test Window",
        appName: String = "Test App",
        bundleID: String? = "com.test.app",
        frame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
        isResizable: Bool = true,
        isFloating: Bool = false,
        ownerPID: pid_t = 1234
    ) -> WindowInfo {
        return WindowInfo(
            id: WindowID(rawValue: id),
            title: title,
            appName: appName,
            bundleID: bundleID,
            frame: frame,
            isResizable: isResizable,
            isFloating: isFloating,
            ownerPID: ownerPID
        )
    }
}
