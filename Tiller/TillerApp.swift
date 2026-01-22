//
//  TillerApp.swift
//  Tiller
//
//  Created by Gregory Orton on 2026/1/21.
//

import SwiftUI

@main
struct TillerApp: App {
    init() {
        ConfigManager.shared.loadConfiguration()
        AccessibilityManager.shared.requestPermissionsOnLaunch()

        AccessibilityManager.shared.onPermissionStatusChanged = { status in
            if status == .granted {
                // Future: initialize WindowDiscoveryService
            }
        }
    }

    var body: some Scene {
        MenuBarExtra("Tiller", systemImage: "bolt.fill") {
            Text("Hello world")
        }
    }
}
