//
//  TillerMenuStateTests.swift
//  TillerTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Tiller

struct TillerMenuStateTests {

    private let sut: TillerMenuState
    private let orchestrator: AutoTilingOrchestrator
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

        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        configManager = ConfigManager(
            fileManager: .default,
            basePath: tempDirectory.path,
            notificationService: MockNotificationService()
        )
        configManager.loadConfiguration()

        let testMonitor = MockMonitorService.createTestMonitor(
            id: 1,
            name: "Test Monitor",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055),
            isMain: true
        )
        mockMonitorService.simulateMonitorConnect(testMonitor)

        windowDiscoveryManager.startMonitoring()

        orchestrator = AutoTilingOrchestrator(
            windowDiscoveryManager: windowDiscoveryManager,
            monitorManager: monitorManager,
            configManager: configManager,
            layoutEngine: mockLayoutEngine,
            animationService: mockAnimationService
        )

        sut = TillerMenuState(monitorManager: monitorManager)
    }

    // MARK: - canToggleTiling

    @Test func canToggleTilingFalseBeforeConfigure() {
        #expect(!sut.canToggleTiling)
    }

    @Test func canToggleTilingTrueAfterConfigure() {
        sut.configure(orchestrator: orchestrator)
        #expect(sut.canToggleTiling)
    }

    // MARK: - configure

    @Test func configureInitializesMonitorList() {
        sut.configure(orchestrator: orchestrator)

        #expect(sut.monitors.count == 1)
        #expect(sut.monitors.first?.name == "Test Monitor")
    }

    @Test func configureInitializesActiveMonitor() {
        monitorManager.startMonitoring()
        sut.configure(orchestrator: orchestrator)

        #expect(sut.activeMonitorID == MonitorID(rawValue: 1))
    }

    @Test func configureSetsTilingEnabledFromOrchestrator() {
        sut.configure(orchestrator: orchestrator)
        #expect(!sut.isTilingEnabled)
    }

    // MARK: - toggleTiling

    @Test func toggleTilingStartsOrchestrator() async {
        sut.configure(orchestrator: orchestrator)
        #expect(!sut.isTilingEnabled)

        sut.toggleTiling()

        // Wait for the async start() to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(sut.isTilingEnabled)
        #expect(orchestrator.isCurrentlyRunning)
    }

    @Test func toggleTilingStopsOrchestrator() async {
        sut.configure(orchestrator: orchestrator)

        // Start first
        await orchestrator.start()
        sut.isTilingEnabled = true

        sut.toggleTiling()

        #expect(!sut.isTilingEnabled)
        #expect(!orchestrator.isCurrentlyRunning)
    }

    @Test func toggleTilingDoesNothingWithoutConfigure() {
        sut.toggleTiling()
        #expect(!sut.isTilingEnabled)
    }

    // MARK: - Monitor updates

    // MARK: - Layout State

    @Test func configureInitializesLayoutState() {
        sut.configure(orchestrator: orchestrator)

        // Default layout is monocle for the connected monitor
        #expect(sut.activeLayoutPerMonitor[MonitorID(rawValue: 1)] == .monocle)
    }

    @Test func switchLayoutUpdatesState() async {
        // Need windows for the orchestrator to create monitor state
        let window = MockWindowService.createTestWindow(id: 1, title: "W1", frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        mockWindowService.windows = [window]
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window.id, pid: window.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        sut.configure(orchestrator: orchestrator)
        await orchestrator.start()

        // Now switch layout
        sut.switchLayout(to: .splitHalves, on: MonitorID(rawValue: 1))

        #expect(sut.activeLayoutPerMonitor[MonitorID(rawValue: 1)] == .splitHalves)
    }

    @Test func layoutChangeCallbackUpdatesState() async {
        let window = MockWindowService.createTestWindow(id: 1, title: "W1", frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        mockWindowService.windows = [window]
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window.id, pid: window.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        sut.configure(orchestrator: orchestrator)
        await orchestrator.start()

        // Simulate layout change via orchestrator (as if triggered by keyboard)
        orchestrator.switchLayout(to: .splitHalves, on: MonitorID(rawValue: 1))

        #expect(sut.activeLayoutPerMonitor[MonitorID(rawValue: 1)] == .splitHalves)
    }

    @Test func switchLayoutDoesNothingWithoutConfigure() {
        // Should not crash
        sut.switchLayout(to: .splitHalves, on: MonitorID(rawValue: 1))
        #expect(sut.activeLayoutPerMonitor.isEmpty)
    }

    // MARK: - Status Text

    @Test func statusTextDefaultsToMonitor1Idle() {
        #expect(sut.statusText == "1 | 1 | -")
    }

    @Test func statusTextReflectsLeaderActive() {
        sut.leaderState = .leaderActive
        #expect(sut.statusText == "1 | 1 | *")
    }

    @Test func statusTextCombinesMonitorAndLeader() {
        let secondMonitor = MockMonitorService.createTestMonitor(
            id: 2,
            name: "External Monitor",
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            isMain: false
        )
        mockMonitorService.simulateMonitorConnect(secondMonitor)
        sut.configure(orchestrator: orchestrator)
        monitorManager.startMonitoring()

        sut.activeMonitorID = MonitorID(rawValue: 2)
        sut.leaderState = .leaderActive

        #expect(sut.statusText == "2 | 1 | *")
    }

    @Test func statusTextDefaultsToMonitor1WhenNoActiveMonitor() {
        sut.activeMonitorID = nil
        sut.leaderState = .leaderActive
        #expect(sut.statusText == "1 | 1 | *")
    }

    @Test func statusTextShowsSubLayerKey() {
        sut.configure(orchestrator: orchestrator)
        sut.leaderState = .subLayerActive(key: "m")
        #expect(sut.statusText == "1 | 1 | m")
    }

    @Test func statusTextShowsLayoutNumber() async {
        let window = MockWindowService.createTestWindow(id: 1, title: "W1", frame: CGRect(x: 100, y: 100, width: 800, height: 600))
        mockWindowService.windows = [window]
        mockLayoutEngine.resultToReturn = LayoutResult(placements: [
            WindowPlacement(windowID: window.id, pid: window.ownerPID, targetFrame: CGRect(x: 8, y: 33, width: 1904, height: 1039))
        ])

        sut.configure(orchestrator: orchestrator)
        sut.activeMonitorID = MonitorID(rawValue: 1)
        await orchestrator.start()

        sut.switchLayout(to: .splitHalves, on: MonitorID(rawValue: 1))

        #expect(sut.statusText == "1 | 2 | -")
    }

    // MARK: - Config Error Indicator

    @Test func statusTextAppendsErrorSuffix() {
        sut.hasConfigError = true
        #expect(sut.statusText == "1 | 1 | - !")
    }

    @Test func statusTextNormalWhenNoError() {
        sut.hasConfigError = false
        #expect(sut.statusText == "1 | 1 | -")
    }

    @Test func statusTextErrorWithLeaderActive() {
        sut.hasConfigError = true
        sut.leaderState = .leaderActive
        #expect(sut.statusText == "1 | 1 | * !")
    }

    @Test func configErrorTooltipWhenError() {
        sut.hasConfigError = true
        sut.configErrorMessage = "Margin value 999 is out of range (0-20)"
        #expect(sut.configErrorTooltip == "Margin value 999 is out of range (0-20)")
    }

    @Test func configErrorTooltipNilWhenNoError() {
        sut.hasConfigError = false
        sut.configErrorMessage = nil
        #expect(sut.configErrorTooltip == nil)
    }

    @Test func configureConfigSyncsErrorState() {
        let errorManager = ConfigManager(
            fileManager: .default,
            basePath: tempDirectory.path,
            notificationService: MockNotificationService()
        )
        let configDir = (tempDirectory.path as NSString).appendingPathComponent(".config/tiller")
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        let invalidJSON = """
        { "margin": 999, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        try? Data(invalidJSON.utf8).write(to: URL(fileURLWithPath: (configDir as NSString).appendingPathComponent("config.json")))
        errorManager.loadConfiguration()

        sut.configureConfig(manager: errorManager)

        #expect(sut.hasConfigError)
        #expect(sut.configErrorMessage != nil)
    }

    // MARK: - Monitor Updates

    @Test func monitorListUpdatesOnChange() {
        sut.configure(orchestrator: orchestrator)
        #expect(sut.monitors.count == 1)

        let secondMonitor = MockMonitorService.createTestMonitor(
            id: 2,
            name: "External Monitor",
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            isMain: false
        )
        mockMonitorService.simulateMonitorConnect(secondMonitor)

        // Trigger the monitor change callback
        monitorManager.handleScreenConfigurationChange()

        #expect(sut.monitors.count == 2)
        #expect(sut.monitors.last?.name == "External Monitor")
    }
}
