//
//  AutoTilingOrchestrator.swift
//  Tiller
//

import CoreGraphics
import Foundation

@MainActor
final class AutoTilingOrchestrator {

    // MARK: - Dependencies

    private let windowDiscoveryManager: WindowDiscoveryManager
    private let monitorManager: MonitorManager
    private let configManager: ConfigManager
    private let layoutEngine: LayoutEngineProtocol
    private let animationService: WindowAnimationServiceProtocol
    private let config: OrchestratorConfig

    // MARK: - State

    private var isRunning: Bool = false
    private var pendingRetileTask: Task<Void, Never>?
    private var isInitialTile: Bool = true
    private var lastTileResult: TilingResult?

    /// Stable window order for ring buffer navigation (not affected by z-order changes)
    private var stableWindowOrder: [WindowID] = []

    /// Suppress focus-triggered retiles while we're adjusting z-order
    private var isAdjustingZOrder: Bool = false

    // MARK: - Initialization

    init(
        windowDiscoveryManager: WindowDiscoveryManager,
        monitorManager: MonitorManager,
        configManager: ConfigManager,
        layoutEngine: LayoutEngineProtocol,
        animationService: WindowAnimationServiceProtocol,
        config: OrchestratorConfig = .default
    ) {
        self.windowDiscoveryManager = windowDiscoveryManager
        self.monitorManager = monitorManager
        self.configManager = configManager
        self.layoutEngine = layoutEngine
        self.animationService = animationService
        self.config = config
    }

    // MARK: - Public API

    func start() async {
        guard !isRunning else { return }

        isRunning = true
        isInitialTile = true

        windowDiscoveryManager.onWindowChange = { [weak self] event in
            self?.handleWindowChange(event)
        }

        windowDiscoveryManager.onFocusedWindowChanged = { [weak self] focusedWindow in
            self?.handleFocusChange(focusedWindow)
        }

        await performTile()
        isInitialTile = false
    }

    func stop() {
        guard isRunning else { return }

        isRunning = false
        pendingRetileTask?.cancel()
        pendingRetileTask = nil
        windowDiscoveryManager.onWindowChange = nil
        windowDiscoveryManager.onFocusedWindowChanged = nil
    }

    // MARK: - Event Handlers

    private func handleWindowChange(_ event: WindowChangeEvent) {
        switch event {
        case .windowOpened, .windowClosed:
            scheduleRetile()
        case .windowFocused:
            scheduleRetile()
        case .windowMoved, .windowResized:
            // Ignore move/resize to avoid fighting with user-initiated changes
            break
        }
    }

    private func handleFocusChange(_ focusedWindow: FocusedWindowInfo?) {
        // Ignore focus changes caused by our own z-order adjustments
        guard !isAdjustingZOrder else {
            print("[Orchestrator] Ignoring focus change during z-order adjustment")
            return
        }
        // Focus changes trigger retile to update accordion positioning
        scheduleRetile()
    }

    // MARK: - Debouncing

    private func scheduleRetile() {
        pendingRetileTask?.cancel()
        pendingRetileTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                try await Task.sleep(nanoseconds: UInt64(self.config.debounceDelay * 1_000_000_000))

                guard !Task.isCancelled else { return }
                await self.performTile()
            } catch {
                // Task was cancelled, which is expected during debouncing
            }
        }
    }

    // MARK: - Tiling Logic

    @discardableResult
    func performTile() async -> TilingResult {
        guard isRunning else {
            let result = TilingResult.cancelled
            lastTileResult = result
            return result
        }

        let windows = windowDiscoveryManager.visibleWindows
        let focusedWindow = windowDiscoveryManager.focusedWindow

        guard !windows.isEmpty else {
            stableWindowOrder.removeAll()
            let result = TilingResult.noWindowsToTile
            lastTileResult = result
            return result
        }

        // Update stable window order: keep existing order, add new windows, remove closed ones
        let currentWindowIDs = Set(windows.map { $0.id })
        stableWindowOrder.removeAll { !currentWindowIDs.contains($0) }
        for window in windows {
            if !stableWindowOrder.contains(window.id) {
                stableWindowOrder.append(window.id)
            }
        }

        // Create window lookup for sorting
        let windowByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })

        // Sort windows by stable order
        let stableOrderedWindows = stableWindowOrder.compactMap { windowByID[$0] }

        print("[Orchestrator] Stable window order: \(stableWindowOrder.map { $0.rawValue })")

        let tillerConfig = configManager.getConfig()
        let monitors = monitorManager.connectedMonitors

        guard !monitors.isEmpty else {
            let result = TilingResult.failed(reason: "No monitors detected")
            lastTileResult = result
            return result
        }

        // Group windows by monitor using their center point (maintaining stable order)
        var windowsByMonitor: [MonitorID: [WindowInfo]] = [:]

        for window in stableOrderedWindows {
            let centerPoint = CGPoint(
                x: window.frame.midX,
                y: window.frame.midY
            )

            if let monitor = monitors.first(where: { $0.frame.contains(centerPoint) }) {
                windowsByMonitor[monitor.id, default: []].append(window)
            } else if let mainMonitor = monitors.first(where: { $0.isMain }) {
                // Fallback to main monitor if window center isn't in any monitor
                windowsByMonitor[mainMonitor.id, default: []].append(window)
            } else if let firstMonitor = monitors.first {
                // Fallback to first monitor
                windowsByMonitor[firstMonitor.id, default: []].append(window)
            }
        }

        // Calculate layouts and collect animations for each monitor
        var allAnimations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)] = []

        for monitor in monitors {
            guard let monitorWindows = windowsByMonitor[monitor.id], !monitorWindows.isEmpty else {
                continue
            }

            // Calculate container frame with margins
            let margin = CGFloat(tillerConfig.margin)
            let containerFrame = monitor.visibleFrame.insetBy(dx: margin, dy: margin)

            let input = LayoutInput(
                windows: monitorWindows,
                focusedWindowID: focusedWindow?.windowID,
                containerFrame: containerFrame,
                accordionOffset: tillerConfig.accordionOffset
            )

            let result = layoutEngine.calculate(input: input)

            // Position ALL windows - don't skip based on current position
            for placement in result.placements {
                guard let window = monitorWindows.first(where: { $0.id == placement.windowID }) else {
                    print("[Orchestrator] Window \(placement.windowID.rawValue) not found in monitorWindows")
                    continue
                }

                print("[Orchestrator] Window \(window.appName) (ID: \(window.id.rawValue)) -> \(placement.targetFrame.origin.x)")

                allAnimations.append((
                    windowID: placement.windowID,
                    pid: placement.pid,
                    startFrame: window.frame,
                    targetFrame: placement.targetFrame
                ))
            }
        }

        guard !allAnimations.isEmpty else {
            let result = TilingResult.success(tiledCount: 0)
            lastTileResult = result
            return result
        }

        // Set z-order BEFORE positioning to avoid flickering
        // Order: others (back) -> prev -> next -> focused (front)
        let focusedID = focusedWindow?.windowID
        var focusedIndex = 0
        if let fid = focusedID, let idx = stableWindowOrder.firstIndex(of: fid) {
            focusedIndex = idx
        }

        let windowCount = stableWindowOrder.count
        if windowCount > 0 {
            let prevIndex = (focusedIndex - 1 + windowCount) % windowCount
            let nextIndex = (focusedIndex + 1) % windowCount

            // Build z-order: others first (back), then prev, then next, then focused (front)
            var zOrder: [(windowID: WindowID, pid: pid_t)] = []

            // Add "others" (not prev, focused, or next)
            for (idx, windowID) in stableWindowOrder.enumerated() {
                if idx != focusedIndex && idx != prevIndex && idx != nextIndex {
                    if let window = windowByID[windowID] {
                        zOrder.append((windowID: windowID, pid: window.ownerPID))
                    }
                }
            }

            // Add prev (if different from focused and next)
            if windowCount > 2, let window = windowByID[stableWindowOrder[prevIndex]] {
                zOrder.append((windowID: stableWindowOrder[prevIndex], pid: window.ownerPID))
            }

            // Add next (if different from focused)
            if windowCount > 1, let window = windowByID[stableWindowOrder[nextIndex]] {
                zOrder.append((windowID: stableWindowOrder[nextIndex], pid: window.ownerPID))
            }

            // Add focused (front)
            if let fid = focusedID, let window = windowByID[fid] {
                zOrder.append((windowID: fid, pid: window.ownerPID))
            }

            print("[Orchestrator] Z-order (back to front): \(zOrder.map { $0.windowID.rawValue })")
            isAdjustingZOrder = true
            animationService.raiseWindowsInOrder(zOrder)
            isAdjustingZOrder = false
        }

        // Determine animation duration
        let duration: TimeInterval
        if isInitialTile && !config.animateOnInitialTile {
            duration = 0
        } else {
            duration = config.animationDuration
        }

        let animationResult = await animationService.animateBatch(allAnimations, duration: duration)

        let result: TilingResult
        switch animationResult {
        case .completed:
            result = .success(tiledCount: allAnimations.count)
        case .cancelled:
            result = .cancelled
        case .failed(let error):
            result = .failed(reason: "Animation failed: \(error)")
        }

        lastTileResult = result
        return result
    }

    // MARK: - Test Helpers

    var isCurrentlyRunning: Bool {
        return isRunning
    }

    var lastResult: TilingResult? {
        return lastTileResult
    }

    var hasPendingRetile: Bool {
        return pendingRetileTask != nil && !pendingRetileTask!.isCancelled
    }
}
