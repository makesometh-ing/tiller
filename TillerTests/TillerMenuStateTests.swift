//
//  TillerMenuStateTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

@MainActor
final class TillerMenuStateTests: XCTestCase {

    private var sut: TillerMenuState!
    private var orchestrator: AutoTilingOrchestrator!
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

    override func tearDown() async throws {
        sut = nil
        orchestrator = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - canToggleTiling

    func testCanToggleTilingFalseBeforeConfigure() {
        XCTAssertFalse(sut.canToggleTiling)
    }

    func testCanToggleTilingTrueAfterConfigure() {
        sut.configure(orchestrator: orchestrator)
        XCTAssertTrue(sut.canToggleTiling)
    }

    // MARK: - configure

    func testConfigureInitializesMonitorList() {
        sut.configure(orchestrator: orchestrator)

        XCTAssertEqual(sut.monitors.count, 1)
        XCTAssertEqual(sut.monitors.first?.name, "Test Monitor")
    }

    func testConfigureInitializesActiveMonitor() {
        monitorManager.startMonitoring()
        sut.configure(orchestrator: orchestrator)

        XCTAssertEqual(sut.activeMonitorID, MonitorID(rawValue: 1))
    }

    func testConfigureSetsTilingEnabledFromOrchestrator() {
        sut.configure(orchestrator: orchestrator)
        XCTAssertFalse(sut.isTilingEnabled)
    }

    // MARK: - toggleTiling

    func testToggleTilingStartsOrchestrator() async {
        sut.configure(orchestrator: orchestrator)
        XCTAssertFalse(sut.isTilingEnabled)

        sut.toggleTiling()

        // Wait for the async start() to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(sut.isTilingEnabled)
        XCTAssertTrue(orchestrator.isCurrentlyRunning)
    }

    func testToggleTilingStopsOrchestrator() async {
        sut.configure(orchestrator: orchestrator)

        // Start first
        await orchestrator.start()
        sut.isTilingEnabled = true

        sut.toggleTiling()

        XCTAssertFalse(sut.isTilingEnabled)
        XCTAssertFalse(orchestrator.isCurrentlyRunning)
    }

    func testToggleTilingDoesNothingWithoutConfigure() {
        sut.toggleTiling()
        XCTAssertFalse(sut.isTilingEnabled)
    }

    // MARK: - Monitor updates

    func testMonitorListUpdatesOnChange() {
        sut.configure(orchestrator: orchestrator)
        XCTAssertEqual(sut.monitors.count, 1)

        let secondMonitor = MockMonitorService.createTestMonitor(
            id: 2,
            name: "External Monitor",
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            isMain: false
        )
        mockMonitorService.simulateMonitorConnect(secondMonitor)

        // Trigger the monitor change callback
        monitorManager.handleScreenConfigurationChange()

        XCTAssertEqual(sut.monitors.count, 2)
        XCTAssertEqual(sut.monitors.last?.name, "External Monitor")
    }
}
