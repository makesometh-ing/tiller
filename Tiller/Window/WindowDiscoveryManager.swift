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

        print("[WindowDiscoveryManager] Starting window discovery")

        let windows = windowService.getVisibleWindows()
        print("[WindowDiscoveryManager] Found \(windows.count) visible window(s):")
        for window in windows {
            print("[WindowDiscoveryManager]   - \"\(window.title)\" (\(window.appName), ID: \(window.id.rawValue))")
        }

        if let focused = windowService.getFocusedWindow() {
            print("[WindowDiscoveryManager] Focused window: \(focused.appName) (ID: \(focused.windowID.rawValue))")
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
        print("[WindowDiscoveryManager] Stopped window discovery")
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
            print("[WindowDiscoveryManager] Window opened: \"\(windowInfo.title)\" (\(windowInfo.appName))")
        case .windowClosed(let windowID):
            print("[WindowDiscoveryManager] Window closed: ID \(windowID.rawValue)")
        case .windowFocused(let windowID):
            print("[WindowDiscoveryManager] Window focused: ID \(windowID.rawValue)")
            if let focused = windowService.getFocusedWindow() {
                onFocusedWindowChanged?(focused)
            }
        case .windowMoved(let windowID, let newFrame):
            print("[WindowDiscoveryManager] Window moved: ID \(windowID.rawValue) to \(newFrame)")
        case .windowResized(let windowID, let newFrame):
            print("[WindowDiscoveryManager] Window resized: ID \(windowID.rawValue) to \(newFrame)")
        }

        onWindowChange?(event)
    }
}
