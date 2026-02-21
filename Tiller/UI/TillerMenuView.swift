//
//  TillerMenuView.swift
//  Tiller
//

import SwiftUI

struct TillerMenuView: View {
    let menuState: TillerMenuState

    var body: some View {
        Toggle("Tiling", isOn: Binding(
            get: { menuState.isTilingEnabled },
            set: { _ in menuState.toggleTiling() }
        ))
        .disabled(!menuState.canToggleTiling)

        Divider()

        ForEach(Array(menuState.monitors.enumerated()), id: \.element.id) { index, monitor in
            let monitorIndex = index + 1
            let isActive = monitor.id == menuState.activeMonitorID

            Text(monitorLabel(index: monitorIndex, name: monitor.name, isActive: isActive))

            Button("  1-Monocle") {
                // No-op — Monocle is the only layout in Phase 1
            }
            .disabled(true)

            Divider()
        }

        Button("Settings...") {
            // Placeholder — no settings GUI in Phase 1
        }
        .disabled(true)

        Divider()

        Button("Quit Tiller") {
            menuState.quit()
        }
        .keyboardShortcut("q")
    }

    private func monitorLabel(index: Int, name: String, isActive: Bool) -> String {
        if isActive {
            return "[\(index)] \(index)-\(name)"
        } else {
            return "      \(index)-\(name)"
        }
    }
}
