import AppKit
import ApplicationServices

/// Reads the Accessibility notifications of each managed app and the app notifications of `NSWorkspace`. Each callback runs on the main thread.
/// `onFocus`: the focused window of an app changed, or another app became active.
/// `onWindows`: a window opened, closed, was minimized or unminimized, or an app was hidden, shown, launched or quit. The argument is the notification name.
final class WindowObserver {
    private let ax: AXWindows
    private let onFocus: () -> Void
    private let onWindows: (String) -> Void
    private var observers: [pid_t: AXObserver] = [:]
    private var tokens: [NSObjectProtocol] = []
    /// Added to each window element.
    private static let windowNotifications = [kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification]

    init(ax: AXWindows, onFocus: @escaping () -> Void, onWindows: @escaping (String) -> Void) {
        self.ax = ax
        self.onFocus = onFocus
        self.onWindows = onWindows
    }

    /// Call on the main thread after the Accessibility permission is granted.
    func start() {
        for app in NSWorkspace.shared.runningApplications where ax.isManaged(app) { observe(app) }
        let center = NSWorkspace.shared.notificationCenter
        func app(_ note: Notification) -> NSRunningApplication? { note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
        func on(_ name: Notification.Name, _ handler: @escaping (WindowObserver, NSRunningApplication?) -> Void) {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                if let self { handler(self, app(note)) }
            })
        }
        on(NSWorkspace.didActivateApplicationNotification) { me, app in
            // An app that wasn't ready at its launch is observed at its first activation.
            if let app, me.ax.isManaged(app) { me.observe(app) }
            me.onFocus()
        }
        on(NSWorkspace.didLaunchApplicationNotification) { me, app in
            if let app, me.ax.isManaged(app) { me.observe(app) }
            me.onWindows("appLaunched")
        }
        on(NSWorkspace.didTerminateApplicationNotification) { me, app in
            if let pid = app?.processIdentifier, let observer = me.observers.removeValue(forKey: pid) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
            }
            me.onWindows("appTerminated")
        }
        on(NSWorkspace.didHideApplicationNotification) { me, _ in me.onWindows("appHidden") }
        on(NSWorkspace.didUnhideApplicationNotification) { me, app in
            // An app that was hidden when Tiller started isn't observed yet.
            if let app, me.ax.isManaged(app) { me.observe(app) }
            me.onWindows("appShown")
        }
    }

    private func observe(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            Unmanaged<WindowObserver>.fromOpaque(refcon!).takeUnretainedValue().received(notification as String, element: element, observer: observer)
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }
        let element = AXUIElementCreateApplication(pid)
        // A hung app returns an error after this time instead of blocking the main thread.
        AXUIElementSetMessagingTimeout(element, 0.5)
        for name in [kAXFocusedWindowChangedNotification, kAXWindowCreatedNotification] {
            let result = AXObserverAddNotification(observer, element, name as CFString, Unmanaged.passUnretained(self).toOpaque())
            guard result == .success else {
                Log.event(.axError, ["function": "AXObserverAddNotification", "attribute": .string(name),
                                     "code": .int(Int(result.rawValue)), "bundleId": .string(app.bundleIdentifier ?? "\(pid)")])
                return
            }
        }
        for window in element.value(kAXWindowsAttribute) as? [AXUIElement] ?? [] { watch(window, observer: observer) }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    private func watch(_ window: AXUIElement, observer: AXObserver) {
        for name in Self.windowNotifications {
            AXObserverAddNotification(observer, window, name as CFString, Unmanaged.passUnretained(self).toOpaque())
        }
    }

    private func received(_ notification: String, element: AXUIElement, observer: AXObserver) {
        if notification == kAXFocusedWindowChangedNotification { onFocus(); return }
        if notification == kAXWindowCreatedNotification { watch(element, observer: observer) }
        onWindows(notification)
    }
}
