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

    /// Per-monitor tiling state: layout, containers, and window assignments
    private var monitorStates: [MonitorID: MonitorTilingState] = [:]

    /// Track when we last adjusted z-order to ignore async focus events
    private var lastZOrderAdjustment: Date?

    /// Track last focused window to avoid redundant z-order changes
    private var lastFocusedWindowID: WindowID?

    /// Per-container tracking of last focused tileable window for accordion freeze
    private var lastFocusedTileableWindowPerContainer: [ContainerID: WindowID] = [:]

    /// Windows that rejected resize at tile-time (detected via size-set failure).
    /// These are treated as non-resizable on subsequent tiles.
    private var resizeRejectedWindowIDs: Set<WindowID> = []

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

        // Perform initial tile BEFORE registering callbacks.
        // This prevents window events from triggering retiles while isInitialTile is true,
        // which would cause them to use duration=0 (instant) instead of animating.
        await performTile()
        isInitialTile = false

        windowDiscoveryManager.onWindowChange = { [weak self] event in
            self?.handleWindowChange(event)
        }

        windowDiscoveryManager.onFocusedWindowChanged = { [weak self] focusedWindow in
            self?.handleFocusChange(focusedWindow)
        }
    }

    func stop() {
        guard isRunning else { return }

        isRunning = false
        pendingRetileTask?.cancel()
        pendingRetileTask = nil
        windowDiscoveryManager.onWindowChange = nil
        windowDiscoveryManager.onFocusedWindowChanged = nil
    }

    // MARK: - Layout Switching

    func switchLayout(to layout: LayoutID, on monitorID: MonitorID) {
        guard var state = monitorStates[monitorID] else { return }
        guard state.activeLayout != layout else { return }

        let tillerConfig = configManager.getConfig()
        guard let monitor = monitorManager.connectedMonitors.first(where: { $0.id == monitorID }) else { return }

        let containerFrames = LayoutDefinitions.containerFrames(
            for: layout,
            in: monitor.visibleFrame,
            margin: CGFloat(tillerConfig.margin),
            padding: CGFloat(tillerConfig.padding)
        )

        let windows = windowDiscoveryManager.visibleWindows
        let windowFrames = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0.frame) })

        state.switchLayout(to: layout, containerFrames: containerFrames, windowFrames: windowFrames)
        monitorStates[monitorID] = state

        scheduleRetile()
    }

    // MARK: - Window/Container Operations (stubs for TILLER-48)

    func cycleWindow(direction: CycleDirection) {
        // Will be wired in TILLER-48
    }

    func moveWindowToContainer(direction: MoveDirection) {
        // Will be wired in TILLER-48
    }

    func focusContainer(direction: MoveDirection) {
        // Will be wired in TILLER-48
    }

    // MARK: - Event Handlers

    private func handleWindowChange(_ event: WindowChangeEvent) {
        switch event {
        case .windowOpened, .windowClosed:
            scheduleRetile()
        case .windowFocused:
            // Focus is handled by onFocusedWindowChanged callback with dedup logic
            break
        case .windowMoved, .windowResized:
            // Ignore move/resize to avoid fighting with user-initiated changes
            break
        }
    }

    private func handleFocusChange(_ focusedWindow: FocusedWindowInfo?) {
        // Ignore focus changes caused by our own z-order adjustments (within 200ms)
        if let lastAdjust = lastZOrderAdjustment,
           Date().timeIntervalSince(lastAdjust) < 0.2 {
            TillerLogger.debug("orchestration","[Orchestrator] Ignoring focus change within 200ms of z-order adjustment")
            return
        }

        // Ignore if focus hasn't actually changed
        if focusedWindow?.windowID == lastFocusedWindowID {
            TillerLogger.debug("orchestration","[Orchestrator] Ignoring duplicate focus event for same window")
            return
        }

        lastFocusedWindowID = focusedWindow?.windowID
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

        let rawWindows = windowDiscoveryManager.visibleWindows
        let focusedWindow = windowDiscoveryManager.focusedWindow

        guard !rawWindows.isEmpty else {
            monitorStates.removeAll()
            let result = TilingResult.noWindowsToTile
            lastTileResult = result
            return result
        }

        // Override isResizable for windows that rejected resize at tile-time
        let windows = rawWindows.map { window -> WindowInfo in
            if resizeRejectedWindowIDs.contains(window.id) && window.isResizable {
                TillerLogger.debug("orchestration", "[Orchestrator] Overriding window \(window.id.rawValue) (\(window.appName)) to non-resizable (resize rejected at tile-time)")
                return WindowInfo(
                    id: window.id,
                    title: window.title,
                    appName: window.appName,
                    bundleID: window.bundleID,
                    frame: window.frame,
                    isResizable: false,
                    isFloating: window.isFloating,
                    ownerPID: window.ownerPID
                )
            }
            return window
        }

        // Non-floating windows participate in tiling
        let nonFloatingWindows = windows.filter { !$0.isFloating }

        // Create window lookup
        let windowByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })

        let tillerConfig = configManager.getConfig()
        let monitors = monitorManager.connectedMonitors

        guard !monitors.isEmpty else {
            let result = TilingResult.failed(reason: "No monitors detected")
            lastTileResult = result
            return result
        }

        // Group non-floating windows by monitor using their center point
        var windowsByMonitor: [MonitorID: [WindowInfo]] = [:]

        for window in nonFloatingWindows {
            let centerPoint = CGPoint(
                x: window.frame.midX,
                y: window.frame.midY
            )

            if let monitor = monitors.first(where: { $0.frame.contains(centerPoint) }) {
                windowsByMonitor[monitor.id, default: []].append(window)
            } else if let mainMonitor = monitors.first(where: { $0.isMain }) {
                windowsByMonitor[mainMonitor.id, default: []].append(window)
            } else if let firstMonitor = monitors.first {
                windowsByMonitor[firstMonitor.id, default: []].append(window)
            }
        }

        let focusedID = focusedWindow?.windowID

        // Prune monitor states for monitors that are no longer connected
        let connectedMonitorIDs = Set(monitors.map { $0.id })
        monitorStates = monitorStates.filter { connectedMonitorIDs.contains($0.key) }

        // Calculate layouts and collect animations per-container
        var allAnimations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)] = []
        var allZOrderCalls: [(windowID: WindowID, pid: pid_t)] = []
        var didRaiseNonResizable = false

        for monitor in monitors {
            let monitorWindows = windowsByMonitor[monitor.id] ?? []

            // Get or create MonitorTilingState for this monitor
            var state = monitorStates[monitor.id] ?? MonitorTilingState(monitorID: monitor.id)

            // Compute container frames from LayoutDefinitions
            let containerFrames = LayoutDefinitions.containerFrames(
                for: state.activeLayout,
                in: monitor.visibleFrame,
                margin: CGFloat(tillerConfig.margin),
                padding: CGFloat(tillerConfig.padding)
            )

            // Update container frames, preserving window assignments.
            // On first tile (empty containers), this falls through to redistributeWindows.
            // On subsequent tiles with same layout, frames update in place.
            state.updateContainerFrames(containerFrames)

            // Determine which windows should be in this monitor's containers
            let currentWindowIDs = Set(monitorWindows.map { $0.id })
            let stateWindowIDs = Set(state.containers.flatMap { $0.windowIDs })

            // Remove windows that are no longer on this monitor
            for windowID in stateWindowIDs where !currentWindowIDs.contains(windowID) {
                state.removeWindow(windowID)
            }

            // Add new windows (not yet in any container) to the focused container
            for window in monitorWindows where !stateWindowIDs.contains(window.id) {
                state.assignWindow(window.id)
            }

            let orderDesc = state.containers.map { container in
                let ids = container.windowIDs.map { String($0.rawValue) }.joined(separator: ",")
                return "C\(container.id.rawValue):[\(ids)]"
            }.joined(separator: " ")
            TillerLogger.debug("orchestration","[Orchestrator] Monitor \(monitor.id.rawValue) containers: \(orderDesc)")

            // Tile each container independently
            for container in state.containers {
                guard !container.windowIDs.isEmpty else { continue }

                // Build the ordered list of WindowInfo for this container
                let containerWindows = container.windowIDs.compactMap { windowByID[$0] }
                guard !containerWindows.isEmpty else { continue }

                // Determine accordion focus for this container
                let tileableIDs = Set(containerWindows.filter { $0.isResizable }.map { $0.id })
                let containerFocusedID = focusedID.flatMap { container.windowIDs.contains($0) ? $0 : nil }
                let focusedIsTileable = containerFocusedID.map { tileableIDs.contains($0) } ?? false

                // Track last focused tileable window per container
                if let fid = containerFocusedID, tileableIDs.contains(fid) {
                    lastFocusedTileableWindowPerContainer[container.id] = fid
                }

                let accordionFocusID: WindowID?
                if focusedIsTileable {
                    accordionFocusID = containerFocusedID
                } else {
                    accordionFocusID = lastFocusedTileableWindowPerContainer[container.id]
                }

                let input = LayoutInput(
                    windows: containerWindows,
                    focusedWindowID: accordionFocusID,
                    containerFrame: container.frame,
                    accordionOffset: tillerConfig.accordionOffset
                )

                let result = layoutEngine.calculate(input: input)

                for placement in result.placements {
                    guard let window = windowByID[placement.windowID] else {
                        TillerLogger.debug("orchestration","[Orchestrator] Window \(placement.windowID.rawValue) not found")
                        continue
                    }

                    TillerLogger.debug("orchestration","[Orchestrator] Window \(window.appName) (ID: \(window.id.rawValue)) -> \(placement.targetFrame.origin.x)")

                    allAnimations.append((
                        windowID: placement.windowID,
                        pid: placement.pid,
                        startFrame: window.frame,
                        targetFrame: placement.targetFrame
                    ))
                }

                // Per-container z-order management
                let tileableRingOrder = container.windowIDs.filter { tileableIDs.contains($0) }
                let tileableCount = tileableRingOrder.count
                let nonFloatingIDs = Set(container.windowIDs)
                let focusedIsNonResizable = containerFocusedID.map {
                    nonFloatingIDs.contains($0) && !tileableIDs.contains($0)
                } ?? false

                if tileableCount > 1 && focusedIsTileable {
                    var focusedTileableIdx = 0
                    if let fid = containerFocusedID, let idx = tileableRingOrder.firstIndex(of: fid) {
                        focusedTileableIdx = idx
                    }

                    let prevIndex = (focusedTileableIdx - 1 + tileableCount) % tileableCount
                    let nextIndex = (focusedTileableIdx + 1) % tileableCount

                    // Add "others" (not prev, focused, or next)
                    for (idx, windowID) in tileableRingOrder.enumerated() {
                        if idx != focusedTileableIdx && idx != prevIndex && idx != nextIndex {
                            if let window = windowByID[windowID] {
                                allZOrderCalls.append((windowID: windowID, pid: window.ownerPID))
                            }
                        }
                    }

                    // Add prev (if different from focused and next)
                    if tileableCount > 2, let window = windowByID[tileableRingOrder[prevIndex]] {
                        allZOrderCalls.append((windowID: tileableRingOrder[prevIndex], pid: window.ownerPID))
                    }

                    // Add next (if different from focused)
                    if tileableCount > 1, nextIndex != focusedTileableIdx, let window = windowByID[tileableRingOrder[nextIndex]] {
                        allZOrderCalls.append((windowID: tileableRingOrder[nextIndex], pid: window.ownerPID))
                    }
                } else if focusedIsNonResizable, let fid = containerFocusedID, let focusedWin = windowByID[fid] {
                    TillerLogger.debug("orchestration","[Orchestrator] Raising non-resizable window \(fid.rawValue) to top (overlay)")
                    allZOrderCalls.append((windowID: fid, pid: focusedWin.ownerPID))
                    didRaiseNonResizable = true
                }
            }

            // Save updated state
            monitorStates[monitor.id] = state
        }

        guard !allAnimations.isEmpty else {
            let result = TilingResult.success(tiledCount: 0)
            lastTileResult = result
            return result
        }

        // Execute z-order adjustments
        if !allZOrderCalls.isEmpty {
            let zOrderDesc = allZOrderCalls.map { String($0.windowID.rawValue) }.joined(separator: ", ")
            if didRaiseNonResizable {
                TillerLogger.debug("orchestration","[Orchestrator] Z-order (non-resizable overlay): [\(zOrderDesc)]")
            } else {
                TillerLogger.debug("orchestration","[Orchestrator] Z-order (back to front, excluding focused): [\(zOrderDesc)]")
            }
            lastZOrderAdjustment = Date()
            animationService.raiseWindowsInOrder(allZOrderCalls)
        }

        // Determine animation duration
        let duration: TimeInterval
        if isInitialTile && !config.animateOnInitialTile {
            duration = 0
        } else {
            duration = config.animationDuration
        }

        let animationResult = await animationService.animateBatch(allAnimations, duration: duration)

        // Check for windows that rejected resize during this tile pass.
        let newRejections = animationService.resizeRejectedWindowIDs.subtracting(resizeRejectedWindowIDs)
        if !newRejections.isEmpty {
            let rejectedDesc = newRejections.map { String($0.rawValue) }.joined(separator: ", ")
            TillerLogger.debug("orchestration", "[Orchestrator] Detected \(newRejections.count) new resize-rejected window(s): [\(rejectedDesc)] — will retile with corrected classification")
            resizeRejectedWindowIDs.formUnion(newRejections)
            animationService.clearResizeRejected()

            // Retile immediately with corrected classification (non-resizable → centered)
            return await performTile()
        }

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

// MARK: - Direction Types

enum CycleDirection: Sendable {
    case next
    case previous
}

enum MoveDirection: Sendable {
    case left
    case right
    case up
    case down
}
