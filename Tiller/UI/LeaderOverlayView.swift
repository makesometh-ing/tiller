//
//  LeaderOverlayView.swift
//  Tiller
//

import SwiftUI

struct LeaderOverlayView: View {
    let menuState: TillerMenuState

    var body: some View {
        VStack(spacing: 6) {
            keybindingHints
            layoutBar
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Keybinding Hints

    private var keybindingHints: some View {
        HStack(spacing: 16) {
            hintGroup("Cycle", keys: "< >")
            hintGroup("Move", keys: "h l")
            hintGroup("Focus", keys: "H L")
            hintGroup("Exit", keys: "esc")
        }
        .font(.system(size: 11))
    }

    private func hintGroup(_ label: String, keys: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(keys)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Layout Bar

    private var layoutBar: some View {
        HStack(spacing: 5) {
            ForEach(LayoutID.allCases, id: \.self) { layout in
                let isActive = layout == activeLayout
                if isActive {
                    activeKeycapGroup(layout: layout)
                } else {
                    keycap(layout: layout, isActive: false)
                }
            }
        }
    }

    private func activeKeycapGroup(layout: LayoutID) -> some View {
        HStack(spacing: 8) {
            keycap(layout: layout, isActive: true)
            Text(layout.displayName)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .padding(.vertical, 2)
        .padding(.leading, 2)
        .padding(.trailing, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func keycap(layout: LayoutID, isActive: Bool) -> some View {
        VStack(spacing: 1) {
            LayoutIconView(layout: layout, isActive: isActive)
            Text("\(layout.displayNumber)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.white.opacity(isActive ? 0.8 : 0.33))
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 3)
        .background(isActive ? Color.blue : Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    isActive ? Color.blue.opacity(0.8) : Color.white.opacity(0.12),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var activeLayout: LayoutID? {
        guard let monitorID = menuState.activeMonitorID else { return nil }
        return menuState.activeLayoutPerMonitor[monitorID]
    }
}
