import AppKit
import ApplicationServices

/// Focuses one window of an app with one focus method, then writes the front-to-back window order to a JSON file.
/// It is used to test which windows of an app come to the front when Tiller focuses one of its windows.
/// Usage: Tiller --focus-test <bundle id> <window id> <ax|all-windows|raise-floating|raise-floating-keep-focus> <output path>
enum FocusTest {
    struct Entry: Codable {
        var windowID: UInt32
        var owner: String
        var layer: Int
    }
    struct Result: Codable {
        var method: String
        var focusedWindowID: UInt32?
        var frontmostApp: String?
        /// On-screen windows at layer 0, front to back.
        var order: [Entry]
    }

    static func run(bundleID: String, windowID: UInt32, method: String, out: String) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let windows = appElement.value(kAXWindowsAttribute) as? [AXUIElement] ?? []
        guard let window = windows.first(where: { $0.windowID == windowID }) else { return }
        let ref = WindowRef(id: windowID, element: window, app: appElement, pid: app.processIdentifier, frame: window.frame ?? .zero, title: "")
        AXWindows(onlyBundleIDs: nil).focus(ref)
        if method == "all-windows" { app.activate(options: [.activateAllWindows]) }
        if method == "raise-floating" || method == "raise-floating-keep-focus" {
            let order = AXWindows.frontToBackOrder()
            for w in windows {
                guard let wid = w.windowID, AXWindows.traits(w, id: wid, order: order).kind == .floating else { continue }
                AXUIElementPerformAction(w, kAXRaiseAction as CFString)
            }
            // Focus goes to the raised window. These calls try to move focus back without a raise.
            if method == "raise-floating-keep-focus" {
                window.set(kAXMainAttribute, kCFBooleanTrue)
                window.set(kAXFocusedAttribute, kCFBooleanTrue)
            }
        }
        Thread.sleep(forTimeInterval: 0.5)

        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let order = info.compactMap { e -> Entry? in
            guard let n = e[kCGWindowNumber as String] as? UInt32, let layer = e[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
            return Entry(windowID: n, owner: e[kCGWindowOwnerName as String] as? String ?? "", layer: layer)
        }
        let result = Result(method: method, focusedWindowID: AXWindows(onlyBundleIDs: nil).focusedWindowID(),
                            frontmostApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier, order: order)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try? encoder.encode(result).write(to: URL(filePath: out))
    }
}
