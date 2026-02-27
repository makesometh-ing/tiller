//
//  WindowDiscoveryManager.swift
//  Tiller
//

import Foundation

@MainActor
final class WindowDiscoveryManager {
    static let shared = WindowDiscoveryManager()

    private let windowService: WindowServiceProtocol
    private var _isMonitoring: Bool = false

    var onWindowChange: ((WindowChangeEvent) -> Void)?
    var onFocusedWindowChanged: ((FocusedWindowInfo?) -> Void)?

    private init() {
        self.windowService = SystemWindowService()
    }

    init(windowService: WindowServiceProtocol) {
        self.windowService = windowService
    }

    var isMonitoring: Bool {
        return _isMonitoring
    }

    var visibleWindows: [WindowInfo] {
        return windowService.getVisibleWindows()
    }

    var focusedWindow: FocusedWindowInfo? {
        return windowService.getFocusedWindow()
    }

    func startMonitoring() {
        guard !_isMonitoring else {
            return
        }

        TillerLogger.debug("window-discovery","Starting window discovery")

        let windows = windowService.getVisibleWindows()
        TillerLogger.debug("window-discovery","Found \(windows.count) visible window(s)")
        for window in windows {
            TillerLogger.debug("window-discovery","  - \"\(window.title)\" (\(window.appName), ID: \(window.id.rawValue))")
        }

        if let focused = windowService.getFocusedWindow() {
            TillerLogger.debug("window-discovery","Focused window: \(focused.appName) (ID: \(focused.windowID.rawValue))")
        }

        windowService.startObserving { [weak self] event in
            self?.handleWindowEvent(event)
        }

        _isMonitoring = true
    }

    func stopMonitoring() {
        guard _isMonitoring else {
            return
        }

        windowService.stopObserving()
        _isMonitoring = false
        TillerLogger.debug("window-discovery","Stopped window discovery")
    }

    func getWindow(byID id: WindowID) -> WindowInfo? {
        return windowService.getWindow(byID: id)
    }

    func getWindows(forBundleID bundleID: String) -> [WindowInfo] {
        return windowService.getWindows(forBundleID: bundleID)
    }

    private func handleWindowEvent(_ event: WindowChangeEvent) {
        switch event {
        case .windowOpened(let windowInfo):
            TillerLogger.debug("window-discovery","Window opened: \"\(windowInfo.title)\" (\(windowInfo.appName))")
        case .windowClosed(let windowID):
            TillerLogger.debug("window-discovery","Window closed: ID \(windowID.rawValue)")
        case .windowFocused(let windowID):
            TillerLogger.debug("window-discovery","Window focused: ID \(windowID.rawValue)")
            // Use the windowID from the AX observer event directly instead of re-querying
            // via getFocusedWindow(), which is fragile (fails when Tiller menu bar is frontmost
            // or AX element becomes stale between the observer callback and the re-query).
            if let windowInfo = windowService.getWindow(byID: windowID) {
                let focused = FocusedWindowInfo(
                    windowID: windowID,
                    appName: windowInfo.appName,
                    bundleID: windowInfo.bundleID
                )
                onFocusedWindowChanged?(focused)
            } else {
                TillerLogger.debug("window-discovery", "Window focused but not found in visible windows: ID \(windowID.rawValue)")
            }
        case .windowMoved(let windowID, let newFrame):
            TillerLogger.debug("window-discovery","Window moved: ID \(windowID.rawValue) to \(String(describing: newFrame))")
        case .windowResized(let windowID, let newFrame):
            TillerLogger.debug("window-discovery","Window resized: ID \(windowID.rawValue) to \(String(describing: newFrame))")
        }

        onWindowChange?(event)
    }
}
