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

    /// Track when we last adjusted z-order to ignore async focus events
    private var lastZOrderAdjustment: Date?

    /// Track last focused window to avoid redundant z-order changes
    private var lastFocusedWindowID: WindowID?

    /// Track last focused tileable window for accordion freeze when non-resizable is focused
    private var lastFocusedTileableWindowID: WindowID?

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
            stableWindowOrder.removeAll()
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

        // Identify tileable windows (for accordion positioning and z-order)
        let tileableWindows = windows.filter { !$0.isFloating && $0.isResizable }
        let tileableIDs = Set(tileableWindows.map { $0.id })

        // Ring buffer includes all non-floating windows (tileable + non-resizable)
        // so non-resizable windows can be cycled to via keyboard shortcuts
        let nonFloatingWindows = windows.filter { !$0.isFloating }
        let nonFloatingIDs = Set(nonFloatingWindows.map { $0.id })

        stableWindowOrder.removeAll { !nonFloatingIDs.contains($0) }
        for window in nonFloatingWindows {
            if !stableWindowOrder.contains(window.id) {
                stableWindowOrder.append(window.id)
            }
        }

        // Create window lookup for sorting
        let windowByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })

        // Order windows by ring buffer position (floating windows excluded)
        let stableOrderedWindows = stableWindowOrder.compactMap { windowByID[$0] }

        let orderDesc = stableWindowOrder.map { String($0.rawValue) }.joined(separator: ", ")
        TillerLogger.debug("orchestration","[Orchestrator] Stable window order: [\(orderDesc)]")

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

        // Track last focused tileable window for accordion freeze
        let focusedID = focusedWindow?.windowID
        let focusedIsTileable = focusedID.map { tileableIDs.contains($0) } ?? false

        if let fid = focusedID, tileableIDs.contains(fid) {
            lastFocusedTileableWindowID = fid
        }

        // When a non-resizable window is focused, freeze the accordion:
        // pass the last focused tileable window ID so accordion positioning stays put
        let accordionFocusID: WindowID? = focusedIsTileable ? focusedID : lastFocusedTileableWindowID

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
                focusedWindowID: accordionFocusID,
                containerFrame: containerFrame,
                accordionOffset: tillerConfig.accordionOffset
            )

            let result = layoutEngine.calculate(input: input)

            // Position ALL windows - don't skip based on current position
            for placement in result.placements {
                guard let window = monitorWindows.first(where: { $0.id == placement.windowID }) else {
                    TillerLogger.debug("orchestration","[Orchestrator] Window \(placement.windowID.rawValue) not found in monitorWindows")
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
        }

        guard !allAnimations.isEmpty else {
            let result = TilingResult.success(tiledCount: 0)
            lastTileResult = result
            return result
        }

        // Z-order management: accordion z-order uses tileable windows only,
        // even though stableWindowOrder includes non-resizable windows for cycling.
        // DON'T raise focused window - it triggers focus events and it's already in front.
        let tileableRingOrder = stableWindowOrder.filter { tileableIDs.contains($0) }
        let tileableCount = tileableRingOrder.count
        let focusedIsNonResizable = focusedID.map { nonFloatingIDs.contains($0) && !tileableIDs.contains($0) } ?? false

        if tileableCount > 1 && focusedIsTileable {
            // Accordion z-order: position tileable windows as prev/focused/next
            var focusedTileableIdx = 0
            if let fid = focusedID, let idx = tileableRingOrder.firstIndex(of: fid) {
                focusedTileableIdx = idx
            }

            let prevIndex = (focusedTileableIdx - 1 + tileableCount) % tileableCount
            let nextIndex = (focusedTileableIdx + 1) % tileableCount

            var zOrder: [(windowID: WindowID, pid: pid_t)] = []

            // Add "others" (not prev, focused, or next)
            for (idx, windowID) in tileableRingOrder.enumerated() {
                if idx != focusedTileableIdx && idx != prevIndex && idx != nextIndex {
                    if let window = windowByID[windowID] {
                        zOrder.append((windowID: windowID, pid: window.ownerPID))
                    }
                }
            }

            // Add prev (if different from focused and next)
            if tileableCount > 2, let window = windowByID[tileableRingOrder[prevIndex]] {
                zOrder.append((windowID: tileableRingOrder[prevIndex], pid: window.ownerPID))
            }

            // Add next (if different from focused)
            if tileableCount > 1, nextIndex != focusedTileableIdx, let window = windowByID[tileableRingOrder[nextIndex]] {
                zOrder.append((windowID: tileableRingOrder[nextIndex], pid: window.ownerPID))
            }

            if !zOrder.isEmpty {
                let zOrderDesc = zOrder.map { String($0.windowID.rawValue) }.joined(separator: ", ")
                TillerLogger.debug("orchestration","[Orchestrator] Z-order (back to front, excluding focused): [\(zOrderDesc)]")
                lastZOrderAdjustment = Date()
                animationService.raiseWindowsInOrder(zOrder)
            }
        } else if focusedIsNonResizable, let fid = focusedID, let focusedWin = windowByID[fid] {
            // Non-resizable overlay: raise it above the frozen accordion
            TillerLogger.debug("orchestration","[Orchestrator] Raising non-resizable window \(fid.rawValue) to top (overlay)")
            lastZOrderAdjustment = Date()
            animationService.raiseWindowsInOrder([(windowID: fid, pid: focusedWin.ownerPID)])
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
        // These are windows the system reported as resizable but actually aren't
        // (e.g. iPhone Mirroring) — detected because AXSize set fails at tile-time.
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
