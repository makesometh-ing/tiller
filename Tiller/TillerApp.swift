//
//  TillerApp.swift
//  Tiller
//
//  Created by Gregory Orton on 2026/1/21.
//

import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var orchestrator: AutoTilingOrchestrator?
    private var leaderKeyManager: LeaderKeyManager?
    private var overlayPanel: LeaderOverlayPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        leader.onAction = { [weak orch] action in
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
        }
        let overlay = LeaderOverlayPanel(menuState: TillerMenuState.shared)
        self.overlayPanel = overlay

        leader.onStateChanged = { [weak overlay] state in
            TillerMenuState.shared.leaderState = state

            switch state {
            case .leaderActive, .subLayerActive:
                if let monitor = MonitorManager.shared.activeMonitor, overlay?.isVisible != true {
                    overlay?.show(on: monitor)
                }
            case .idle:
                overlay?.hide()
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
}

@main
struct TillerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            TillerMenuView(menuState: TillerMenuState.shared)
        } label: {
            HStack(spacing: 4) {
                Image("MenuBarIcon")
                Text(TillerMenuState.shared.statusText)
                    .font(.system(.body, design: .monospaced))
            }
            .help(TillerMenuState.shared.configErrorTooltip ?? "")
        }
    }
}
