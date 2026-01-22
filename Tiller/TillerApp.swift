//
//  TillerApp.swift
//  Tiller
//
//  Created by Gregory Orton on 2026/1/21.
//

import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ConfigManager.shared.loadConfiguration()
        AccessibilityManager.shared.requestPermissionsOnLaunch()

        AccessibilityManager.shared.onPermissionStatusChanged = { status in
            if status == .granted {
                MonitorManager.shared.startMonitoring()
            }
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
