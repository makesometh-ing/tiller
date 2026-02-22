//
//  AutoTilingOrchestratorTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

@MainActor
final class AutoTilingOrchestratorTests: XCTestCase {

    private var sut: AutoTilingOrchestrator!
    private var mockWindowService: MockWindowService!
    private var mockMonitorService: MockMonitorService!
    private var mockLayoutEngine: MockLayoutEngine!
    private var mockAnimationService: MockWindowAnimationService!
    private var windowDiscoveryManager: WindowDiscoveryManager!
    private var monitorManager: MonitorManager!
    private var configManager: ConfigManager!
    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

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
            config: OrchestratorConfig(debounceDelay: 0.01, animationDuration: 0.1, animateOnInitialTile: false)
        )
    }

    override func tearDown() async throws {
        sut?.stop()
        sut = nil
        mockWindowService = nil
        mockMonitorService = nil
        mockLayoutEngine = nil
        mockAnimationService = nil
        windowDiscoveryManager = nil
        monitorManager = nil
        configManager = nil

        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil

        try await super.tearDown()
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

    // MARK: - Initial Tiling Tests

    func testInitialTiling() async {
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
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 1)
        XCTAssertEqual(mockAnimationService.batchAnimationCalls.count, 1)
        XCTAssertEqual(mockAnimationService.batchAnimationCalls.first?.animations.count, 3)

        // Verify initial tile doesn't animate (duration should be 0)
        XCTAssertEqual(mockAnimationService.batchAnimationCalls.first?.duration, 0)
    }

    func testInitialTilingWithAnimation() async {
        // Given: Config with animateOnInitialTile = true
        sut.stop()
        sut = AutoTilingOrchestrator(
            windowDiscoveryManager: windowDiscoveryManager,
            monitorManager: monitorManager,
            configManager: configManager,
            layoutEngine: mockLayoutEngine,
            animationService: mockAnimationService,
            config: OrchestratorConfig(debounceDelay: 0.01, animationDuration: 0.25, animateOnInitialTile: true)
        )

        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]

        let targetFrame = CGRect(x: 8, y: 33, width: 1904, height: 1039)
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window1.id, pid: window1.ownerPID, targetFrame: targetFrame)
        ])

        // When: Orchestrator starts
        await sut.start()

        // Then: Animation should use configured duration
        XCTAssertEqual(mockAnimationService.batchAnimationCalls.first?.duration, 0.25)
    }

    // MARK: - New Window Tests

    func testNewWindowAdded() async {
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
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then: Retile was triggered
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 1)
        XCTAssertGreaterThanOrEqual(mockAnimationService.batchAnimationCalls.count, 1)
    }

    // MARK: - Window Closed Tests

    func testWindowClosed() async {
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
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then: Retile was triggered
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 1)
    }

    // MARK: - Floating Window Tests

    func testFloatingWindowExcluded() async {
        // Given: One normal and one floating window
        let normalWindow = makeWindow(id: 1, isFloating: false)
        let floatingWindow = makeWindow(id: 2, isFloating: true)
        mockWindowService.windows = [normalWindow, floatingWindow]

        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: normalWindow.id, pid: normalWindow.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        // When: Orchestrator starts
        await sut.start()

        // Then: Floating windows are excluded at orchestrator level — only non-floating windows reach the engine
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 1)
        XCTAssertEqual(mockLayoutEngine.lastInput?.windows.count, 1)

        let inputWindows = mockLayoutEngine.lastInput?.windows ?? []
        XCTAssertTrue(inputWindows.contains(where: { $0.id == normalWindow.id }))
        XCTAssertFalse(inputWindows.contains(where: { $0.id == floatingWindow.id }))
    }

    // MARK: - Multi-Monitor Tests

    func testMultipleMonitorTiling() async {
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
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 2)

        // Verify separate layouts per monitor
        let inputs = mockLayoutEngine.allInputs
        XCTAssertEqual(inputs.count, 2)

        // Check that each input has the correct container frame for its monitor
        let containerFrame1 = inputs.first(where: { $0.windows.contains(where: { $0.id == window1.id }) })?.containerFrame
        let containerFrame2 = inputs.first(where: { $0.windows.contains(where: { $0.id == window2.id }) })?.containerFrame

        XCTAssertNotNil(containerFrame1)
        XCTAssertNotNil(containerFrame2)
        XCTAssertNotEqual(containerFrame1, containerFrame2)
    }

    // MARK: - Debouncing Tests

    func testRapidEventsDebounced() async {
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
        XCTAssertLessThan(mockLayoutEngine.calculateCallCount, 5)
    }

    // MARK: - Focus Change Tests

    func testWindowFocusChangeUpdatesAccordion() async {
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
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 1)
        XCTAssertEqual(mockLayoutEngine.lastInput?.focusedWindowID, window2.id)
    }

    // MARK: - Start/Stop Tests

    func testStartSetsRunningState() async {
        XCTAssertFalse(sut.isCurrentlyRunning)

        await sut.start()

        XCTAssertTrue(sut.isCurrentlyRunning)
    }

    func testStopClearsRunningState() async {
        await sut.start()
        XCTAssertTrue(sut.isCurrentlyRunning)

        sut.stop()

        XCTAssertFalse(sut.isCurrentlyRunning)
    }

    func testStopCancelsPendingRetile() async {
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
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 0)
    }

    // MARK: - Edge Cases

    func testNoWindowsReturnsNoWindowsToTile() async {
        mockWindowService.windows = []

        await sut.start()

        XCTAssertEqual(sut.lastResult, .noWindowsToTile)
    }

    func testNoMonitorsReturnsFailed() async {
        mockMonitorService.monitors = []
        let window1 = makeWindow(id: 1)
        mockWindowService.windows = [window1]

        await sut.start()

        if case .failed(let reason) = sut.lastResult {
            XCTAssertTrue(reason.contains("No monitors"))
        } else {
            XCTFail("Expected failed result with no monitors")
        }
    }

    func testWindowsNotOnAnyMonitorFallbackToMain() async {
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
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 1)
        XCTAssertEqual(mockLayoutEngine.lastInput?.windows.count, 1)
    }

    func testIgnoresMoveEvents() async {
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
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 0)
    }

    func testIgnoresResizeEvents() async {
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
        XCTAssertEqual(mockLayoutEngine.calculateCallCount, 0)
    }

    func testAlwaysPositionsAllWindows() async {
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
        XCTAssertEqual(mockAnimationService.batchAnimationCalls.count, 1)
        XCTAssertEqual(sut.lastResult, .success(tiledCount: 1))
    }

    // MARK: - Stable Window Order Tests

    func testWindowOrderRemainsStableAcrossFocusChanges() async {
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
        XCTAssertEqual(initialInputOrder, newInputOrder, "Window order should remain stable across focus changes")
    }

    func testNewWindowsAppendedToStableOrder() async {
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
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then: New window should be appended (window1 stays first)
        let inputOrder = mockLayoutEngine.lastInput?.windows.map { $0.id } ?? []
        XCTAssertEqual(inputOrder.first, window1.id, "Original window should remain first in order")
        XCTAssertEqual(inputOrder.last, window2.id, "New window should be appended to order")
    }

    func testClosedWindowsRemovedFromStableOrder() async {
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
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then: Only window2 remains
        let inputOrder = mockLayoutEngine.lastInput?.windows.map { $0.id } ?? []
        XCTAssertEqual(inputOrder.count, 1)
        XCTAssertEqual(inputOrder.first, window2.id)
    }

    // MARK: - Non-Resizable Window Ring Buffer Tests

    func testNonResizableWindowInRingButNotAccordionZOrder() async {
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
        XCTAssertEqual(mockLayoutEngine.lastInput?.windows.count, 3)

        // And: Accordion z-order only raises tileable windows (non-resizable not in accordion z-order)
        let raisedWindowIDs = Set(mockAnimationService.raiseOrderCalls.flatMap { $0.map { $0.windowID } })
        XCTAssertFalse(raisedWindowIDs.contains(nonResizableWindow.id),
            "Non-resizable window should not be in accordion z-order raises")
    }

    func testNonResizableFocusedRaisesToTop() async {
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
        XCTAssertEqual(mockAnimationService.raiseOrderCalls.count, 1)
        let raisedWindows = mockAnimationService.raiseOrderCalls[0]
        XCTAssertEqual(raisedWindows.count, 1)
        XCTAssertEqual(raisedWindows[0].windowID, nonResizableWindow.id)
    }

    func testNonResizableFocusedFreezesAccordion() async {
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
        XCTAssertEqual(mockLayoutEngine.lastInput?.focusedWindowID, tileableWindow2.id)

        // Wait for z-order suppression (200ms) to expire
        try? await Task.sleep(nanoseconds: 250_000_000)
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

        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Accordion freezes — layout engine receives tileableWindow2 (last tileable focus),
        // NOT the non-resizable window's ID
        XCTAssertEqual(mockLayoutEngine.lastInput?.focusedWindowID, tileableWindow2.id,
            "Accordion should freeze at last tileable window when non-resizable is focused")
    }

    // MARK: - Focus Event Suppression Tests

    func testDuplicateFocusEventsIgnored() async {
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
        XCTAssertLessThanOrEqual(mockLayoutEngine.calculateCallCount, 1,
            "Duplicate focus events for same window should be ignored")
    }
}
