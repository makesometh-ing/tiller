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
            guard let list = appElement.value(kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for element in list {
                guard let id = element.windowID, let frame = element.frame else { continue }
                let kind = Self.traits(element, id: id, order: order).kind
                guard kind != .ignored else { continue }
                refs.append(WindowRef(id: id, element: element, app: appElement, pid: app.processIdentifier,
                                      frame: frame, title: element.value(kAXTitleAttribute) as? String ?? "", kind: kind))
            }
        }
        return refs.sorted { (order[$0.id]?.index ?? .max) < (order[$1.id]?.index ?? .max) }
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
    func setFrames(_ frames: [WindowID: CGRect], refs: [WindowID: WindowRef]) {
        let byApp = Dictionary(grouping: frames.compactMap { id, frame in refs[id].map { ($0, frame) } }, by: { $0.0.pid })
        let groups = Array(byApp.values)
        DispatchQueue.concurrentPerform(iterations: groups.count) { i in
            let app = groups[i][0].0.app
            let start = DispatchTime.now().uptimeNanoseconds
            // When AXEnhancedUserInterface is on, some apps animate each resize slowly. It is restored after the move.
            let enhanced = app.value("AXEnhancedUserInterface") as? Bool == true
            if enhanced { app.set("AXEnhancedUserInterface", kCFBooleanFalse) }
            var calls: [String] = []
            for (ref, frame) in groups[i] {
                let t = DispatchTime.now().uptimeNanoseconds
                Self.setFrame(ref.element, frame)
                calls.append(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - t) / 1e6))
            }
            if enhanced { app.set("AXEnhancedUserInterface", kCFBooleanTrue) }
            let name = NSRunningApplication(processIdentifier: groups[i][0].0.pid)?.bundleIdentifier ?? "\(groups[i][0].0.pid)"
            Log.write("setFrames app=\(name) windows=\(groups[i].count) enhancedUI=\(enhanced) totalMs=\(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)) perWindowMs=\(calls.joined(separator: ","))")
        }
    }

    private static func setFrame(_ element: AXUIElement, _ frame: CGRect) {
        var size = frame.size, origin = frame.origin
        let sizeValue = AXValueCreate(.cgSize, &size)!
        let originValue = AXValueCreate(.cgPoint, &origin)!
        // Size first, so that the window fits at the new position. Size again, because some apps
        // limit the size to the screen at the old position.
        element.set(kAXSizeAttribute, sizeValue)
        element.set(kAXPositionAttribute, originValue)
        element.set(kAXSizeAttribute, sizeValue)
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
