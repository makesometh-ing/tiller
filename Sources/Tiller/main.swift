import AppKit
import ApplicationServices
import Combine
import SwiftUI
import TillerCore

/// Launch arguments:
/// `--proof`: answer the proof runner notifications.
/// `--only-bundle-ids a,b`: manage only the windows of these apps.
/// `--dump-windows <path>`: write the Accessibility attributes of all windows to a JSON file, then quit.
/// `--focus-test <bundle id> <window id> <ax|all-windows> <path>`: focus one window, write the window order, then quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let leader = LeaderKey()
    private let store = ShortcutStore(arguments: CommandLine.arguments)
    private lazy var overlay = OverlayController(store: store)
    private lazy var settings = SettingsWindowController(model: SettingsModel(store: store, leaderKey: leader))
    /// Set by the proof runner `leader` step. The overlay is then reported after it is shown.
    private var reportOverlay = false
    private var controller: Controller!
    private var windowObserver: WindowObserver!
    private var statusItem: NSStatusItem!
    private var permissionItem: NSMenuItem!
    private var trustTimer: Timer?
    private var showInObserver: AnyCancellable?
    private var enabledObserver: AnyCancellable?
    private let proofMode = CommandLine.arguments.contains("--proof")
    private let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)

    func applicationWillTerminate(_ notification: Notification) {
        Log.event(.appTerminate)
        Log.shared.flush()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        let only = args.firstIndex(of: "--only-bundle-ids").flatMap { i in
            i + 1 < args.count ? Set(args[i + 1].split(separator: ",").map(String.init)) : nil
        }
        let ax = AXWindows(onlyBundleIDs: only)
        controller = Controller(ax: ax)
        windowObserver = WindowObserver(ax: ax, onFocus: { [weak self] in
            guard let self, store.enabled else { return }
            controller.focusChanged(clicked: leader.lastMouseDown)
        }, onWindows: { [weak self] trigger in
            guard let self, store.enabled else { return }
            controller.windowsChanged(trigger: trigger)
        })
        Log.event(.appLaunch, Diagnostics.systemFields(screens: ScreenInfo.all()).merging([
            "pid": .int(Int(getpid())), "proof": .bool(proofMode),
            "onlyBundleIds": only.map { .array($0.sorted().map(LogValue.string)) } ?? .null, "settings": .object(store.logFields),
        ]) { $1 })
        // `pkill` sends SIGTERM. The app then quits through `applicationWillTerminate`, so the log is written to disk.
        signal(SIGTERM, SIG_IGN)
        termSource.setEventHandler { NSApp.terminate(nil) }
        termSource.resume()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            Log.event(.displayChanged, ["screens": Diagnostics.systemFields(screens: ScreenInfo.all())["screens"] ?? .null])
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(named: "menubar")
        // A template image is drawn by macOS in the menu bar text color, for light and dark menu bars.
        icon?.isTemplate = true
        icon?.accessibilityDescription = "Tiller"
        statusItem.button?.image = icon
        let menu = NSMenu()
        let switchItem = NSMenuItem()
        switchItem.view = NSHostingView(rootView: MenuSwitchRow(store: store))
        switchItem.view?.frame.size = switchItem.view?.fittingSize ?? .zero
        switchItem.view?.autoresizingMask = .width
        menu.addItem(switchItem)
        menu.addItem(.separator())
        permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(withTitle: "Export Diagnostics…", action: #selector(exportDiagnosticsToDesktop), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Tiller", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // The app menu is shown in the menu bar when the activation policy is `.regular`.
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: "Export Diagnostics…", action: #selector(exportDiagnosticsToDesktop), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Tiller", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        NSApp.mainMenu = NSMenu()
        NSApp.mainMenu?.addItem(appItem)
        showInObserver = store.$showIn.sink { [weak self] in self?.apply($0) }
        enabledObserver = store.$enabled.dropFirst().sink { [weak self] enabled in
            guard let self else { return }
            if enabled { controller.rearrange() }
            // Waits for the moves. The report is sent only in a proof run.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.controller.reportCurrentState(action: "enabled=\(enabled)") }
        }

        leader.shortcuts = { [store] in store.shortcuts }
        leader.onLayerChange = { [weak self] active in
            // Leave the event tap callback first. Panel work in the callback delays all key presses.
            DispatchQueue.main.async { self?.layerChanged(active) }
        }
        leader.clickEndsLayer = { [weak self] point in !(self?.overlay.barContains(point) ?? false) }
        leader.isEnabled = { [store] in store.enabled }
        leader.onToggle = { [store] in store.setEnabled(!store.enabled, source: "globalShortcut") }
        leader.onAction = { [weak self] action, received in
            guard let self else { return }
            if action == .turnOff { store.setEnabled(false, source: "leaderKey"); return }
            controller.perform(action, received: received) { [weak self] in
                // Leader key mode continues after an action with the "Exit after" setting off.
                guard let self, leader.isLayerActive else { return }
                updateOverlay(since: received, syncFocus: false)
            }
        }
        leader.onCancel = { [weak self] in self?.controller.reportCurrentState(action: "cancel") }
        leader.onKeyList = { [weak self] in
            DispatchQueue.main.async {
                self?.overlay.toggleKeyList()
                if self?.proofMode == true {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.controller.reportCurrentState(action: "key-list") }
                }
            }
        }
        settings.model.exportDiagnostics = { [weak self] completion in self?.exportToDesktop(completion: completion) }
        if proofMode { setUpProof() }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            startTap()
        } else {
            permissionItem.title = "Accessibility permission: not granted"
            trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.startTap()
            }
        }
    }

    @objc private func openSettings() { settings.show() }

    @objc private func toggleEnabled() { store.setEnabled(!store.enabled, source: "dock") }

    /// Writes the diagnostics zip to the Desktop and shows it in Finder.
    @objc private func exportDiagnosticsToDesktop() { exportToDesktop {} }

    /// In a proof run, the path of the zip is sent to the proof runner.
    private func exportToDesktop(completion: @escaping () -> Void) {
        exportDiagnostics(to: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")) { [controller] url in
            if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            controller?.reportCurrentState(action: "export-button zip=\(url?.path ?? "failed")")
            completion()
        }
    }

    /// `completion` runs on the main thread with the URL of the zip.
    private func exportDiagnostics(to directory: URL, completion: @escaping (URL?) -> Void) {
        let system = Diagnostics.systemFields(screens: ScreenInfo.all())
        let settings = store.logFields
        let titles = store.logTitles
        DispatchQueue.global(qos: .userInitiated).async { [controller] in
            let url = Diagnostics.export(to: directory, system: system, settings: settings, titles: titles, controller: controller!)
            DispatchQueue.main.async { completion(url) }
        }
    }

    private func apply(_ showIn: ShowIn) {
        statusItem.isVisible = showIn != .dock
        NSApp.setActivationPolicy(showIn == .menuBar ? .accessory : .regular)
        // A change to `.accessory` deactivates the app after this function returns. The settings window is then behind other apps.
        // On the next run loop pass the app is still active, so the window is shown again 0.2 seconds later.
        if settings.isOpen { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [settings] in settings.show(page: settings.model.page) } }
    }

    /// A click on the Dock icon, or `open Tiller.app` while Tiller runs.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return false
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let enable = menu.addItem(withTitle: "Enable Tiller", action: #selector(toggleEnabled), keyEquivalent: "")
        enable.target = self
        enable.state = store.enabled ? .on : .off
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "").target = self
        return menu
    }

    private func layerChanged(_ active: Bool) {
        let start = DispatchTime.now()
        guard active else {
            overlay.hide()
            Log.event(.overlayHidden, ["hideMs": Log.ms(since: start)])
            return
        }
        overlay.show()
        let barMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
        updateOverlay(since: start, barMs: barMs)
    }

    /// Reads the containers and windows, and shows them in the overlay. `start` is the leader key press or the action key press.
    private func updateOverlay(since start: DispatchTime, barMs: Double? = nil, syncFocus: Bool = true) {
        controller.overlayScreens(syncFocus: syncFocus) { [weak self] screens, hiddenPills in
            guard let self, self.leader.isLayerActive else { return }
            self.overlay.update(screens)
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
            // After an action, `containersMs` is from the action key press.
            Log.event(.overlayShown, ["trigger": barMs == nil ? "action" : "leader", "barMs": barMs.map(LogValue.ms) ?? .null,
                                      "containersMs": .ms(ms), "screens": .int(screens.count), "pills": .int(screens.map(\.windows.count).reduce(0, +)),
                                      "hiddenPills": .int(hiddenPills), "keyBar": .bool(self.store.showKeyBar)])
            if self.reportOverlay {
                self.reportOverlay = false
                // Wait for the panels to draw before the proof runner takes a screenshot.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.controller.reportCurrentState(action: "overlay", latencyMs: ms) }
            }
        }
    }

    private func startTap() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--focus-test"), i + 4 < args.count {
            FocusTest.run(bundleID: args[i + 1], windowID: UInt32(args[i + 2]) ?? 0, method: args[i + 3], out: args[i + 4])
            NSApp.terminate(nil)
            return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--dump-windows"), i + 1 < CommandLine.arguments.count {
            WindowDump.write(to: CommandLine.arguments[i + 1])
            NSApp.terminate(nil)
            return
        }
        let started = leader.start()
        windowObserver.start()
        Log.event(.tapStarted, ["keyTap": .bool(started), "mouseTap": .bool(leader.mouseTapStarted)])
        permissionItem.title = started ? "Leader key: \(store.shortcuts.leader.map { $0.labels.joined(separator: " ") } ?? "none")" : "Event tap failed to start"
        if started && proofMode {
            DistributedNotificationCenter.default().postNotificationName(.init("com.tiller.proof.ready"), object: nil, userInfo: nil, deliverImmediately: true)
        }
    }

    /// The proof runner sends a key name. Tiller posts the leader key and that key as real key events,
    /// so that they go through the event tap. After the action, Tiller sends back an `ActionReport`.
    private func setUpProof() {
        controller.onReport = { report in
            let json = String(decoding: try! JSONEncoder().encode(report), as: UTF8.self)
            DistributedNotificationCenter.default().postNotificationName(.init("com.tiller.proof.result"), object: nil, userInfo: ["json": json], deliverImmediately: true)
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("com.tiller.proof.press"), object: nil, queue: .main) { [unowned self] note in
            guard let key = note.userInfo?["key"] as? String else { return }
            let leaderChord = self.store.shortcuts.leader
            switch key {
            case "hover":
                // Moves the mouse pointer over the `v` key, so that the screenshot shows the tooltip.
                if let point = self.overlay.firstKeyCenter() {
                    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
                }
                // A global event monitor doesn't receive mouse events that this app posts, so the hover is read again here.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.overlay.updateHover() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.controller.reportCurrentState(action: "hover") }
            case _ where key.hasPrefix("click:"):
                // A click at a visible point of a window, as a click with the mouse.
                let name = String(key.dropFirst("click:".count))
                self.controller.clickTarget(name) { target in
                    guard let target else { self.controller.reportCurrentState(action: "click:\(name) target-not-found"); return }
                    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: target.point, mouseButton: .left)?.post(tap: .cghidEventTap)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.controller.reportCurrentState(action: "click:\(name) window=\(target.id) layer=\(self.leader.isLayerActive)", expectedFocused: target.id)
                    }
                }
            case _ where key.hasPrefix("export-diagnostics:"):
                // The same export as the "Export Diagnostics…" menu item, to the directory after the colon. Finder isn't opened.
                let dir = URL(filePath: String(key.dropFirst("export-diagnostics:".count)))
                self.exportDiagnostics(to: dir) { url in
                    self.controller.reportCurrentState(action: "export-diagnostics zip=\(url?.lastPathComponent ?? "failed")")
                }
            case _ where key.hasPrefix("shortcuts-mode:"):
                // The same change as a click on the segmented control of the Shortcuts page.
                self.settings.model.shortcutsMode = ShortcutsMode(rawValue: String(key.dropFirst("shortcuts-mode:".count))) ?? .leader
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.controller.reportCurrentState(action: "shortcuts-mode:\(self.settings.model.shortcutsMode.rawValue)") }
            case _ where key.hasPrefix("global:"):
                // A global shortcut. The action sends the report. Without an action, the proof runner fails the step.
                guard let chord = KeyChord(spec: String(key.dropFirst("global:".count))) else { return }
                Self.post(chord)
            case _ where key.hasPrefix("window:"):
                // A command for the test windows app: `open`, `open-floating`, `close:<title>`, `minimize:<title>` or `unminimize:<title>`.
                DistributedNotificationCenter.default().postNotificationName(.init("com.tiller.testwindows.command"), object: nil,
                                                                             userInfo: ["command": String(key.dropFirst("window:".count))], deliverImmediately: true)
                self.reportWindowChange(key)
            case "close:focused":
                // A click on the close button of the system focused window, as a click on the red button with the mouse.
                if let app = NSWorkspace.shared.frontmostApplication,
                   let window = AXUIElementCreateApplication(app.processIdentifier).value(kAXFocusedWindowAttribute),
                   let button = (window as! AXUIElement).value(kAXCloseButtonAttribute), let frame = (button as! AXUIElement).frame {
                    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: CGPoint(x: frame.midX, y: frame.midY), mouseButton: .left)?.post(tap: .cghidEventTap)
                    }
                }
                self.reportWindowChange(key)
            case _ where key.hasPrefix("app:hide:") || key.hasPrefix("app:show:"):
                // `app:hide:<bundle id>` hides the app, as ⌘H does. `app:show:<bundle id>` shows the app again and activates it, as a click on its Dock icon does.
                for app in NSRunningApplication.runningApplications(withBundleIdentifier: String(key.dropFirst("app:hide:".count))) {
                    if key.hasPrefix("app:hide:") { app.hide() } else { app.unhide(); app.activate() }
                }
                self.reportWindowChange(key)
            case "move-bar":
                self.overlay.moveBar(dx: 120, dy: 60)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.controller.reportCurrentState(action: "move-bar") }
            case "leader":
                self.reportOverlay = true
                if let leaderChord { Self.post(leaderChord) }
            case _ where key == "settings" || key.hasPrefix("settings:"):
                self.settings.show(page: SettingsPage(rawValue: String(key.dropFirst("settings:".count))) ?? .general)
                // The proof runner takes a screenshot of the window with this number.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.controller.reportCurrentState(action: "settings:\(self.settings.model.page.rawValue) window=\(self.settings.windowNumber)")
                }
            case _ where key.hasPrefix("scroll:"):
                // A scroll wheel event over the center of the settings window, as a scroll with the mouse. A positive value scrolls down, in points.
                if let points = Int32(key.dropFirst("scroll:".count)), let center = self.settings.center {
                    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: center, mouseButton: .left)?.post(tap: .cghidEventTap)
                    let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -points, wheel2: 0, wheel3: 0)
                    scroll?.location = center
                    scroll?.post(tap: .cghidEventTap)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.controller.reportCurrentState(action: "\(key) window=\(self.settings.windowNumber)")
                }
            case "toggle:debugLogging":
                // The same change as a click on the "Debug logging" switch.
                self.store.setDebugLogging(!self.store.debugLogging)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.controller.reportCurrentState(action: "debugLogging=\(self.store.debugLogging)") }
            case "expire:debugLogging":
                // Debug logging on for 1 second instead of 24 hours. The timer then turns it off.
                self.store.setDebugLogging(true, duration: 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.controller.reportCurrentState(action: "debugLogging=\(self.store.debugLogging) after 1 s") }
            case "toggle:logTitles":
                // The same change as a click on the "Include window titles in logs" switch.
                self.store.logTitles.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.controller.reportCurrentState(action: "logTitles=\(self.store.logTitles)") }
            case _ where key.hasPrefix("press:"):
                // The button action sends the report.
                let title = String(key.dropFirst("press:".count))
                if !Self.pressButton(title) { self.controller.reportCurrentState(action: "press:\(title) button-not-found") }
            case "settings-close":
                self.settings.close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.controller.reportCurrentState(action: "settings-close") }
            case "toggle:showKeyBar":
                // The same change as a click on the "Show the key bar" switch.
                self.store.showKeyBar.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.controller.reportCurrentState(action: "showKeyBar=\(self.store.showKeyBar)") }
            case _ where key.hasPrefix("record:"):
                // The same call as a click on the shortcut field.
                let name = String(key.dropFirst("record:".count))
                let target: RecordTarget = name == "leader" ? .leader : name == "toggle" ? .toggle
                    : name.hasPrefix("global:") ? .global(ActionID(rawValue: String(name.dropFirst("global:".count)))!) : .action(ActionID(rawValue: name)!)
                self.settings.model.record(target)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.controller.reportCurrentState(action: "recording:\(name)") }
            case _ where key.hasPrefix("exit-after:"):
                // The same change as a click on the "Exit after" checkbox of the action.
                guard let id = ActionID(rawValue: String(key.dropFirst("exit-after:".count))) else { return }
                self.store.setExitAfter(!self.store.shortcuts.exits(after: id), for: id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.controller.reportCurrentState(action: "exitAfter:\(id.rawValue)=\(self.store.shortcuts.exits(after: id))") }
            case _ where key.hasPrefix("chord:") || key.hasPrefix("pass:"):
                // A key press without the leader key, for example the chord for a field that records.
                guard let chord = KeyChord(spec: String(key.split(separator: ":", maxSplits: 1)[1])) else { return }
                Self.post(chord)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.controller.reportCurrentState(action: "chord:\(chord.spec) leader=\(self.store.shortcuts.leader?.spec ?? "none") toggle=\(self.store.shortcuts.toggle?.spec ?? "none") global=[\(self.store.shortcuts.global.map { "\($0.key.rawValue)=\($0.value.spec)" }.sorted().joined(separator: ","))] refused=\(self.settings.model.refused?.text ?? "none") layer=\(self.leader.isLayerActive) enabled=\(self.store.enabled)") }
            default:
                guard let chord = KeyChord(spec: key) else { return }
                // A key after a `leader` step goes to the layer that the `leader` step started.
                if !self.leader.isLayerActive, let leaderChord { Self.post(leaderChord) }
                Self.post(chord)
            }
        }
    }

    /// Sends the report 1.2 seconds after a window step. A minimize takes about 0.5 seconds. After a new floating window and a hidden app,
    /// the expected focused window is the system focused window. After the other steps, it is the focused window of the workspace.
    private func reportWindowChange(_ key: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.controller.reportCurrentState(action: key, workspaceFocus: key != "window:open-floating" && !key.hasPrefix("app:hide:"))
        }
    }

    /// Presses the button with `title` in a Tiller window with the Accessibility API, as a click does. Returns false when the button isn't found.
    /// An Accessibility call to Tiller runs the AppKit code on the calling thread, so call it on the main thread.
    private static func pressButton(_ title: String) -> Bool {
        func find(_ e: AXUIElement) -> AXUIElement? {
            if e.value(kAXRoleAttribute) as? String == kAXButtonRole,
               [kAXTitleAttribute, kAXDescriptionAttribute].contains(where: { e.value($0) as? String == title }) { return e }
            return (e.value(kAXChildrenAttribute) as? [AXUIElement] ?? []).lazy.compactMap(find).first
        }
        guard let button = find(AXUIElementCreateApplication(getpid())) else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    private static func post(_ chord: KeyChord) {
        post(CGKeyCode(chord.keyCode), flags: chord.modifiers.eventFlags)
    }

    private static func post(_ code: CGKeyCode, flags: CGEventFlags) {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
