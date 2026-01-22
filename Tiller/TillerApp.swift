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

    func applicationDidFinishLaunching(_ notification: Notification) {
        ConfigManager.shared.loadConfiguration()

        // Set callback BEFORE requesting permissions (callback fires synchronously if already granted)
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
        orchestrator = AutoTilingOrchestrator(
            windowDiscoveryManager: WindowDiscoveryManager.shared,
            monitorManager: MonitorManager.shared,
            configManager: ConfigManager.shared,
            layoutEngine: FullscreenLayoutEngine(),
            animationService: WindowAnimationService()
        )

        Task {
            await orchestrator?.start()
        }
    }
}

@main
struct TillerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Tiller", systemImage: "bolt.fill") {
            Text("Hello world")
        }
    }
}
