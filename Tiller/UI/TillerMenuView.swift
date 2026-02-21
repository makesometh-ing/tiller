//
//  TillerMenuView.swift
//  Tiller
//

import SwiftUI

struct TillerMenuView: View {
    let menuState: TillerMenuState

    var body: some View {
        Button {
            menuState.toggleTiling()
        } label: {
            if menuState.isTilingEnabled {
                Text("✓  Tiller is tiling your windows...")
            } else {
                Text("✗  Tiller is sleeping...")
            }
        }
        .disabled(!menuState.canToggleTiling)

        Divider()

        ForEach(Array(menuState.monitors.enumerated()), id: \.element.id) { index, monitor in
            let monitorIndex = index + 1

            Text("[\(monitorIndex)] \(monitor.name)")

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
}
