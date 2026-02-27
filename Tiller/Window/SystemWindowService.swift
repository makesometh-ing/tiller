//
//  SystemWindowService.swift
//  Tiller
//

import AppKit
import ApplicationServices
import Foundation

@_silgen_name("_AXUIElementGetWindow")
nonisolated private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

final class SystemWindowService: WindowServiceProtocol {
    private var observerCallback: (@MainActor (WindowChangeEvent) -> Void)?
    private var appObservers: [pid_t: AXObserver] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var trackedWindows: [WindowID: WindowInfo] = [:]

    /// Apps that should always be treated as floating (system utilities, overlays, etc.)
    private static let alwaysFloatingApps: Set<String> = [
        "pro.betterdisplay.BetterDisplay",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "eu.exelban.Stats"
    ]

    func getVisibleWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var windows: [WindowInfo] = []

        for windowDict in windowList {
            guard let windowInfo = parseWindowInfo(from: windowDict) else {
                continue
            }
            windows.append(windowInfo)
        }

        return windows
    }

    func getWindow(byID id: WindowID) -> WindowInfo? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  windowID == id.rawValue else {
                continue
            }

            return parseWindowInfo(from: windowDict)
        }

        return nil
    }

    func getFocusedWindow() -> FocusedWindowInfo? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            TillerLogger.debug("window-discovery", "[getFocusedWindow] frontmostApplication is nil")
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedWindowRef: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowRef
        )

        guard result == .success,
              let focusedWindow = focusedWindowRef else {
            TillerLogger.debug("window-discovery", "[getFocusedWindow] AXFocusedWindow query failed for \(frontApp.localizedName ?? "?") (pid \(frontApp.processIdentifier)): error \(result.rawValue)")
            return nil
        }

        let windowElement = focusedWindow as! AXUIElement
        var windowID: CGWindowID = 0

        let windowIDResult = _AXUIElementGetWindow(windowElement, &windowID)
        guard windowIDResult == .success else {
            TillerLogger.debug("window-discovery", "[getFocusedWindow] _AXUIElementGetWindow failed for \(frontApp.localizedName ?? "?"): error \(windowIDResult.rawValue)")
            return nil
        }

        return FocusedWindowInfo(
            windowID: WindowID(rawValue: windowID),
            appName: frontApp.localizedName ?? "Unknown",
            bundleID: frontApp.bundleIdentifier
        )
    }

    func getWindows(forBundleID bundleID: String) -> [WindowInfo] {
        let windows = getVisibleWindows()
        return windows.filter { $0.bundleID == bundleID }
    }

    func startObserving(callback: @escaping @MainActor (WindowChangeEvent) -> Void) {
        self.observerCallback = callback

        trackedWindows = Dictionary(
            uniqueKeysWithValues: getVisibleWindows().map { ($0.id, $0) }
        )

        setupWorkspaceObservers()

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            setupObserver(for: app.processIdentifier)
        }
    }

    func stopObserving() {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()

        for (pid, observer) in appObservers {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            removeObserverNotifications(observer, pid: pid)
        }
        appObservers.removeAll()

        trackedWindows.removeAll()
        observerCallback = nil
    }

    // MARK: - Private Methods

    private func parseWindowInfo(from dict: [String: Any]) -> WindowInfo? {
        guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID,
              let layer = dict[kCGWindowLayer as String] as? Int,
              layer == 0 else {
            return nil
        }

        let ownerPID = dict[kCGWindowOwnerPID as String] as? pid_t ?? 0
        let ownerName = dict[kCGWindowOwnerName as String] as? String ?? "Unknown"
        let title = dict[kCGWindowName as String] as? String ?? ""

        var bundleID: String?
        if let app = NSRunningApplication(processIdentifier: ownerPID) {
            bundleID = app.bundleIdentifier
        }

        var frame = CGRect.zero
        if let boundsDict = dict[kCGWindowBounds as String] as? [String: Any] {
            let x = boundsDict["X"] as? CGFloat ?? 0
            let y = boundsDict["Y"] as? CGFloat ?? 0
            let width = boundsDict["Width"] as? CGFloat ?? 0
            let height = boundsDict["Height"] as? CGFloat ?? 0
            frame = CGRect(x: x, y: y, width: width, height: height)
        }

        let attributes = queryWindowAttributes(pid: ownerPID, windowID: windowID, bundleID: bundleID)

        return WindowInfo(
            id: WindowID(rawValue: windowID),
            title: title,
            appName: ownerName,
            bundleID: bundleID,
            frame: frame,
            isResizable: attributes.isResizable,
            isFloating: attributes.isFloating,
            ownerPID: ownerPID
        )
    }

    private func queryWindowAttributes(pid: pid_t, windowID: CGWindowID, bundleID: String?) -> (isResizable: Bool, isFloating: Bool) {
        let result = queryWindowAttributesInner(pid: pid, windowID: windowID, bundleID: bundleID)
        TillerLogger.debug("window-discovery", "Window \(windowID) (\(bundleID ?? "unknown")) -> isResizable=\(result.isResizable), isFloating=\(result.isFloating)")
        return result
    }

    private func queryWindowAttributesInner(pid: pid_t, windowID: CGWindowID, bundleID: String?) -> (isResizable: Bool, isFloating: Bool) {
        // Check if app is in always-floating list (system utilities that can't be positioned)
        if let bundleID = bundleID, Self.alwaysFloatingApps.contains(bundleID) {
            return (isResizable: true, isFloating: true)
        }

        // Check if app is in user-configured floatingApps
        if let bundleID = bundleID {
            let floatingApps = ConfigManager.shared.getConfig().floatingApps
            if floatingApps.contains(bundleID) {
                return (isResizable: true, isFloating: true)
            }
        }

        // Filter windows from menu bar-only (accessory) or background (prohibited) apps
        if let app = NSRunningApplication(processIdentifier: pid) {
            if app.activationPolicy == .accessory || app.activationPolicy == .prohibited {
                return (isResizable: true, isFloating: true)
            }
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
            // Can't query AX windows — assume non-resizable (safe: centering is better than broken tiling)
            return (isResizable: false, isFloating: false)
        }

        for window in windows {
            var currentWindowID: CGWindowID = 0
            let windowIDResult = _AXUIElementGetWindow(window, &currentWindowID)

            if windowIDResult == .success && currentWindowID == windowID {
                // Check AXRole for dialog or sheet
                var roleRef: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(
                    window,
                    kAXRoleAttribute as CFString,
                    &roleRef
                )
                if roleResult == .success, let role = roleRef as? String {
                    // AXDialog and AXSheet roles indicate floating windows
                    if role == "AXDialog" || role == "AXSheet" {
                        return (isResizable: true, isFloating: true)
                    }
                }

                // Check AXSubrole for floating window types
                var subroleRef: CFTypeRef?
                let subroleResult = AXUIElementCopyAttributeValue(
                    window,
                    kAXSubroleAttribute as CFString,
                    &subroleRef
                )
                if subroleResult == .success, let subrole = subroleRef as? String {
                    let floatingSubroles = [
                        "AXFloatingWindow",
                        "AXSystemFloatingWindow",
                        "AXDialog"
                    ]
                    if floatingSubroles.contains(subrole) {
                        return (isResizable: true, isFloating: true)
                    }
                }

                // Check AXResizable
                var resizableRef: CFTypeRef?
                let resizableResult = AXUIElementCopyAttributeValue(
                    window,
                    "AXResizable" as CFString,
                    &resizableRef
                )

                if resizableResult == .success,
                   let resizable = resizableRef as? Bool {
                    TillerLogger.debug("window-discovery", "Window \(windowID) (\(bundleID ?? "unknown")): AXResizable = \(resizable)")
                    return (isResizable: resizable, isFloating: false)
                }

                TillerLogger.debug("window-discovery", "Window \(windowID) (\(bundleID ?? "unknown")): AXResizable query failed (error \(resizableResult.rawValue))")

                // AXResizable failed — try min/max size probe as fallback.
                var minSizeRef: CFTypeRef?
                var maxSizeRef: CFTypeRef?
                let minResult = AXUIElementCopyAttributeValue(window, "AXMinimumSize" as CFString, &minSizeRef)
                let maxResult = AXUIElementCopyAttributeValue(window, "AXMaximumSize" as CFString, &maxSizeRef)

                if minResult == .success, maxResult == .success,
                   let minVal = minSizeRef, let maxVal = maxSizeRef,
                   CFGetTypeID(minVal) == AXValueGetTypeID(),
                   CFGetTypeID(maxVal) == AXValueGetTypeID() {
                    var minSize = CGSize.zero
                    var maxSize = CGSize(width: 1, height: 1)
                    if AXValueGetValue(minVal as! AXValue, .cgSize, &minSize),
                       AXValueGetValue(maxVal as! AXValue, .cgSize, &maxSize) {
                        let isFixed = (minSize.width == maxSize.width && minSize.height == maxSize.height)
                        TillerLogger.debug("window-discovery", "Window \(windowID) (\(bundleID ?? "unknown")): min/max probe: min=\(minSize), max=\(maxSize), fixed=\(isFixed)")
                        return (isResizable: !isFixed, isFloating: false)
                    }
                }

                // All probes failed, but we DID find the window in the AX tree
                // and the app has .regular activation policy.
                // Default to resizable: these are normal app windows where attribute
                // queries failed (can happen in debug builds or certain app frameworks).
                TillerLogger.debug("window-discovery", "Window \(windowID) (\(bundleID ?? "unknown")): all probes failed, defaulting to resizable (window found in AX tree)")
                return (isResizable: true, isFloating: false)
            }
        }

        // Window not found in AX window list — assume non-resizable (safe default)
        return (isResizable: false, isFloating: false)
    }

    private func setupWorkspaceObservers() {
        let launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.activationPolicy == .regular else {
                return
            }
            let pid = app.processIdentifier
            MainActor.assumeIsolated {
                self?.setupObserver(for: pid)
            }
        }
        workspaceObservers.append(launchObserver)

        let terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let pid = app.processIdentifier
            MainActor.assumeIsolated {
                self?.removeObserver(for: pid)
            }
        }
        workspaceObservers.append(terminateObserver)

        let activateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            // Ignore activations from menu bar-only (accessory) or background (prohibited) apps
            // These apps (e.g. Stats) should not trigger a retile when their popover opens
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.activationPolicy != .regular {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let focusedWindow = self.getFocusedWindow() {
                    Task { @MainActor in
                        self.observerCallback?(.windowFocused(focusedWindow.windowID))
                    }
                }
            }
        }
        workspaceObservers.append(activateObserver)
    }

    private func setupObserver(for pid: pid_t) {
        guard appObservers[pid] == nil else {
            return
        }

        var observer: AXObserver?
        let result = AXObserverCreate(
            pid,
            { _, element, notification, refcon in
                guard let refcon = refcon else { return }
                MainActor.assumeIsolated {
                    let service = Unmanaged<SystemWindowService>.fromOpaque(refcon).takeUnretainedValue()
                    service.handleAXNotification(element: element, notification: notification as String)
                }
            },
            &observer
        )

        guard result == .success, let observer = observer else {
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let notifications = [
            kAXWindowCreatedNotification,
            kAXUIElementDestroyedNotification,
            kAXFocusedWindowChangedNotification,
            kAXWindowMovedNotification,
            kAXWindowResizedNotification
        ]

        for notification in notifications {
            AXObserverAddNotification(observer, appElement, notification as CFString, refcon)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        appObservers[pid] = observer
    }

    private func removeObserver(for pid: pid_t) {
        guard let observer = appObservers[pid] else {
            return
        }

        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        removeObserverNotifications(observer, pid: pid)
        appObservers.removeValue(forKey: pid)
    }

    private func removeObserverNotifications(_ observer: AXObserver, pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)

        let notifications = [
            kAXWindowCreatedNotification,
            kAXUIElementDestroyedNotification,
            kAXFocusedWindowChangedNotification,
            kAXWindowMovedNotification,
            kAXWindowResizedNotification
        ]

        for notification in notifications {
            AXObserverRemoveNotification(observer, appElement, notification as CFString)
        }
    }

    private func handleAXNotification(element: AXUIElement, notification: String) {
        switch notification {
        case kAXWindowCreatedNotification:
            handleWindowCreated(element: element)
        case kAXUIElementDestroyedNotification:
            handleWindowDestroyed(element: element)
        case kAXFocusedWindowChangedNotification:
            handleFocusChanged(element: element)
        case kAXWindowMovedNotification:
            handleWindowMoved(element: element)
        case kAXWindowResizedNotification:
            handleWindowResized(element: element)
        default:
            break
        }
    }

    private func handleWindowCreated(element: AXUIElement) {
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &windowID) == .success else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            if let windowInfo = self.getWindow(byID: WindowID(rawValue: windowID)) {
                self.trackedWindows[windowInfo.id] = windowInfo
                Task { @MainActor in
                    self.observerCallback?(.windowOpened(windowInfo))
                }
            }
        }
    }

    private func handleWindowDestroyed(element: AXUIElement) {
        var windowID: CGWindowID = 0
        if _AXUIElementGetWindow(element, &windowID) == .success {
            let id = WindowID(rawValue: windowID)
            trackedWindows.removeValue(forKey: id)
            Task { @MainActor in
                observerCallback?(.windowClosed(id))
            }
            return
        }

        let currentWindows = Set(getVisibleWindows().map { $0.id })
        for trackedID in trackedWindows.keys {
            if !currentWindows.contains(trackedID) {
                trackedWindows.removeValue(forKey: trackedID)
                Task { @MainActor in
                    observerCallback?(.windowClosed(trackedID))
                }
            }
        }
    }

    private func handleFocusChanged(element: AXUIElement) {
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &windowID) == .success else {
            return
        }

        Task { @MainActor in
            observerCallback?(.windowFocused(WindowID(rawValue: windowID)))
        }
    }

    private func handleWindowMoved(element: AXUIElement) {
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &windowID) == .success else {
            return
        }

        let id = WindowID(rawValue: windowID)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            if let windowInfo = self.getWindow(byID: id) {
                self.trackedWindows[id] = windowInfo
                Task { @MainActor in
                    self.observerCallback?(.windowMoved(id, newFrame: windowInfo.frame))
                }
            }
        }
    }

    private func handleWindowResized(element: AXUIElement) {
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &windowID) == .success else {
            return
        }

        let id = WindowID(rawValue: windowID)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            if let windowInfo = self.getWindow(byID: id) {
                self.trackedWindows[id] = windowInfo
                Task { @MainActor in
                    self.observerCallback?(.windowResized(id, newFrame: windowInfo.frame))
                }
            }
        }
    }
}
