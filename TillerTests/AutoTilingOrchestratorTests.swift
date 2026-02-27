//
//  AutoTilingOrchestratorTests.swift
//  TillerTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Tiller

struct AutoTilingOrchestratorTests {

    private let sut: AutoTilingOrchestrator
    private let mockWindowService: MockWindowService
    private let mockMonitorService: MockMonitorService
    private let mockLayoutEngine: MockLayoutEngine
    private let mockAnimationService: MockWindowAnimationService
    private let windowDiscoveryManager: WindowDiscoveryManager
    private let monitorManager: MonitorManager
    private let configManager: ConfigManager
    private let tempDirectory: URL

    init() throws {
        mockWindowService = MockWindowService()
        mockMonitorService = MockMonitorService()
        mockLayoutEngine = MockLayoutEngine()
        mockAnimationService = MockWindowAnimationService()

        windowDiscoveryManager = WindowDiscoveryManager(windowService: mockWindowService)
        monitorManager = MonitorManager(monitorService: mockMonitorService)

        // Set up temp directory for config
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        configManager = ConfigManager(
            fileManager: .default,
            basePath: tempDirectory.path,
            notificationService: MockNotificationService()
        )
        configManager.loadConfiguration()

        // Set up a default monitor
        let testMonitor = MockMonitorService.createTestMonitor(
            id: 1,
            name: "Test Monitor",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055),
            isMain: true
        )
        mockMonitorService.simulateMonitorConnect(testMonitor)

        // Start monitoring to enable event callbacks
        windowDiscoveryManager.startMonitoring()

        sut = AutoTilingOrchestrator(
            windowDiscoveryManager: windowDiscoveryManager,
            monitorManager: monitorManager,
            configManager: configManager,
            layoutEngine: mockLayoutEngine,
            animationService: mockAnimationService,
            config: OrchestratorConfig(debounceDelay: 0.01, animationDuration: 0.1, animateOnInitialTile: false, zOrderGuardDuration: 0)
        )
    }

    // MARK: - Helper Methods

    private func makeWindow(
        id: UInt32,
        frame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
        isFloating: Bool = false,
        isResizable: Bool = true
    ) -> WindowInfo {
        MockWindowService.createTestWindow(
            id: id,
            title: "Window \(id)",
            frame: frame,
            isResizable: isResizable,
            isFloating: isFloating
        )
    }

    /// Polls until the layout engine has been called at least the expected number of times,
    /// or times out after ~1 second. Replaces non-deterministic fixed sleeps.
    private func waitForRetile(
        expectedCallCount: Int = 1,
        timeout: Int = 20,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0..<timeout {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms per poll
            if mockLayoutEngine.calculateCallCount >= expectedCallCount { return }
        }
        Issue.record(
            "Timed out waiting for retile (expected \(expectedCallCount), got \(mockLayoutEngine.calculateCallCount))",
            sourceLocation: sourceLocation
        )
    }


    // MARK: - Initial Tiling Tests

    @Test func initialTiling() async {
        // Given: Multiple non-floating windows exist
        let window1 = makeWindow(id: 1, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        let window2 = makeWindow(id: 2, frame: CGRect(x: 200, y: 200, width: 800, height: 600))
        let window3 = makeWindow(id: 3, frame: CGRect(x: 300, y: 300, width: 800, height: 600))

        mockWindowService.windows = [window1, window2, window3]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id,
            appName: window1.appName,
            bundleID: window1.bundleID
        )

        // Set up layout engine to return placements
        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])

        // When: Orchestrator starts
        await sut.start()

        // Then: Layout engine was called and animations were triggered
        #expect(mockLayoutEngine.calculateCallCount == 1)
        #expect(mockAnimationService.batchAnimationCalls.count == 1)
        #expect(mockAnimationService.batchAnimationCalls.first?.animations.count == 3)

        // Verify initial tile doesn't animate (duration should be 0)
        #expect(mockAnimationService.batchAnimationCalls.first?.duration == 0)
    }

    @Test func initialTilingWithAnimation() async {
        // Given: Config with animateOnInitialTile = true
        sut.stop()
        let animatedSut = AutoTilingOrchestrator(
            windowDiscoveryManager: windowDiscoveryManager,
            monitorManager: monitorManager,
            configManager: configManager,
            layoutEngine: mockLayoutEngine,
            animationService: mockAnimationService,
            config: OrchestratorConfig(debounceDelay: 0.01, animationDuration: 0.25, animateOnInitialTile: true, zOrderGuardDuration: 0)
        )

        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame)
        ])

        // When: Orchestrator starts
        await animatedSut.start()

        // Then: Animation should use configured duration
        #expect(mockAnimationService.batchAnimationCalls.first?.duration == 0.25)
    }

    // MARK: - New Window Tests

    @Test func newWindowAdded() async {
        // Given: Orchestrator is running with one window
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        await sut.start()
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // When: A new window is added
        let window2 = makeWindow(id: 2)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039)),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        mockWindowService.simulateWindowOpenSync(window2)

        // Wait for debounce and retile
        await waitForRetile()

        // Then: Retile was triggered
        #expect(mockLayoutEngine.calculateCallCount >= 1)
        #expect(mockAnimationService.batchAnimationCalls.count >= 1)
    }

    // MARK: - Window Closed Tests

    @Test func windowClosed() async {
        // Given: Orchestrator is running with two windows
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        mockWindowService.windows = [window1, window2]
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039)),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        await sut.start()
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // When: A window is closed
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        mockWindowService.simulateWindowCloseSync(window2.id)

        // Wait for debounce and retile
        await waitForRetile()

        // Then: Retile was triggered
        #expect(mockLayoutEngine.calculateCallCount >= 1)
    }

    // MARK: - Floating Window Tests

    @Test func floatingWindowExcluded() async {
        // Given: One normal and one floating window
        let normalWindow = makeWindow(id: 1, isFloating: false)
        let floatingWindow = makeWindow(id: 2, isFloating: true)
        mockWindowService.windows = [normalWindow, floatingWindow]

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: normalWindow.id, pid: normalWindow.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        // When: Orchestrator starts
        await sut.start()

        // Then: Floating windows are excluded at orchestrator level -- only non-floating windows reach the engine
        #expect(mockLayoutEngine.calculateCallCount == 1)
        #expect(mockLayoutEngine.lastInput?.windows.count == 1)

        let inputWindows = mockLayoutEngine.lastInput?.windows ?? []
        #expect(inputWindows.contains(where: { $0.id == normalWindow.id }))
        #expect(!inputWindows.contains(where: { $0.id == floatingWindow.id }))
    }

    // MARK: - Multi-Monitor Tests

    @Test func multipleMonitorTiling() async {
        // Given: Two monitors with windows on each
        let monitor1 = MockMonitorService.createTestMonitor(
            id: 1,
            name: "Monitor 1",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055),
            isMain: true
        )
        let monitor2 = MockMonitorService.createTestMonitor(
            id: 2,
            name: "Monitor 2",
            frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1920, y: 25, width: 1920, height: 1055),
            isMain: false
        )

        mockMonitorService.monitors = [monitor1, monitor2]

        // Window on first monitor (center is within monitor1's frame)
        let window1 = makeWindow(id: 1, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        // Window on second monitor (center is within monitor2's frame)
        let window2 = makeWindow(id: 2, frame: CGRect(x: 2100, y: 100, width: 800, height: 600))

        mockWindowService.windows = [window1, window2]

        let targetFrame1 = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        let targetFrame2 = CGRect(x: 1928, y: 33, width: 1904, height: 1039)

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame1)
        ])

        // When: Orchestrator starts
        await sut.start()

        // Then: Layout engine was called for each monitor with windows
        #expect(mockLayoutEngine.calculateCallCount == 2)

        // Verify separate layouts per monitor
        let inputs = mockLayoutEngine.allInputs
        #expect(inputs.count == 2)

        // Check that each input has the correct container frame for its monitor
        let containerFrame1 = inputs.first(where: { $0.windows.contains(where: { $0.id == window1.id }) })?.containerFrame
        let containerFrame2 = inputs.first(where: { $0.windows.contains(where: { $0.id == window2.id }) })?.containerFrame

        #expect(containerFrame1 != nil)
        #expect(containerFrame2 != nil)
        #expect(containerFrame1 != containerFrame2)
    }

    // MARK: - Debouncing Tests

    @Test func rapidEventsDebounced() async {
        // Given: Orchestrator is running
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        await sut.start()
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // When: Multiple rapid window events occur
        for i in 2...10 {
            let newWindow = makeWindow(id: UInt32(i))
            mockWindowService.simulateWindowOpenSync(newWindow)
            mockWindowService.simulateWindowCloseSync(newWindow.id)
        }

        // Wait for debounce to settle
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Only a small number of retiles occurred (debounced)
        // With good debouncing, we expect far fewer than 18 calls (9 opens + 9 closes)
        #expect(mockLayoutEngine.calculateCallCount < 5)
    }

    // MARK: - Focus Change Tests

    @Test func windowFocusChangeUpdatesAccordion() async {
        // Given: Orchestrator is running with multiple windows
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        mockWindowService.windows = [window1, window2]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id,
            appName: window1.appName,
            bundleID: window1.bundleID
        )

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039)),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: CGRect(x: 1912, y: 33, width: 1904, height: 1039))
        ])

        await sut.start()

        // Wait for z-order suppression window (200ms) to expire
        try? await Task.sleep(nanoseconds: 250_000_000)

        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // Re-set the result after reset (reset clears it to empty)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039)),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: CGRect(x: 1912, y: 33, width: 1904, height: 1039))
        ])

        // When: Focus changes to window2
        // Update the mock's focused window (simulating the system focus change)
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window2.id,
            appName: window2.appName,
            bundleID: window2.bundleID
        )
        mockWindowService.simulateWindowFocusSync(window2.id)

        // Yield to allow the scheduled task to start, then wait for debounce
        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms > 10ms debounce

        // Then: Retile was triggered with new focused window
        #expect(mockLayoutEngine.calculateCallCount == 1)
        #expect(mockLayoutEngine.lastInput?.focusedWindowID == window2.id)
    }

    // MARK: - Start/Stop Tests

    @Test func startSetsRunningState() async {
        #expect(!sut.isCurrentlyRunning)

        await sut.start()

        #expect(sut.isCurrentlyRunning)
    }

    @Test func stopClearsRunningState() async {
        await sut.start()
        #expect(sut.isCurrentlyRunning)

        sut.stop()

        #expect(!sut.isCurrentlyRunning)
    }

    @Test func stopCancelsPendingRetile() async {
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [])

        await sut.start()
        mockLayoutEngine.reset()

        // Trigger a retile that will be debounced
        mockWindowService.simulateWindowOpenSync(makeWindow(id: 2))

        // Stop before debounce completes
        sut.stop()

        // Wait longer than debounce
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Should not have retiled after stop
        #expect(mockLayoutEngine.calculateCallCount == 0)
    }

    // MARK: - Edge Cases

    @Test func noWindowsReturnsNoWindowsToTile() async {
        mockWindowService.windows = []

        await sut.start()

        #expect(sut.lastResult == .noWindowsToTile)
    }

    @Test func noMonitorsReturnsFailed() async {
        mockMonitorService.monitors = []
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]

        await sut.start()

        if case .failed(let reason) = sut.lastResult {
            #expect(reason.contains("No monitors"))
        } else {
            Issue.record("Expected failed result with no monitors")
        }
    }

    @Test func windowsNotOnAnyMonitorFallbackToMain() async {
        // Given: A window whose center is outside all monitors
        let offscreenWindow = makeWindow(id: 1, frame: CGRect(x: 5000, y: 5000, width: 800, height: 600))
        mockWindowService.windows = [offscreenWindow]

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: offscreenWindow.id, pid: offscreenWindow.ownerPID, targetFrame: targetFrame)
        ])

        // When: Orchestrator starts
        await sut.start()

        // Then: Layout was still calculated (window assigned to main monitor)
        #expect(mockLayoutEngine.calculateCallCount == 1)
        #expect(mockLayoutEngine.lastInput?.windows.count == 1)
    }

    @Test func ignoresMoveEvents() async {
        // Given: Orchestrator is running
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [])

        await sut.start()
        mockLayoutEngine.reset()

        // When: Window is moved by user
        mockWindowService.simulateWindowMoveSync(window1.id, newFrame: CGRect(x: 200, y: 200, width: 800, height: 600))

        // Wait for any potential debounced retile
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then: No retile was triggered (we don't fight with user-initiated moves)
        #expect(mockLayoutEngine.calculateCallCount == 0)
    }

    @Test func ignoresResizeEvents() async {
        // Given: Orchestrator is running
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [])

        await sut.start()
        mockLayoutEngine.reset()

        // When: Window is resized by user
        mockWindowService.simulateWindowResizeSync(window1.id, newFrame: CGRect(x: 100, y: 100, width: 1000, height: 800))

        // Wait for any potential debounced retile
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then: No retile was triggered (we don't fight with user-initiated resizes)
        #expect(mockLayoutEngine.calculateCallCount == 0)
    }

    @Test func alwaysPositionsAllWindows() async {
        // Given: A window that's already at its target position
        let alreadyPositionedFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        let window1 = makeWindow(id: 1, frame: alreadyPositionedFrame)
        mockWindowService.windows = [window1]

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: alreadyPositionedFrame)
        ])

        // When: Orchestrator starts
        await sut.start()

        // Then: Animation is still triggered (we always position for z-order consistency)
        // Initial tile has duration=0 so we use instant positioning, but the batch call still happens
        #expect(mockAnimationService.batchAnimationCalls.count == 1)
        #expect(sut.lastResult == .success(tiledCount: 1))
    }

    // MARK: - Stable Window Order Tests

    @Test func windowOrderRemainsStableAcrossFocusChanges() async {
        // Given: Multiple windows in a specific order
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let window3 = makeWindow(id: 3)
        mockWindowService.windows = [window1, window2, window3]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id,
            appName: window1.appName,
            bundleID: window1.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()

        // Record initial input order
        let initialInputOrder = mockLayoutEngine.lastInput?.windows.map { $0.id } ?? []

        // Wait for z-order suppression window (200ms) to expire
        try? await Task.sleep(nanoseconds: 250_000_000)

        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // Re-set the result after reset (reset clears it to empty)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])

        // When: Focus changes to window3
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window3.id,
            appName: window3.appName,
            bundleID: window3.bundleID
        )
        mockWindowService.simulateWindowFocusSync(window3.id)

        // Yield to allow the scheduled task to start, then wait for debounce
        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms > 10ms debounce

        // Then: Window order in layout input should be stable (not reordered by z-order)
        let newInputOrder = mockLayoutEngine.lastInput?.windows.map { $0.id } ?? []
        #expect(initialInputOrder == newInputOrder, "Window order should remain stable across focus changes")
    }

    @Test func newWindowsAppendedToStableOrder() async {
        // Given: One window
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()
        mockLayoutEngine.reset()

        // When: A new window is added
        let window2 = makeWindow(id: 2)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        mockWindowService.simulateWindowOpenSync(window2)
        await waitForRetile()

        // Then: New window should be appended (window1 stays first)
        let inputOrder = mockLayoutEngine.lastInput?.windows.map { $0.id } ?? []
        #expect(inputOrder.first == window1.id, "Original window should remain first in order")
        #expect(inputOrder.last == window2.id, "New window should be appended to order")
    }

    @Test func closedWindowsRemovedFromStableOrder() async {
        // Given: Two windows
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        mockWindowService.windows = [window1, window2]

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()
        mockLayoutEngine.reset()

        // When: Window1 is closed
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        mockWindowService.simulateWindowCloseSync(window1.id)
        await waitForRetile()

        // Then: Only window2 remains
        let inputOrder = mockLayoutEngine.lastInput?.windows.map { $0.id } ?? []
        #expect(inputOrder.count == 1)
        #expect(inputOrder.first == window2.id)
    }

    // MARK: - Non-Resizable Window Ring Buffer Tests

    @Test func nonResizableWindowInRingButNotAccordionZOrder() async {
        // Given: Mix of resizable and non-resizable windows, tileable focused
        let tileableWindow1 = makeWindow(id: 1, isResizable: true)
        let tileableWindow2 = makeWindow(id: 2, isResizable: true)
        let nonResizableWindow = makeWindow(id: 3, frame: CGRect(x: 100, y: 100, width: 400, height: 300), isResizable: false)
        mockWindowService.windows = [tileableWindow1, tileableWindow2, nonResizableWindow]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: tileableWindow1.id,
            appName: tileableWindow1.appName,
            bundleID: tileableWindow1.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        let centeredFrame = CGRect(x: 760, y: 390, width: 400, height: 300)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: tileableWindow1.id, pid: tileableWindow1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: tileableWindow2.id, pid: tileableWindow2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: nonResizableWindow.id, pid: nonResizableWindow.ownerPID, targetFrame: centeredFrame)
        ])

        // When: Orchestrator starts
        await sut.start()

        // Then: All 3 windows passed to layout engine (non-resizable in ring buffer)
        #expect(mockLayoutEngine.lastInput?.windows.count == 3)

        // And: Accordion z-order only raises tileable windows (non-resizable not in accordion z-order)
        let raisedWindowIDs = Set(mockAnimationService.raiseOrderCalls.flatMap { $0.map { $0.windowID } })
        #expect(!raisedWindowIDs.contains(nonResizableWindow.id),
            "Non-resizable window should not be in accordion z-order raises")
    }

    @Test func nonResizableFocusedRaisesToTop() async {
        // Given: Mix of windows with non-resizable one focused
        let tileableWindow1 = makeWindow(id: 1, isResizable: true)
        let tileableWindow2 = makeWindow(id: 2, isResizable: true)
        let nonResizableWindow = makeWindow(id: 3, frame: CGRect(x: 100, y: 100, width: 400, height: 300), isResizable: false)
        mockWindowService.windows = [tileableWindow1, tileableWindow2, nonResizableWindow]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: nonResizableWindow.id,
            appName: nonResizableWindow.appName,
            bundleID: nonResizableWindow.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        let centeredFrame = CGRect(x: 760, y: 390, width: 400, height: 300)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: tileableWindow1.id, pid: tileableWindow1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: tileableWindow2.id, pid: tileableWindow2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: nonResizableWindow.id, pid: nonResizableWindow.ownerPID, targetFrame: centeredFrame)
        ])

        // When: Orchestrator starts (with non-resizable window focused)
        await sut.start()

        // Then: Non-resizable window is raised to top (overlay behavior)
        #expect(mockAnimationService.raiseOrderCalls.count == 1)
        let raisedWindows = mockAnimationService.raiseOrderCalls[0]
        #expect(raisedWindows.count == 1)
        #expect(raisedWindows[0].windowID == nonResizableWindow.id)
    }

    @Test func nonResizableFocusedFreezesAccordion() async {
        // Given: Start with tileable window 2 focused
        let tileableWindow1 = makeWindow(id: 1, isResizable: true)
        let tileableWindow2 = makeWindow(id: 2, isResizable: true)
        let nonResizableWindow = makeWindow(id: 3, frame: CGRect(x: 100, y: 100, width: 400, height: 300), isResizable: false)
        mockWindowService.windows = [tileableWindow1, tileableWindow2, nonResizableWindow]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: tileableWindow2.id,
            appName: tileableWindow2.appName,
            bundleID: tileableWindow2.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        let centeredFrame = CGRect(x: 760, y: 390, width: 400, height: 300)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: tileableWindow1.id, pid: tileableWindow1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: tileableWindow2.id, pid: tileableWindow2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: nonResizableWindow.id, pid: nonResizableWindow.ownerPID, targetFrame: centeredFrame)
        ])

        await sut.start()

        // Initial tile: layout engine should get tileableWindow2 as focused
        #expect(mockLayoutEngine.lastInput?.focusedWindowID == tileableWindow2.id)

        // Wait for z-order suppression (200ms) to expire -- use generous margin
        try? await Task.sleep(nanoseconds: 350_000_000)
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: tileableWindow1.id, pid: tileableWindow1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: tileableWindow2.id, pid: tileableWindow2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: nonResizableWindow.id, pid: nonResizableWindow.ownerPID, targetFrame: centeredFrame)
        ])

        // When: Focus changes to non-resizable window
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: nonResizableWindow.id,
            appName: nonResizableWindow.appName,
            bundleID: nonResizableWindow.bundleID
        )
        mockWindowService.simulateWindowFocusSync(nonResizableWindow.id)

        // Wait for debounce and retile
        await waitForRetile()

        // Then: Accordion freezes -- layout engine receives tileableWindow2 (last tileable focus),
        // NOT the non-resizable window's ID
        #expect(mockLayoutEngine.lastInput?.focusedWindowID == tileableWindow2.id,
            "Accordion should freeze at last tileable window when non-resizable is focused")
    }

    // MARK: - Focus Event Suppression Tests

    @Test func duplicateFocusEventsIgnored() async {
        // Given: Orchestrator is running with focused window
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        mockWindowService.windows = [window1, window2]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id,
            appName: window1.appName,
            bundleID: window1.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()
        mockLayoutEngine.reset()

        // When: Same window is focused multiple times rapidly
        for _ in 1...5 {
            mockWindowService.simulateWindowFocusSync(window1.id)
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should have minimal retiles (debounced + duplicate ignored)
        #expect(mockLayoutEngine.calculateCallCount <= 1,
            "Duplicate focus events for same window should be ignored")
    }

    // MARK: - Per-Container Architecture Tests

    @Test func twoMonitorsEachGetIndependentMonocleTiling() async {
        // Given: Two monitors with separate windows
        let monitor1 = MockMonitorService.createTestMonitor(
            id: 1,
            name: "Monitor 1",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055),
            isMain: true
        )
        let monitor2 = MockMonitorService.createTestMonitor(
            id: 2,
            name: "Monitor 2",
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1920, y: 25, width: 2560, height: 1415),
            isMain: false
        )
        mockMonitorService.monitors = [monitor1, monitor2]

        // Windows on monitor 1
        let win1 = makeWindow(id: 1, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        let win2 = makeWindow(id: 2, frame: CGRect(x: 200, y: 200, width: 800, height: 600))
        // Windows on monitor 2
        let win3 = makeWindow(id: 3, frame: CGRect(x: 2100, y: 100, width: 800, height: 600))

        mockWindowService.windows = [win1, win2, win3]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: win1.id, appName: win1.appName, bundleID: win1.bundleID
        )

        let targetFrame1 = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        let targetFrame2 = CGRect(x: 1928, y: 33, width: 2544, height: 1399)

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: win1.id, pid: win1.ownerPID, targetFrame: targetFrame1),
            WindowPlacement(windowID: win2.id, pid: win2.ownerPID, targetFrame: targetFrame1),
            WindowPlacement(windowID: win3.id, pid: win3.ownerPID, targetFrame: targetFrame2)
        ])

        // When: Orchestrator starts
        await sut.start()

        // Then: Layout engine called once per monitor (monocle = 1 container per monitor)
        #expect(mockLayoutEngine.calculateCallCount == 2)

        let inputs = mockLayoutEngine.allInputs
        #expect(inputs.count == 2)

        // Monitor 1 input should have 2 windows with monitor 1's container frame
        let m1Input = inputs.first(where: { $0.windows.count == 2 })
        #expect(m1Input != nil, "Monitor 1 should have 2 windows")
        #expect(m1Input?.windows.contains(where: { $0.id == win1.id }) ?? false)
        #expect(m1Input?.windows.contains(where: { $0.id == win2.id }) ?? false)

        // Monitor 2 input should have 1 window with monitor 2's container frame
        let m2Input = inputs.first(where: { $0.windows.count == 1 })
        #expect(m2Input != nil, "Monitor 2 should have 1 window")
        #expect(m2Input?.windows.contains(where: { $0.id == win3.id }) ?? false)

        // Container frames should be different (different monitor sizes)
        #expect(m1Input?.containerFrame != m2Input?.containerFrame,
            "Each monitor should have its own independent container frame")
    }

    @Test func windowAddedToCorrectMonitorContainer() async {
        // Given: Two monitors, orchestrator running with one window on each
        let monitor1 = MockMonitorService.createTestMonitor(
            id: 1, name: "Monitor 1",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055),
            isMain: true
        )
        let monitor2 = MockMonitorService.createTestMonitor(
            id: 2, name: "Monitor 2",
            frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1920, y: 25, width: 1920, height: 1055),
            isMain: false
        )
        mockMonitorService.monitors = [monitor1, monitor2]

        let win1 = makeWindow(id: 1, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        let win2 = makeWindow(id: 2, frame: CGRect(x: 2100, y: 100, width: 800, height: 600))
        mockWindowService.windows = [win1, win2]

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: win1.id, pid: win1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: win2.id, pid: win2.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // When: New window opens on monitor 2
        let win3 = makeWindow(id: 3, frame: CGRect(x: 2200, y: 200, width: 800, height: 600))
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: win1.id, pid: win1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: win2.id, pid: win2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: win3.id, pid: win3.ownerPID, targetFrame: targetFrame)
        ])

        mockWindowService.simulateWindowOpenSync(win3)
        await waitForRetile()

        // Then: Monitor 2 layout input should now have 2 windows
        let m2Inputs = mockLayoutEngine.allInputs.filter {
            $0.windows.contains(where: { $0.id == win2.id })
        }
        #expect(!m2Inputs.isEmpty, "Monitor 2 should have been tiled")

        let m2Input = m2Inputs.first(where: { $0.windows.contains(where: { $0.id == win3.id }) })
        #expect(m2Input != nil, "New window should be in monitor 2's layout input")

        // Monitor 1 should still have just 1 window
        let m1Input = mockLayoutEngine.allInputs.first(where: {
            $0.windows.contains(where: { $0.id == win1.id }) &&
            !$0.windows.contains(where: { $0.id == win3.id })
        })
        #expect(m1Input != nil, "Monitor 1 should still have just its original window")
    }

    // MARK: - Layout Switching Tests

    @Test func switchLayoutTriggersRetile() async {
        // Given: Orchestrator running with monocle layout
        let window1 = makeWindow(id: 1, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        let window2 = makeWindow(id: 2, frame: CGRect(x: 1100, y: 100, width: 800, height: 600))
        mockWindowService.windows = [window1, window2]

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()
        let initialCallCount = mockLayoutEngine.calculateCallCount
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // Provide fresh placements for the retile after layout switch
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        // When: Switch to split halves
        let monitorID = MonitorID(rawValue: 1)
        sut.switchLayout(to: .splitHalves, on: monitorID)

        // Wait for debounced retile
        await waitForRetile()

        // Then: Layout engine was called with split halves container frames (2 containers)
        #expect(mockLayoutEngine.calculateCallCount >= 1)

        // Split halves produces 2 containers, so layout engine should be called twice
        // (once per container)
        let inputs = mockLayoutEngine.allInputs
        #expect(inputs.count == 2, "Split halves should produce 2 container layout inputs")
    }

    @Test func switchLayoutSameLayoutNoOp() async {
        // Given: Orchestrator running with monocle layout
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        await sut.start()
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // When: Switch to same layout (monocle)
        let monitorID = MonitorID(rawValue: 1)
        sut.switchLayout(to: .monocle, on: monitorID)

        // Wait briefly to ensure nothing happens
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: No retile triggered
        #expect(mockLayoutEngine.calculateCallCount == 0)
    }

    // MARK: - Window/Container Operation Tests

    @Test func cycleWindowTriggersRetile() async {
        // Given: Orchestrator running with 3 windows in monocle
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let window3 = makeWindow(id: 3)
        mockWindowService.windows = [window1, window2, window3]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id, appName: window1.appName, bundleID: window1.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])

        // When: Cycle to next window
        sut.cycleWindow(direction: .next)
        await waitForRetile()

        // Then: Layout engine was called (retile triggered)
        #expect(mockLayoutEngine.calculateCallCount >= 1)
    }

    @Test func moveWindowToContainerTriggersRetile() async {
        // Given: Orchestrator running with split-halves layout
        let window1 = makeWindow(id: 1, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        let window2 = makeWindow(id: 2, frame: CGRect(x: 1100, y: 100, width: 800, height: 600))
        mockWindowService.windows = [window1, window2]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id, appName: window1.appName, bundleID: window1.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()

        // Switch to split halves to get 2 containers
        mockLayoutEngine.reset()
        mockAnimationService.reset()
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])
        sut.switchLayout(to: .splitHalves, on: MonitorID(rawValue: 1))
        await waitForRetile(expectedCallCount: 2)

        mockLayoutEngine.reset()
        mockAnimationService.reset()
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        // When: Move focused window (window1) to right container
        sut.moveWindowToContainer(direction: .right)
        await waitForRetile()

        // Then: Retile triggered
        #expect(mockLayoutEngine.calculateCallCount >= 1)
    }

    @Test func focusContainerTriggersRetile() async {
        // Given: Orchestrator running with split-halves layout
        let window1 = makeWindow(id: 1, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        let window2 = makeWindow(id: 2, frame: CGRect(x: 1100, y: 100, width: 800, height: 600))
        mockWindowService.windows = [window1, window2]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id, appName: window1.appName, bundleID: window1.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()

        // Switch to split halves
        mockLayoutEngine.reset()
        mockAnimationService.reset()
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])
        sut.switchLayout(to: .splitHalves, on: MonitorID(rawValue: 1))
        await waitForRetile(expectedCallCount: 2)

        mockLayoutEngine.reset()
        mockAnimationService.reset()
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        // When: Focus right container
        sut.focusContainer(direction: .right)
        await waitForRetile()

        // Then: Retile triggered
        #expect(mockLayoutEngine.calculateCallCount >= 1)
    }

    @Test func operationsNoOpWithNoFocusedWindow() async {
        // Given: Orchestrator running but no focused window
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]
        mockWindowService.focusedWindow = nil

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // When: All three operations called with no focused window
        sut.cycleWindow(direction: .next)
        sut.moveWindowToContainer(direction: .right)
        sut.focusContainer(direction: .right)

        // Wait briefly
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: No retile triggered (all no-ops)
        #expect(mockLayoutEngine.calculateCallCount == 0)
    }

    @Test func switchLayoutDoesNotAffectOtherMonitor() async {
        // Given: Two monitors, orchestrator running
        let monitor1 = MockMonitorService.createTestMonitor(
            id: 1, name: "Monitor 1",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055),
            isMain: true
        )
        let monitor2 = MockMonitorService.createTestMonitor(
            id: 2, name: "Monitor 2",
            frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1920, y: 25, width: 1920, height: 1055),
            isMain: false
        )
        mockMonitorService.monitors = [monitor1, monitor2]

        let win1 = makeWindow(id: 1, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        let win2 = makeWindow(id: 2, frame: CGRect(x: 2100, y: 100, width: 800, height: 600))
        mockWindowService.windows = [win1, win2]

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: win1.id, pid: win1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039)),
            WindowPlacement(windowID: win2.id, pid: win2.ownerPID, targetFrame: CGRect(x: 1928, y: 33, width: 1904, height: 1039))
        ])

        await sut.start()
        // Initial tile: 2 calls (1 container per monitor, each in monocle)
        #expect(mockLayoutEngine.calculateCallCount == 2)
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: win1.id, pid: win1.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039)),
            WindowPlacement(windowID: win2.id, pid: win2.ownerPID, targetFrame: CGRect(x: 1928, y: 33, width: 1904, height: 1039))
        ])

        // When: Switch monitor 1 to split halves
        sut.switchLayout(to: .splitHalves, on: MonitorID(rawValue: 1))
        await waitForRetile(expectedCallCount: 2)

        // Then: Monitor 1 has 2 containers (split), monitor 2 still has 1 (monocle)
        let inputs = mockLayoutEngine.allInputs

        // Monitor 2 input: should still have 1 window, unchanged monocle container frame
        let m2Input = inputs.first(where: { $0.windows.contains(where: { $0.id == win2.id }) })
        #expect(m2Input != nil, "Monitor 2 should still be tiled")

        // Monitor 1 should now have split containers (2 inputs for the 2 containers,
        // though only the non-empty ones get to the layout engine)
        let m1Inputs = inputs.filter { !$0.windows.contains(where: { $0.id == win2.id }) }
        #expect(m1Inputs.count >= 1, "Monitor 1 should have been retiled")
    }

    // MARK: - Z-Order Focus Change Regression Tests (TILLER-86)

    /// Helper: sets up split-halves with window1 in left container, window2+window3 in right container.
    /// Returns (window1, window2, window3) after initial tile + layout switch + retile are complete.
    /// Sets up split-halves layout with:
    ///   Left container:  window1 (1 window)
    ///   Right container: window2 + window3 (2 windows, focused)
    private func setupSplitHalvesWithFocus() async -> (WindowInfo, WindowInfo, WindowInfo) {
        let window1 = makeWindow(id: 1, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        let window2 = makeWindow(id: 2, frame: CGRect(x: 1100, y: 100, width: 800, height: 600))
        let window3 = makeWindow(id: 3, frame: CGRect(x: 1100, y: 200, width: 800, height: 600))
        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)

        // Step 1: Start with only window1 + window2, focus on window2
        mockWindowService.windows = [window1, window2]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window2.id, appName: window2.appName, bundleID: window2.bundleID
        )
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])
        await sut.start()

        // Step 2: Switch to split-halves → round-robin: window1 in left, window2 in right
        mockLayoutEngine.reset()
        mockAnimationService.reset()
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])
        sut.switchLayout(to: .splitHalves, on: MonitorID(rawValue: 1))
        await waitForRetile(expectedCallCount: 2)

        // Step 3: Focus window2 to set focusedContainerID to the right container.
        // switchLayout follows the ring buffer's focusedWindowID (window1, first added),
        // so focusedContainerID defaults to left. This focus event corrects it.
        mockWindowService.simulateWindowFocusSync(window2.id)
        mockLayoutEngine.reset()
        mockAnimationService.reset()
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])
        await waitForRetile(expectedCallCount: 2)

        // Step 4: Add window3 and tile — goes to focused container (right, where window2 is)
        mockWindowService.windows = [window1, window2, window3]
        mockLayoutEngine.reset()
        mockAnimationService.reset()
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])
        await sut.performTile()

        // Reset animation mock for the actual test (keep layoutEngine.allInputs for tests that inspect them)
        mockAnimationService.reset()

        return (window1, window2, window3)
    }

    @Test func focusChangeDoesNotTriggerZOrderForNonActiveContainer() async {
        // Given: Split halves, focus in right container (window2)
        let (window1, window2, window3) = await setupSplitHalvesWithFocus()

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])

        // When: OS focus changes to window1 (left container), then tile directly
        mockWindowService.simulateWindowFocusSync(window1.id)
        let raiseCountBefore = mockAnimationService.raiseOrderCalls.count
        await sut.performTile()

        // Then: No z-order calls should include windows from the right container.
        let newRaisedWindowIDs = mockAnimationService.raiseOrderCalls.dropFirst(raiseCountBefore).flatMap { $0.map(\.windowID) }
        #expect(!newRaisedWindowIDs.contains(window2.id), "Right container window2 should not be raised when focus moves to left container")
        #expect(!newRaisedWindowIDs.contains(window3.id), "Right container window3 should not be raised when focus moves to left container")
    }

    @Test func focusContainerDoesNotTriggerZOrderForOldContainer() async {
        // Given: Split halves, focus in right container (window2)
        let (window1, window2, window3) = await setupSplitHalvesWithFocus()

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])

        // When: Focus container switches left via keybinding, then tile directly.
        // focusContainer calls raiseAndActivateWindow(window1) which in real usage
        // causes the OS to update focus. Simulate that by updating the mock.
        sut.focusContainer(direction: .left)
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id, appName: window1.appName, bundleID: window1.bundleID
        )
        let raiseCountBefore = mockAnimationService.raiseOrderCalls.count
        await sut.performTile()

        // Then: Right container windows should NOT be raised (no z-order refresh for old container)
        let newRaisedWindowIDs = mockAnimationService.raiseOrderCalls.dropFirst(raiseCountBefore).flatMap { $0.map(\.windowID) }
        #expect(!newRaisedWindowIDs.contains(window2.id), "Old container window2 should not be z-order refreshed on focusContainer")
        #expect(!newRaisedWindowIDs.contains(window3.id), "Old container window3 should not be z-order refreshed on focusContainer")
    }

    @Test func focusChangeLeavesNonActiveContainerLayoutInputStable() async {
        // Given: Split halves, focus in right container (window2)
        let (window1, window2, window3) = await setupSplitHalvesWithFocus()

        // Capture layout inputs from the split-halves retile
        let rightContainerInputBefore = mockLayoutEngine.allInputs.last(where: {
            $0.windows.contains(where: { $0.id == window2.id })
        })
        #expect(rightContainerInputBefore != nil, "Right container should have been tiled")

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])

        // When: OS focus changes to window1 (left container), then tile directly
        mockWindowService.simulateWindowFocusSync(window1.id)
        await sut.performTile()

        // Then: Right container's layout input should be unchanged
        let rightContainerInputAfter = mockLayoutEngine.allInputs.last(where: {
            $0.windows.contains(where: { $0.id == window2.id })
        })
        #expect(rightContainerInputAfter != nil, "Right container should still be tiled after focus change")

        // The focused window and container frame should be stable
        #expect(rightContainerInputAfter?.focusedWindowID == rightContainerInputBefore?.focusedWindowID,
                "Right container accordion focus should not change when left container gets OS focus")
        #expect(rightContainerInputAfter?.containerFrame == rightContainerInputBefore?.containerFrame,
                "Right container frame should not change on focus change")
    }

    @Test func focusedWindowIsLastInZOrderCalls() async {
        // Given: Split halves, window1 in left, window2+window3 in right
        let (window1, window2, window3) = await setupSplitHalvesWithFocus()

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window3.id, pid: window3.ownerPID, targetFrame: targetFrame)
        ])

        // When: Move window from right to left (triggers z-order refresh on destination), then tile directly
        sut.moveWindowToContainer(direction: .left)
        let raiseCountBefore = mockAnimationService.raiseOrderCalls.count
        await sut.performTile()

        // Then: If there are z-order calls, the OS-focused window should be the last one raised
        let allRaisedWindowIDs = Array(mockAnimationService.raiseOrderCalls.dropFirst(raiseCountBefore)).flatMap { $0.map(\.windowID) }
        if !allRaisedWindowIDs.isEmpty {
            let focusedID = mockWindowService.focusedWindow?.windowID
            if let fid = focusedID, allRaisedWindowIDs.contains(fid) {
                #expect(allRaisedWindowIDs.last == fid,
                        "The OS-focused window should be the last z-order call to ensure it stays on top")
            }
        }
    }

    // MARK: - Stale Focus Recovery Tests (TILLER-88)

    @Test func leaderActionsWorkAfterFocusedWindowHidden() async {
        // Given: Two windows, window1 focused
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        mockWindowService.windows = [window1, window2]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id, appName: window1.appName, bundleID: window1.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()

        // Simulate window1 being hidden (Cmd+H): remove from visible windows, clear focus
        mockWindowService.windows = [window2]
        mockWindowService.focusedWindow = nil
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        // Trigger retile (simulates what happens when hidden window disappears from CGWindowList)
        mockWindowService.simulateWindowCloseSync(window1.id)
        await waitForRetile(expectedCallCount: 2)

        // When: User tries a leader action (e.g., move window) — should NOT return nil
        let monitorID = sut.activeMonitorID()

        // Then: A valid monitor is returned (focus recovered to window2)
        #expect(monitorID != nil, "Should recover focus to remaining window after hide")
    }

    @Test func activeMonitorStateFallsBackWhenFocusedWindowStale() async {
        // Given: Two windows in split halves, window1 focused
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        mockWindowService.windows = [window1, window2]
        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: window1.id, appName: window1.appName, bundleID: window1.bundleID
        )

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame),
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])

        await sut.start()

        // Switch to split halves so we have two containers
        sut.switchLayout(to: .splitHalves, on: MonitorID(rawValue: 1))
        mockLayoutEngine.reset()
        mockAnimationService.reset()

        // Simulate window1 hidden + retile: window1 removed from containers
        mockWindowService.windows = [window2]
        mockWindowService.focusedWindow = nil
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window2.id, pid: window2.ownerPID, targetFrame: targetFrame)
        ])
        await sut.performTile()

        // When: moveWindowToContainer is called (uses activeMonitorState internally)
        // It should fall back to window2 instead of failing
        sut.moveWindowToContainer(direction: .right)

        // Then: No crash, and a retile was scheduled (action was processed)
        #expect(sut.hasPendingRetile, "moveWindowToContainer should schedule a retile if it found a fallback window")
    }
}
