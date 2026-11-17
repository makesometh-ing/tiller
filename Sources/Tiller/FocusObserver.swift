import AppKit
import ApplicationServices

/// Calls `onChange` on the main thread when the focused window of a managed app changes, or when another app becomes active.
final class FocusObserver {
    private let ax: AXWindows
    private let onChange: () -> Void
    private var observers: [pid_t: AXObserver] = [:]
    private var tokens: [NSObjectProtocol] = []

    init(ax: AXWindows, onChange: @escaping () -> Void) {
        self.ax = ax
        self.onChange = onChange
    }

    /// Call on the main thread after the Accessibility permission is granted.
    func start() {
        for app in NSWorkspace.shared.runningApplications where ax.isManaged(app) { observe(app) }
        let center = NSWorkspace.shared.notificationCenter
        func app(_ note: Notification) -> NSRunningApplication? { note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
        tokens.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            // An app that wasn't ready at its launch is observed at its first activation.
            if let app = app(note), ax.isManaged(app) { observe(app) }
            onChange()
        })
        tokens.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let self, let app = app(note), ax.isManaged(app) { observe(app) }
        })
        tokens.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let pid = app(note)?.processIdentifier, let observer = observers.removeValue(forKey: pid) else { return }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        })
    }

    private func observe(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            Unmanaged<FocusObserver>.fromOpaque(refcon!).takeUnretainedValue().onChange()
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }
        let element = AXUIElementCreateApplication(pid)
        // A hung app returns an error after this time instead of blocking the main thread.
        AXUIElementSetMessagingTimeout(element, 0.5)
        let result = AXObserverAddNotification(observer, element, kAXFocusedWindowChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        guard result == .success else {
            Log.event(.axError, ["function": "AXObserverAddNotification", "attribute": .string(kAXFocusedWindowChangedNotification),
                                 "code": .int(Int(result.rawValue)), "bundleId": .string(app.bundleIdentifier ?? "\(pid)")])
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }
}
