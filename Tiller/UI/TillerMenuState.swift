//
//  TillerMenuState.swift
//  Tiller
//

import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class TillerMenuState {

    static let shared = TillerMenuState(monitorManager: MonitorManager.shared)

    // MARK: - Observable State

    var isTilingEnabled: Bool = false
    var monitors: [MonitorInfo] = []
    var activeMonitorID: MonitorID?
    var activeLayoutPerMonitor: [MonitorID: LayoutID] = [:]
    var leaderState: LeaderState = .idle

    // MARK: - Status Text

    var statusText: String {
        let layer = leaderState == .leaderActive ? "L" : "-"
        return "[\(activeMonitorNumber)] \(layer)"
    }

    private var activeMonitorNumber: Int {
        guard let activeID = activeMonitorID,
              let index = monitors.firstIndex(where: { $0.id == activeID }) else { return 1 }
        return index + 1
    }

    // MARK: - Dependencies

    private var orchestrator: AutoTilingOrchestrator?
    private let monitorManager: MonitorManager

    var canToggleTiling: Bool {
        orchestrator != nil
    }

    init(monitorManager: MonitorManager) {
        self.monitorManager = monitorManager
    }

    // MARK: - Configuration

    func configure(orchestrator: AutoTilingOrchestrator) {
        self.orchestrator = orchestrator
        self.isTilingEnabled = orchestrator.isCurrentlyRunning

        refreshMonitors()
        activeMonitorID = monitorManager.activeMonitor?.id

        for monitor in monitorManager.connectedMonitors {
            activeLayoutPerMonitor[monitor.id] = orchestrator.activeLayout(for: monitor.id)
        }

        orchestrator.onLayoutChanged = { [weak self] monitorID, layout in
            self?.activeLayoutPerMonitor[monitorID] = layout
        }

        monitorManager.onMonitorChange = { [weak self] _ in
            self?.refreshMonitors()
        }

        monitorManager.onActiveMonitorChanged = { [weak self] monitor in
            self?.activeMonitorID = monitor?.id
        }
    }

    // MARK: - Actions

    func toggleTiling() {
        guard let orchestrator else { return }

        if isTilingEnabled {
            orchestrator.stop()
            isTilingEnabled = false
        } else {
            Task {
                await orchestrator.start()
                isTilingEnabled = true
            }
        }
    }

    func switchLayout(to layout: LayoutID, on monitorID: MonitorID) {
        orchestrator?.switchLayout(to: layout, on: monitorID)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Private

    private func refreshMonitors() {
        monitors = monitorManager.connectedMonitors
    }
}
