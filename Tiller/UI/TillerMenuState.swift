//
//  TillerMenuState.swift
//  Tiller
//

import AppKit
import Foundation
import Observation

@Observable
final class TillerMenuState {

    static let shared = TillerMenuState(monitorManager: MonitorManager.shared)

    // MARK: - Observable State

    var isTilingEnabled: Bool = false
    var monitors: [MonitorInfo] = []
    var activeMonitorID: MonitorID?
    var activeLayoutPerMonitor: [MonitorID: LayoutID] = [:]
    var leaderState: LeaderState = .idle
    var hasConfigError: Bool = false
    var configErrorMessage: String?

    // MARK: - Status Text

    var statusText: String {
        let layerSegment: String
        switch leaderState {
        case .idle: layerSegment = "-"
        case .leaderActive: layerSegment = "*"
        case .subLayerActive(let key): layerSegment = key
        }
        let base = "\(activeMonitorNumber) | \(activeLayoutDisplayNumber) | \(layerSegment)"
        return hasConfigError ? "\(base) !" : base
    }

    var configErrorTooltip: String? {
        hasConfigError ? configErrorMessage : nil
    }

    private var activeMonitorNumber: Int {
        guard let activeID = activeMonitorID,
              let index = monitors.firstIndex(where: { $0.id == activeID }) else { return 1 }
        return index + 1
    }

    private var activeLayoutDisplayNumber: String {
        guard let activeID = activeMonitorID,
              let layout = activeLayoutPerMonitor[activeID] else {
            return "1"
        }
        return String(layout.displayNumber)
    }

    // MARK: - Dependencies

    private var orchestrator: AutoTilingOrchestrator?
    private var configManager: ConfigManager?
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

    func configureConfig(manager: ConfigManager) {
        self.configManager = manager
        self.hasConfigError = manager.hasConfigError
        self.configErrorMessage = manager.configErrorMessage
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

    func reloadConfig() {
        guard let configManager else { return }
        configManager.reloadConfiguration()
        hasConfigError = configManager.hasConfigError
        configErrorMessage = configManager.configErrorMessage
    }

    func resetToDefaults() {
        let alert = NSAlert()
        alert.messageText = "Reset Configuration?"
        alert.informativeText = "This will reset all settings (keybindings, floating apps, ignored apps, and general settings) to their defaults. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let configManager else { return }
        configManager.resetToDefaults()
        hasConfigError = false
        configErrorMessage = nil
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Private

    private func refreshMonitors() {
        monitors = monitorManager.connectedMonitors
    }
}
