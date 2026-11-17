import AppKit
import ApplicationServices

/// Writes the Accessibility attributes of every window of every regular app to a JSON file.
/// It is used to find which attributes tell main windows apart from dialogs, child windows and popups.
enum WindowDump {
    struct Entry: Codable {
        var app: String
        var bundleID: String
        var windowID: UInt32?
        var title: String
        var role: String?
        var subrole: String?
        var frame: [Double]?
        var minimized: Bool?
        var modal: Bool?
        var main: Bool?
        var focused: Bool?
        var sizeSettable: Bool
        var positionSettable: Bool
        var buttons: [String]
        var fullScreenButtonEnabled: Bool?
        /// The window server layer. 0 is the normal layer.
        var layer: Int?
        var onScreen: Bool
        /// The role of AXParent. A root window returns `AXApplication`.
        var parentRole: String?
        /// The result of the Tiller window rule: tiled, floating or ignored.
        var kind: String
    }

    /// `titles` is false for the diagnostics zip. Window titles can contain private text.
    static func write(to path: String, titles: Bool = true) {
        let info = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        var layers: [UInt32: Int] = [:], onScreen: [UInt32: Bool] = [:]
        for entry in info {
            guard let number = entry[kCGWindowNumber as String] as? UInt32 else { continue }
            layers[number] = entry[kCGWindowLayer as String] as? Int
            onScreen[number] = entry[kCGWindowIsOnscreen as String] as? Bool ?? false
        }
        let order = AXWindows.frontToBackOrder()
        var entries: [Entry] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 1.0)
            guard let windows = appElement.value(kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for w in windows {
                func settable(_ a: String) -> Bool {
                    var result = DarwinBoolean(false)
                    return AXUIElementIsAttributeSettable(w, a as CFString, &result) == .success && result.boolValue
                }
                let buttons = [kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXZoomButtonAttribute, kAXFullScreenButtonAttribute]
                    .filter { w.value($0) != nil }
                let fullScreenButton = w.value(kAXFullScreenButtonAttribute).map { $0 as! AXUIElement }
                let id = w.windowID
                let parent = w.value(kAXParentAttribute).flatMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil }
                let parentRole = parent?.value(kAXRoleAttribute) as? String
                let kind = id.map { "\(AXWindows.traits(w, id: $0, order: order).kind)" } ?? "ignored"
                entries.append(Entry(
                    app: app.localizedName ?? "", bundleID: app.bundleIdentifier ?? "", windowID: id,
                    title: titles ? w.value(kAXTitleAttribute) as? String ?? "" : "",
                    role: w.value(kAXRoleAttribute) as? String, subrole: w.value(kAXSubroleAttribute) as? String,
                    frame: w.frame.map { [$0.minX, $0.minY, $0.width, $0.height] },
                    minimized: w.value(kAXMinimizedAttribute) as? Bool, modal: w.value(kAXModalAttribute) as? Bool,
                    main: w.value(kAXMainAttribute) as? Bool, focused: w.value(kAXFocusedAttribute) as? Bool,
                    sizeSettable: settable(kAXSizeAttribute), positionSettable: settable(kAXPositionAttribute),
                    buttons: buttons, fullScreenButtonEnabled: fullScreenButton.flatMap { $0.value(kAXEnabledAttribute) as? Bool },
                    layer: id.flatMap { layers[$0] }, onScreen: id.flatMap { onScreen[$0] } ?? false,
                    parentRole: parentRole, kind: kind))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(entries).write(to: URL(filePath: path))
    }
}
