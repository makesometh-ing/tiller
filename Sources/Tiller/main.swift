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
    private var statusItem: NSStatusItem!
    private var permissionItem: NSMenuItem!
    private var trustTimer: Timer?
    private var showInObserver: AnyCancellable?
    private var enabledObserver: AnyCancellable?
    private let proofMode = CommandLine.arguments.contains("--proof")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        let only = args.firstIndex(of: "--only-bundle-ids").flatMap { i in
            i + 1 < args.count ? Set(args[i + 1].split(separator: ",").map(String.init)) : nil
        }
        controller = Controller(ax: AXWindows(onlyBundleIDs: only))
        Log.write("launch pid=\(getpid()) proof=\(proofMode) only=\(only.map { $0.sorted().joined(separator: ",") } ?? "all")")

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
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Tiller", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // The app menu is shown in the menu bar when the activation policy is `.regular`.
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
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
            Log.write("layer \(active ? "start" : "end")")
            // Leave the event tap callback first. Panel work in the callback delays all key presses.
            DispatchQueue.main.async { self?.layerChanged(active) }
        }
        leader.isEnabled = { [store] in store.enabled }
        leader.onToggle = { [store] in store.enabled.toggle() }
        leader.onAction = { [weak self] action, received in
            guard let self else { return }
            if action == .turnOff { store.enabled = false; return }
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
        if proofMode { setUpProof() }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            startTap()
        } else {
            permissionItem.title = "Accessibility permission: not granted"
            Log.write("waiting for Accessibility permission")
            trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.startTap()
            }
        }
    }

    @objc private func openSettings() { settings.show() }

    @objc private func toggleEnabled() { store.enabled.toggle() }

    private func apply(_ showIn: ShowIn) {
        statusItem.isVisible = showIn != .dock
        NSApp.setActivationPolicy(showIn == .menuBar ? .accessory : .regular)
        Log.write("showIn=\(showIn.rawValue) statusItem=\(statusItem.isVisible) policy=\(NSApp.activationPolicy().rawValue)")
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
        guard active else { overlay.hide(); return }
        let start = DispatchTime.now()
        overlay.show()
        let barMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
        updateOverlay(since: start, barMs: barMs)
    }

    /// Reads the containers and windows, and shows them in the overlay. `start` is the leader key press or the action key press.
    private func updateOverlay(since start: DispatchTime, barMs: Double? = nil, syncFocus: Bool = true) {
        controller.overlayScreens(syncFocus: syncFocus) { [weak self] screens in
            guard let self, self.leader.isLayerActive else { return }
            self.overlay.update(screens)
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
            if let barMs {
                Log.write(String(format: "overlay barMs=%.1f containersMs=%.1f screens=%d keyBar=%@", barMs, ms, screens.count, self.store.showKeyBar ? "shown" : "hidden"))
            } else {
                Log.write(String(format: "overlay updated after action msSinceKeyPress=%.1f screens=%d", ms, screens.count))
            }
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
            Log.write("window dump written to \(CommandLine.arguments[i + 1])")
            NSApp.terminate(nil)
            return
        }
        let started = leader.start()
        permissionItem.title = started ? "Leader key: \(store.shortcuts.leader.map { $0.labels.joined(separator: " ") } ?? "none")" : "Event tap failed to start"
        Log.write(started ? "event tap started" : "event tap failed to start")
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
            case "leader":
                self.reportOverlay = true
                if let leaderChord { Self.post(leaderChord) }
            case _ where key == "settings" || key.hasPrefix("settings:"):
                self.settings.show(page: SettingsPage(rawValue: String(key.dropFirst("settings:".count))) ?? .general)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.controller.reportCurrentState(action: "settings") }
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
                self.settings.model.record(name == "leader" ? .leader : name == "toggle" ? .toggle : .action(ActionID(rawValue: name)!))
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.controller.reportCurrentState(action: "chord:\(chord.spec) leader=\(self.store.shortcuts.leader?.spec ?? "none") toggle=\(self.store.shortcuts.toggle?.spec ?? "none") layer=\(self.leader.isLayerActive) enabled=\(self.store.enabled)") }
            default:
                guard let chord = KeyChord(spec: key) else { return }
                // A key after a `leader` step goes to the layer that the `leader` step started.
                if !self.leader.isLayerActive, let leaderChord { Self.post(leaderChord) }
                Self.post(chord)
            }
        }
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
