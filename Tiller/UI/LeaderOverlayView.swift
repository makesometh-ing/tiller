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
        .font(.system(size: 11, design: .monospaced))
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
        HStack(spacing: 8) {
            ForEach(LayoutID.allCases, id: \.self) { layout in
                let isActive = layout == activeLayout
                HStack(spacing: 4) {
                    Text("\(layout.displayNumber)")
                        .font(.system(size: 12, weight: isActive ? .bold : .regular, design: .monospaced))
                    Text(layout.displayName)
                        .font(.system(size: 11, weight: isActive ? .medium : .regular))
                }
                .foregroundStyle(isActive ? .primary : .tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isActive
                        ? AnyShapeStyle(.tint.opacity(0.3))
                        : AnyShapeStyle(.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private var activeLayout: LayoutID? {
        guard let monitorID = menuState.activeMonitorID else { return nil }
        return menuState.activeLayoutPerMonitor[monitorID]
    }
}
