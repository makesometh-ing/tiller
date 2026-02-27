//
//  TillerApp.swift
//  Tiller
//
//  Created by Gregory Orton on 2026/1/21.
//

import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var orchestrator: AutoTilingOrchestrator?
    private var leaderKeyManager: LeaderKeyManager?
    private var overlayPanel: LeaderOverlayPanel?
    private var highlightManager: ContainerHighlightManager?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        let result = ConfigManager.shared.loadConfiguration()
        if case .fallbackToDefault = result {
            TillerMenuState.shared.hasConfigError = ConfigManager.shared.hasConfigError
            TillerMenuState.shared.configErrorMessage = ConfigManager.shared.configErrorMessage
        }

        AccessibilityManager.shared.onPermissionStatusChanged = { [weak self] status in
            if status == .granted {
                MonitorManager.shared.startMonitoring()
                WindowDiscoveryManager.shared.startMonitoring()

                Task { @MainActor in
                    self?.startOrchestrator()
                }
            }
        }

        AccessibilityManager.shared.requestPermissionsOnLaunch()
    }

    private func startOrchestrator() {
        let orch = AutoTilingOrchestrator(
            windowDiscoveryManager: WindowDiscoveryManager.shared,
            monitorManager: MonitorManager.shared,
            configManager: ConfigManager.shared,
            layoutEngine: FullscreenLayoutEngine(),
            animationService: WindowAnimationService()
        )
        self.orchestrator = orch

        TillerMenuState.shared.configure(orchestrator: orch)
        TillerMenuState.shared.configureConfig(manager: ConfigManager.shared)

        let leader = LeaderKeyManager(configManager: ConfigManager.shared)
        leader.onAction = { [weak orch, weak self] action in
            guard let orch else {
                TillerLogger.debug("keyboard", "[Action] Orchestrator deallocated, ignoring action: \(action)")
                return
            }
            TillerLogger.debug("keyboard", "[Action] Dispatching: \(action)")
            switch action {
            case .switchLayout(let layoutID):
                let monitorID = orch.activeMonitorID() ?? MonitorManager.shared.activeMonitor?.id
                guard let monitorID else {
                    TillerLogger.debug("keyboard", "[Action] switchLayout failed: no active monitor")
                    return
                }
                orch.switchLayout(to: layoutID, on: monitorID)
            case .moveWindow(let direction):
                orch.moveWindowToContainer(direction: direction)
            case .focusContainer(let direction):
                orch.focusContainer(direction: direction)
            case .cycleWindow(let direction):
                orch.cycleWindow(direction: direction)
            case .exitLeader:
                break
            }

            // Update container highlights after any action that may change focus
            if let monitorID = MonitorManager.shared.activeMonitor?.id {
                self?.highlightManager?.update(on: monitorID)
            }
        }
        let overlay = LeaderOverlayPanel(menuState: TillerMenuState.shared)
        self.overlayPanel = overlay

        let highlights = ContainerHighlightManager(orchestrator: orch, configManager: ConfigManager.shared)
        self.highlightManager = highlights

        leader.onStateChanged = { [weak overlay, weak highlights] state in
            TillerMenuState.shared.leaderState = state
            let monitorID = MonitorManager.shared.activeMonitor?.id

            switch state {
            case .leaderActive:
                if let monitor = MonitorManager.shared.activeMonitor, overlay?.isVisible != true {
                    overlay?.show(on: monitor)
                }
                if let monitorID { highlights?.show(on: monitorID) }
            case .subLayerActive:
                if let monitorID { highlights?.update(on: monitorID) }
            case .idle:
                overlay?.hide()
                highlights?.hide()
            }
        }
        leader.start()
        self.leaderKeyManager = leader

        ConfigManager.shared.onConfigReloaded = { [weak self] config in
            self?.leaderKeyManager?.updateBindings(from: config.keybindings)
        }

        Task {
            await orch.start()
            TillerMenuState.shared.isTilingEnabled = true
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(named: "MenuBarIcon")
        button.imagePosition = .imageLeading

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        observeStatusText()
    }

    private func updateStatusTitle() {
        statusItem?.button?.attributedTitle = NSAttributedString(
            string: TillerMenuState.shared.statusText,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]
        )
        statusItem?.button?.toolTip = TillerMenuState.shared.configErrorTooltip
    }

    private func observeStatusText() {
        withObservationTracking {
            _ = TillerMenuState.shared.statusText
            _ = TillerMenuState.shared.configErrorTooltip
        } onChange: {
            Task { @MainActor in
                self.updateStatusTitle()
                self.observeStatusText()
            }
        }
        updateStatusTitle()
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let state = TillerMenuState.shared

        let toggleTitle = state.isTilingEnabled
            ? "✓  Tiller is tiling your windows..."
            : "✗  Tiller is sleeping..."
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleTiling), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = state.canToggleTiling
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        for (monitorIdx, monitor) in state.monitors.enumerated() {
            let header = NSMenuItem(title: "[\(monitorIdx + 1)] \(monitor.name)", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for (layoutIdx, layout) in LayoutID.allCases.enumerated() {
                let isActive = state.activeLayoutPerMonitor[monitor.id] == layout
                let item = NSMenuItem(
                    title: "\(isActive ? "✓ " : "  ")\(layoutIdx + 1)-\(layout.displayName)",
                    action: #selector(switchLayout(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = monitorIdx * 100 + layoutIdx
                menu.addItem(item)
            }

            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(title: "Settings...", action: nil, keyEquivalent: "")
        settingsItem.isEnabled = false
        menu.addItem(settingsItem)

        let reloadTitle = state.hasConfigError && state.configErrorMessage != nil
            ? "Reload Config — \(state.configErrorMessage!)"
            : "Reload Config"
        let reloadItem = NSMenuItem(title: reloadTitle, action: #selector(reloadConfig), keyEquivalent: "")
        reloadItem.target = self
        menu.addItem(reloadItem)

        let resetItem = NSMenuItem(title: "Reset to Defaults", action: #selector(resetToDefaults), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Tiller", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func toggleTiling() { TillerMenuState.shared.toggleTiling() }
    @objc private func reloadConfig() { TillerMenuState.shared.reloadConfig() }
    @objc private func resetToDefaults() { TillerMenuState.shared.resetToDefaults() }
    @objc private func quitApp() { TillerMenuState.shared.quit() }

    @objc private func switchLayout(_ sender: NSMenuItem) {
        let state = TillerMenuState.shared
        let monitorIdx = sender.tag / 100
        let layoutIdx = sender.tag % 100
        guard monitorIdx < state.monitors.count, layoutIdx < LayoutID.allCases.count else { return }
        state.switchLayout(to: LayoutID.allCases[layoutIdx], on: state.monitors[monitorIdx].id)
    }
}

@main
struct TillerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
