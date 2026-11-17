import AppKit
import ApplicationServices
import TillerCore

/// Returns the CGWindowID of an Accessibility window element. This private function works with SIP enabled.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

struct WindowRef {
    let id: WindowID
    let element: AXUIElement
    let app: AXUIElement
    let pid: pid_t
    let frame: CGRect
    let title: String
    var kind: WindowKind = .tiled
}

extension AXUIElement {
    func value(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success ? value : nil
    }

    var frame: CGRect? {
        guard let p = value(kAXPositionAttribute), let s = value(kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &point)
        AXValueGetValue(s as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    var windowID: WindowID? {
        var id = CGWindowID(0)
        return _AXUIElementGetWindow(self, &id) == .success ? id : nil
    }

    @discardableResult
    func set(_ attribute: String, _ value: CFTypeRef) -> AXError {
        AXUIElementSetAttributeValue(self, attribute as CFString, value)
    }
}

/// Reads and moves the windows of other apps through the Accessibility API.
final class AXWindows {
    /// When set, only windows of these apps are managed. The proof runner uses this so that it doesn't move your windows.
    let onlyBundleIDs: Set<String>?

    init(onlyBundleIDs: Set<String>?) { self.onlyBundleIDs = onlyBundleIDs }

    /// The window id and kind of each `window.classified` event. A window is logged again when its kind changes.
    private var classified = Set<String>()
    private let classifiedLock = NSLock()

    func isManaged(_ app: NSRunningApplication) -> Bool {
        app.activationPolicy == .regular && !app.isHidden
            && app.processIdentifier != getpid()
            && (onlyBundleIDs.map { $0.contains(app.bundleIdentifier ?? "") } ?? true)
    }

    private func managedApps() -> [NSRunningApplication] { NSWorkspace.shared.runningApplications.filter(isManaged) }

    /// Tiled and floating windows, front to back. Ignored windows aren't returned.
    func windows() -> [WindowRef] {
        let order = Self.frontToBackOrder()
        var refs: [WindowRef] = []
        for app in managedApps() {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            // A hung app returns an error after this time instead of blocking Tiller.
            AXUIElementSetMessagingTimeout(appElement, 1.0)
            var value: CFTypeRef?
            let start = DispatchTime.now()
            let error = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
            if error != .success && error != .noValue && error != .attributeUnsupported {
                // For example kAXErrorCannotComplete from a hung app.
                Log.event(.axError, ["function": "AXUIElementCopyAttributeValue", "attribute": .string(kAXWindowsAttribute),
                                     "code": .int(Int(error.rawValue)), "bundleId": .string(app.bundleIdentifier ?? ""), "ms": Log.ms(since: start)])
            }
            guard let list = value as? [AXUIElement] else { continue }
            for element in list {
                guard let id = element.windowID, let frame = element.frame else { continue }
                let traits = Self.traits(element, id: id, order: order)
                let kind = traits.kind
                logClassified(traits, id: id, app: app, element: element)
                guard kind != .ignored else { continue }
                refs.append(WindowRef(id: id, element: element, app: appElement, pid: app.processIdentifier,
                                      frame: frame, title: element.value(kAXTitleAttribute) as? String ?? "", kind: kind))
            }
        }
        return refs.sorted { (order[$0.id]?.index ?? .max) < (order[$1.id]?.index ?? .max) }
    }

    /// Writes `window.classified` the first time a window id is read with a kind. The event shows why a window is tiled, floats or is ignored.
    /// The title is removed by `EventLog` when "Include window titles in logs" is off.
    private func logClassified(_ t: WindowTraits, id: WindowID, app: NSRunningApplication, element: AXUIElement) {
        let key = "\(id):\(t.kind)"
        guard classifiedLock.withLock({ classified.insert(key).inserted }) else { return }
        Log.event(.windowClassified, [
            "bundleId": .string(app.bundleIdentifier ?? ""), "app": .string(app.localizedName ?? ""), "windowId": .int(Int(id)),
            "subrole": t.subrole.map(LogValue.string) ?? .null, "minimized": .bool(t.minimized), "sizeSettable": .bool(t.sizeSettable),
            "onScreen": .bool(t.onScreen), "layer": .int(t.layer), "modal": .bool(t.modal), "parentIsApp": .bool(t.parentIsApp),
            "kind": .string("\(t.kind)"), "title": .string(element.value(kAXTitleAttribute) as? String ?? ""),
        ])
    }

    /// On-screen windows from the window server, front to back, with their layer.
    /// Window ids and layers don't need Screen Recording permission.
    static func frontToBackOrder() -> [WindowID: (index: Int, layer: Int)] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var order: [WindowID: (index: Int, layer: Int)] = [:]
        for (index, entry) in info.enumerated() {
            if let number = entry[kCGWindowNumber as String] as? WindowID {
                order[number] = (index, entry[kCGWindowLayer as String] as? Int ?? 0)
            }
        }
        return order
    }

    /// On-screen windows at layer 0 and their frames, front first. Tiller's own panels aren't listed.
    static func frontToBackFrames() -> [(id: WindowID, frame: CGRect)] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return info.compactMap { entry in
            guard let id = entry[kCGWindowNumber as String] as? WindowID, entry[kCGWindowLayer as String] as? Int == 0,
                  entry[kCGWindowOwnerPID as String] as? pid_t != getpid(),
                  let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return (id, frame)
        }
    }

    static func traits(_ element: AXUIElement, id: WindowID, order: [WindowID: (index: Int, layer: Int)]) -> WindowTraits {
        var sizeSettable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &sizeSettable)
        let parent = element.value(kAXParentAttribute).flatMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil }
        return WindowTraits(subrole: element.value(kAXSubroleAttribute) as? String,
                            minimized: element.value(kAXMinimizedAttribute) as? Bool == true,
                            sizeSettable: sizeSettable.boolValue,
                            onScreen: order[id] != nil,
                            layer: order[id]?.layer ?? 0,
                            modal: element.value(kAXModalAttribute) as? Bool == true,
                            parentIsApp: parent.map { ($0.value(kAXRoleAttribute) as? String) == kAXApplicationRole } ?? true)
    }

    func focusedWindowID() -> WindowID? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = element.value(kAXFocusedWindowAttribute), CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        return (window as! AXUIElement).windowID
    }

    /// Sets the frames. Windows of different apps are moved in parallel, because each call waits for the other app.
    /// Returns the time for each app, for the `setFramesMs` field of `action.done`.
    @discardableResult
    func setFrames(_ frames: [WindowID: CGRect], refs: [WindowID: WindowRef]) -> LogValue {
        let byApp = Dictionary(grouping: frames.compactMap { id, frame in refs[id].map { ($0, frame) } }, by: { $0.0.pid })
        let groups = Array(byApp.values)
        var timings = [LogValue](repeating: .null, count: groups.count)
        // Each iteration writes only its own index.
        timings.withUnsafeMutableBufferPointer { timings in
        DispatchQueue.concurrentPerform(iterations: groups.count) { i in
            let app = groups[i][0].0.app
            let start = DispatchTime.now().uptimeNanoseconds
            // When AXEnhancedUserInterface is on, some apps animate each resize slowly. It is restored after the move.
            let enhanced = app.value("AXEnhancedUserInterface") as? Bool == true
            if enhanced { app.set("AXEnhancedUserInterface", kCFBooleanFalse) }
            let name = NSRunningApplication(processIdentifier: groups[i][0].0.pid)?.bundleIdentifier ?? "\(groups[i][0].0.pid)"
            for (ref, frame) in groups[i] {
                let t = DispatchTime.now()
                Self.setFrame(ref.element, frame, id: ref.id, bundleID: name)
                Log.event(.axCall, ["function": "setFrame", "bundleId": .string(name), "windowId": .int(Int(ref.id)), "ms": Log.ms(since: t)])
            }
            if enhanced { app.set("AXEnhancedUserInterface", kCFBooleanTrue) }
            timings[i] = ["app": .string(name), "windows": .int(groups[i].count), "enhancedUI": .bool(enhanced),
                          "ms": .ms(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)]
        }
        }
        return .array(timings)
    }

    private static func setFrame(_ element: AXUIElement, _ frame: CGRect, id: WindowID, bundleID: String) {
        var size = frame.size, origin = frame.origin
        let sizeValue = AXValueCreate(.cgSize, &size)!
        let originValue = AXValueCreate(.cgPoint, &origin)!
        // Size first, so that the window fits at the new position. Size again, because some apps
        // limit the size to the screen at the old position.
        for (attribute, value) in [(kAXSizeAttribute, sizeValue), (kAXPositionAttribute, originValue), (kAXSizeAttribute, sizeValue)] {
            let error = element.set(attribute, value)
            if error != .success {
                Log.event(.axError, ["function": "AXUIElementSetAttributeValue", "attribute": .string(attribute), "code": .int(Int(error.rawValue)),
                                     "bundleId": .string(bundleID), "windowId": .int(Int(id))])
            }
        }
    }

    /// Raises the windows. The last window gets focus.
    func raise(_ refs: [WindowRef]) {
        for ref in refs { AXUIElementPerformAction(ref.element, kAXRaiseAction as CFString) }
        if let last = refs.last { Self.activate(last) }
    }

    /// Returns the results of the calls, for the log.
    @discardableResult
    func focus(_ ref: WindowRef) -> String {
        let main = ref.element.set(kAXMainAttribute, kCFBooleanTrue)
        let raise = AXUIElementPerformAction(ref.element, kAXRaiseAction as CFString)
        let (front, activated) = Self.activate(ref)
        return "main=\(main.rawValue) raise=\(raise.rawValue) frontmost=\(front.rawValue) activate=\(activated)"
    }

    /// Makes the app of `ref` the active app. Some apps, for example Dia, return success for AXFrontmost and stay
    /// inactive, so NSRunningApplication.activate() is also called. Without the all-windows option, only the main window comes forward.
    @discardableResult
    private static func activate(_ ref: WindowRef) -> (AXError, Bool) {
        let front = ref.app.set(kAXFrontmostAttribute, kCFBooleanTrue)
        return (front, NSRunningApplication(processIdentifier: ref.pid)?.activate() ?? false)
    }
}
