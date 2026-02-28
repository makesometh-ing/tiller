//
//  AutoTilingOrchestrator.swift
//  Tiller
//

import AppKit
import CoreGraphics
import Foundation

final class AutoTilingOrchestrator {

    // MARK: - Dependencies

    private let windowDiscoveryManager: WindowDiscoveryManager
    private let monitorManager: MonitorManager
    private let configManager: ConfigManager
    private let layoutEngine: LayoutEngineProtocol
    private let animationService: WindowAnimationServiceProtocol
    private let config: OrchestratorConfig

    // MARK: - Callbacks

    var onLayoutChanged: ((MonitorID, LayoutID) -> Void)?

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

    /// Containers that need a one-time z-order refresh (e.g., after receiving moved windows).
    /// Cleared after each tile pass.
    private var containersNeedingZOrderRefresh: Set<ContainerID> = []

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

    // MARK: - Layout

    func activeLayout(for monitorID: MonitorID) -> LayoutID {
        monitorStates[monitorID]?.activeLayout ?? .monocle
    }

    /// Returns container frames and focused container ID for a monitor. Used by UI overlay.
    func containerInfo(for monitorID: MonitorID) -> (frames: [(id: ContainerID, frame: CGRect)], focusedID: ContainerID?)? {
        guard let state = monitorStates[monitorID] else { return nil }
        let frames = state.containers.map { (id: $0.id, frame: $0.frame) }
        return (frames, state.focusedContainerID)
    }

    func switchLayout(to layout: LayoutID, on monitorID: MonitorID) {
        guard var state = monitorStates[monitorID] else {
            TillerLogger.debug("orchestration", "[Action] switchLayout failed: no state for monitor \(monitorID.rawValue). Known monitors: \(monitorStates.keys.map { $0.rawValue })")
            return
        }
        guard state.activeLayout != layout else {
            TillerLogger.debug("orchestration", "[Action] switchLayout no-op: already on \(layout.rawValue)")
            return
        }

        let tillerConfig = configManager.getConfig()
        guard let monitor = monitorManager.connectedMonitors.first(where: { $0.id == monitorID }) else {
            TillerLogger.debug("orchestration", "[Action] switchLayout failed: monitor \(monitorID.rawValue) not in connectedMonitors")
            return
        }

        let containerFrames = LayoutDefinitions.containerFrames(
            for: layout,
            in: monitor.visibleFrame,
            margin: CGFloat(tillerConfig.margin),
            padding: CGFloat(tillerConfig.padding)
        )

        state.switchLayout(to: layout, containerFrames: containerFrames)
        monitorStates[monitorID] = state

        TillerLogger.debug("orchestration", "[Action] switchLayout to \(layout.rawValue) on monitor \(monitorID.rawValue)")
        scheduleRetile()
        onLayoutChanged?(monitorID, layout)
    }

    // MARK: - Window/Container Operations

    func cycleWindow(direction: CycleDirection) {
        guard let result = activeMonitorState() else {
            TillerLogger.debug("orchestration", "[Action] cycleWindow failed: activeMonitorState() returned nil")
            return
        }
        let (monitorID, windowID) = (result.0, result.2)
        var state = result.1
        state.cycleWindow(direction: direction, windowID: windowID)
        monitorStates[monitorID] = state

        if let newFocusID = state.containerForWindow(windowID)?.focusedWindowID {
            raiseAndActivateWindow(newFocusID)
        }

        TillerLogger.debug("orchestration", "[Action] cycleWindow \(direction) on monitor \(monitorID.rawValue)")
        scheduleRetile()
    }

    func moveWindowToContainer(direction: MoveDirection) {
        guard let result = activeMonitorState() else {
            TillerLogger.debug("orchestration", "[Action] moveWindow failed: activeMonitorState() returned nil")
            return
        }
        let (monitorID, windowID) = (result.0, result.2)
        var state = result.1
        state.moveWindow(from: windowID, direction: direction)
        monitorStates[monitorID] = state

        // Mark the destination container for a one-time z-order refresh
        if let dstContainer = state.containerForWindow(windowID) {
            containersNeedingZOrderRefresh.insert(dstContainer.id)
        }

        // Set z-order guard before raise/activate to suppress spurious AX focus events
        lastZOrderAdjustment = Date()

        // Activate the source container's next window so focus stays on source.
        // If the source emptied, moveWindow already shifted focusedContainerID
        // to the destination, so we activate that container's focused window.
        if let focusedCID = state.focusedContainerID,
           let container = state.containers.first(where: { $0.id == focusedCID }),
           let nextWindowID = container.focusedWindowID {
            raiseAndActivateWindow(nextWindowID)
        }

        TillerLogger.debug("orchestration", "[Action] moveWindow \(direction) on monitor \(monitorID.rawValue)")
        scheduleRetile()
    }

    func focusContainer(direction: MoveDirection) {
        guard let result = activeMonitorState() else {
            TillerLogger.debug("orchestration", "[Action] focusContainer failed: activeMonitorState() returned nil")
            return
        }
        let monitorID = result.0
        var state = result.1
        state.setFocusedContainer(direction: direction)
        monitorStates[monitorID] = state

        if let focusedCID = state.focusedContainerID,
           let container = state.containers.first(where: { $0.id == focusedCID }),
           let targetWindowID = container.focusedWindowID {
            raiseAndActivateWindow(targetWindowID)
        }

        TillerLogger.debug("orchestration", "[Action] focusContainer \(direction) on monitor \(monitorID.rawValue)")
        scheduleRetile()
    }

    /// Returns the monitor ID of the focused window, if found in any monitor state.
    func activeMonitorID() -> MonitorID? {
        let focusedWindowID = windowDiscoveryManager.focusedWindow?.windowID ?? lastFocusedWindowID
        guard let focusedWindowID else {
            return monitorStates.first?.key
        }
        for (monitorID, state) in monitorStates {
            if state.containerForWindow(focusedWindowID) != nil {
                return monitorID
            }
        }
        return monitorStates.first?.key
    }

    private func activeMonitorState() -> (MonitorID, MonitorTilingState, WindowID)? {
        // After z-order adjustments, windowDiscoveryManager.focusedWindow may report a
        // spurious focus caused by raising windows in non-active containers. Prefer our
        // own tracking during that window so actions operate on the correct container.
        let focusedWindowID: WindowID?
        if let lastAdjust = lastZOrderAdjustment,
           Date().timeIntervalSince(lastAdjust) < config.zOrderGuardDuration,
           let lastFocused = lastFocusedWindowID {
            focusedWindowID = lastFocused
        } else {
            focusedWindowID = windowDiscoveryManager.focusedWindow?.windowID ?? lastFocusedWindowID
        }
        guard let focusedWindowID else {
            TillerLogger.debug("orchestration", "[Action] activeMonitorState: no focused window (live query nil, no lastFocusedWindowID)")
            return nil
        }
        for (monitorID, state) in monitorStates {
            if state.containerForWindow(focusedWindowID) != nil {
                return (monitorID, state, focusedWindowID)
            }
        }
        // Focused window is stale (hidden/minimized/closed). Fall back to any container's focused window.
        TillerLogger.debug("orchestration", "[Action] activeMonitorState: focused window \(focusedWindowID.rawValue) not in any container, trying fallback")
        for (monitorID, state) in monitorStates {
            if let focusedCID = state.focusedContainerID,
               let container = state.containers.first(where: { $0.id == focusedCID }),
               let fallbackWindowID = container.focusedWindowID {
                lastFocusedWindowID = fallbackWindowID
                TillerLogger.debug("orchestration", "[Action] activeMonitorState: stale focus \(focusedWindowID.rawValue) → fallback to \(fallbackWindowID.rawValue)")
                return (monitorID, state, fallbackWindowID)
            }
        }
        // Log why fallback failed
        let containerCounts = monitorStates.map { (id, state) in
            let windowCount = state.containers.flatMap { $0.windowIDs }.count
            return "M\(id.rawValue):\(windowCount)w"
        }.joined(separator: " ")
        TillerLogger.debug("orchestration", "[Action] activeMonitorState: fallback failed - no container has windows (\(containerCounts))")
        return nil
    }

    // MARK: - Window Focus

    private func raiseAndActivateWindow(_ windowID: WindowID) {
        guard let window = windowDiscoveryManager.getWindow(byID: windowID) else {
            TillerLogger.debug("orchestration", "[Action] raiseAndActivateWindow: window \(windowID.rawValue) not found")
            return
        }
        NSRunningApplication(processIdentifier: window.ownerPID)?.activate()
        animationService.raiseWindowsInOrder([(windowID: windowID, pid: window.ownerPID)])

        // Update tracking immediately — the AX observer may not fire a focus event
        // for the raised window (e.g., debugger process, timing issues).
        lastFocusedWindowID = windowID

        TillerLogger.debug("orchestration", "[Action] raiseAndActivateWindow: raised window \(windowID.rawValue) (\(window.appName))")
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
           Date().timeIntervalSince(lastAdjust) < config.zOrderGuardDuration {
            TillerLogger.debug("orchestration","[Orchestrator] Ignoring focus change within 200ms of z-order adjustment")
            return
        }

        // Ignore if focus hasn't actually changed
        if focusedWindow?.windowID == lastFocusedWindowID {
            TillerLogger.debug("orchestration","[Orchestrator] Ignoring duplicate focus event for same window")
            return
        }

        lastFocusedWindowID = focusedWindow?.windowID

        // Update active monitor based on focused window position
        if let windowID = focusedWindow?.windowID,
           let window = windowDiscoveryManager.getWindow(byID: windowID) {
            monitorManager.updateActiveMonitor(forWindowAtPoint: CGPoint(x: window.frame.midX, y: window.frame.midY))

            // Update focused container to match the newly focused window.
            // No z-order refresh needed: macOS doesn't rearrange z-order of unfocused windows,
            // so the old container's accordion appearance stays intact without intervention.
            for (monitorID, var state) in monitorStates {
                if state.containerForWindow(windowID) != nil {
                    state.updateFocusedContainer(forWindow: windowID)
                    monitorStates[monitorID] = state
                    break
                }
            }
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

        let focusedID = focusedWindow?.windowID ?? lastFocusedWindowID

        // Prune monitor states for monitors that are no longer connected
        let connectedMonitorIDs = Set(monitors.map { $0.id })
        monitorStates = monitorStates.filter { connectedMonitorIDs.contains($0.key) }

        // Calculate layouts and collect animations per-container
        var allAnimations: [(windowID: WindowID, pid: pid_t, startFrame: CGRect, targetFrame: CGRect)] = []
        var allZOrderCalls: [(windowID: WindowID, pid: pid_t)] = []
        var didRaiseNonResizable = false
        var didRefreshNonActiveContainer = false

        for monitor in monitors {
            let monitorWindows = windowsByMonitor[monitor.id] ?? []

            // Get or create MonitorTilingState for this monitor
            let isNewState = monitorStates[monitor.id] == nil
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
            let removedWindowIDs = stateWindowIDs.subtracting(currentWindowIDs)
            for windowID in removedWindowIDs {
                state.removeWindow(windowID)
            }
            if !removedWindowIDs.isEmpty {
                let removedDesc = removedWindowIDs.map { String($0.rawValue) }.joined(separator: ", ")
                TillerLogger.debug("orchestration", "[Orchestrator] Removed windows no longer on monitor \(monitor.id.rawValue): [\(removedDesc)]")
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

                // Determine accordion focus for this container.
                // Prefer OS-focused window if it's in this container; fall back to container's internal focus.
                let tileableIDs = Set(containerWindows.filter { $0.isResizable }.map { $0.id })
                let containerFocusedID: WindowID? = {
                    if let fid = focusedID, container.windowIDs.contains(fid) {
                        return fid
                    }
                    return container.focusedWindowID
                }()
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
                    actualFocusedWindowID: containerFocusedID,
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

                // Whether the OS-focused window is in this container
                let osHasFocusInContainer = focusedID.map { container.windowIDs.contains($0) } ?? false

                // Only manage z-order for: active container (always), or non-active containers
                // that just received moved windows (one-time refresh to fix accordion appearance).
                let shouldManageZOrder = osHasFocusInContainer || containersNeedingZOrderRefresh.contains(container.id)

                if tileableCount > 1 && focusedIsTileable && shouldManageZOrder {
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

                    // For non-active containers, explicitly raise the focused window to the top.
                    // In the active container, the OS already keeps the focused window on top.
                    if !osHasFocusInContainer, let fid = containerFocusedID, let focusedWin = windowByID[fid] {
                        allZOrderCalls.append((windowID: fid, pid: focusedWin.ownerPID))
                        didRefreshNonActiveContainer = true
                    }
                } else if focusedIsNonResizable, let fid = containerFocusedID, let focusedWin = windowByID[fid] {
                    TillerLogger.debug("orchestration","[Orchestrator] Raising non-resizable window \(fid.rawValue) to top (overlay)")
                    allZOrderCalls.append((windowID: fid, pid: focusedWin.ownerPID))
                    didRaiseNonResizable = true
                }
            }

            // Save updated state
            monitorStates[monitor.id] = state

            if isNewState {
                onLayoutChanged?(monitor.id, state.activeLayout)
            }
        }

        // Recover from stale lastFocusedWindowID (e.g., window hidden via Cmd+H or minimized).
        // After the per-monitor loop above, the hidden window has been removed from containers
        // but lastFocusedWindowID may still point to it, causing activeMonitorState() to fail.
        if let lastFocused = lastFocusedWindowID,
           !monitorStates.values.contains(where: { $0.containerForWindow(lastFocused) != nil }) {
            TillerLogger.debug("orchestration", "[Orchestrator] Stale focus detected: window \(lastFocused.rawValue) no longer in any container")
            let liveFocused = windowDiscoveryManager.focusedWindow?.windowID
            if let live = liveFocused,
               monitorStates.values.contains(where: { $0.containerForWindow(live) != nil }) {
                lastFocusedWindowID = live
                TillerLogger.debug("orchestration", "[Orchestrator] Recovered stale focus → live focused window \(live.rawValue)")
            } else if let fallback = monitorStates.values
                .compactMap({ state in
                    state.focusedContainerID.flatMap { cid in
                        state.containers.first(where: { $0.id == cid })?.focusedWindowID
                    }
                }).first {
                lastFocusedWindowID = fallback
                TillerLogger.debug("orchestration", "[Orchestrator] Recovered stale focus → container fallback window \(fallback.rawValue)")
            } else {
                // All containers are empty - leader actions will fail until a window appears
                let totalWindows = monitorStates.values.flatMap { $0.containers.flatMap { $0.windowIDs } }.count
                lastFocusedWindowID = nil
                TillerLogger.debug("orchestration", "[Orchestrator] All containers empty (\(totalWindows) windows total) - leader actions unavailable until a window is focused")
            }
        }

        // Clear one-time z-order refresh flags
        containersNeedingZOrderRefresh.removeAll()

        guard !allAnimations.isEmpty else {
            let result = TilingResult.success(tiledCount: 0)
            lastTileResult = result
            return result
        }

        // After refreshing a non-active container's z-order (e.g. after moveWindowToContainer),
        // re-raise the OS-focused window so it stays on top of the non-active container's windows.
        if didRefreshNonActiveContainer, let fid = focusedID, let focusedWin = windowByID[fid] {
            allZOrderCalls.append((windowID: fid, pid: focusedWin.ownerPID))
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

nonisolated enum CycleDirection: Sendable {
    case next
    case previous
}

nonisolated enum MoveDirection: Sendable {
    case left
    case right
    case up
    case down
}
