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

    func applicationDidFinishLaunching(_ notification: Notification) {
        ConfigManager.shared.loadConfiguration()

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

        let leader = LeaderKeyManager(configManager: ConfigManager.shared)
        leader.onAction = { [weak orch] action in
            guard let orch else { return }
            switch action {
            case .switchLayout(let layoutID):
                guard let activeMonitorID = MonitorManager.shared.activeMonitor?.id else { return }
                orch.switchLayout(to: layoutID, on: activeMonitorID)
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
        leader.start()
        self.leaderKeyManager = leader

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
        MenuBarExtra("Tiller", image: "MenuBarIcon") {
            TillerMenuView(menuState: TillerMenuState.shared)
        }
    }
}
