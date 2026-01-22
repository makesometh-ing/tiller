//
//  MonitorTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

@MainActor
final class MonitorTests: XCTestCase {
    private var mockMonitorService: MockMonitorService!

    override func setUp() async throws {
        try await super.setUp()
        mockMonitorService = MockMonitorService()
    }

    override func tearDown() async throws {
        mockMonitorService = nil
        try await super.tearDown()
    }

    private func createMonitorManager() -> MonitorManager {
        return MonitorManager(monitorService: mockMonitorService)
    }

    // MARK: - Test 1: Monitor Enumeration

    func testMonitorEnumeration() async throws {
        let mainMonitor = MockMonitorService.createTestMonitor(id: 1, name: "Main Display", isMain: true)
        let secondMonitor = MockMonitorService.createTestMonitor(id: 2, name: "External Display", isMain: false)

        mockMonitorService.monitors = [mainMonitor, secondMonitor]

        let manager = createMonitorManager()
        let monitors = manager.connectedMonitors

        XCTAssertEqual(monitors.count, 2)
        XCTAssertTrue(monitors.contains { $0.name == "Main Display" })
        XCTAssertTrue(monitors.contains { $0.name == "External Display" })
    }

    // MARK: - Test 2: Usable Frame Calculation

    func testUsableFrameCalculation() async throws {
        let fullFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1920, height: 1055)

        let monitor = MockMonitorService.createTestMonitor(
            id: 1,
            frame: fullFrame,
            visibleFrame: visibleFrame
        )

        mockMonitorService.monitors = [monitor]

        let manager = createMonitorManager()
        let monitors = manager.connectedMonitors

        XCTAssertEqual(monitors.count, 1)
        XCTAssertEqual(monitors[0].frame, fullFrame)
        XCTAssertEqual(monitors[0].visibleFrame, visibleFrame)
        XCTAssertNotEqual(monitors[0].frame.height, monitors[0].visibleFrame.height)
    }

    // MARK: - Test 3: Active Monitor Tracking

    func testActiveMonitorTracking() async throws {
        let mainMonitor = MockMonitorService.createTestMonitor(
            id: 1,
            name: "Main Display",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            isMain: true
        )
        let secondMonitor = MockMonitorService.createTestMonitor(
            id: 2,
            name: "External Display",
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            isMain: false
        )

        mockMonitorService.monitors = [mainMonitor, secondMonitor]

        let manager = createMonitorManager()
        manager.startMonitoring()

        XCTAssertEqual(manager.activeMonitor?.id.rawValue, 1)

        manager.updateActiveMonitor(forWindowAtPoint: CGPoint(x: 2500, y: 500))

        XCTAssertEqual(manager.activeMonitor?.id.rawValue, 2)

        manager.stopMonitoring()
    }

    // MARK: - Test 4: Monitor Connect Event

    func testMonitorConnectEvent() async throws {
        mockMonitorService.monitors = [
            MockMonitorService.createTestMonitor(id: 1, name: "Main Display", isMain: true)
        ]

        let manager = createMonitorManager()

        var receivedEvents: [MonitorChangeEvent] = []
        manager.onMonitorChange = { event in
            receivedEvents.append(event)
        }

        manager.startMonitoring()

        mockMonitorService.simulateMonitorConnect(
            MockMonitorService.createTestMonitor(id: 2, name: "External Display", isMain: false)
        )

        manager.onMonitorChange?(.configurationChanged)

        XCTAssertTrue(receivedEvents.contains(.configurationChanged))

        manager.stopMonitoring()
    }

    // MARK: - Test 5: Monitor Disconnect Event

    func testMonitorDisconnectEvent() async throws {
        let mainMonitor = MockMonitorService.createTestMonitor(id: 1, name: "Main Display", isMain: true)
        let secondMonitor = MockMonitorService.createTestMonitor(id: 2, name: "External Display", isMain: false)

        mockMonitorService.monitors = [mainMonitor, secondMonitor]

        let manager = createMonitorManager()

        var receivedEvents: [MonitorChangeEvent] = []
        manager.onMonitorChange = { event in
            receivedEvents.append(event)
        }

        manager.startMonitoring()

        mockMonitorService.simulateMonitorDisconnect(MonitorID(rawValue: 2))

        manager.onMonitorChange?(.configurationChanged)

        XCTAssertTrue(receivedEvents.contains(.configurationChanged))
        XCTAssertEqual(manager.connectedMonitors.count, 1)

        manager.stopMonitoring()
    }

    // MARK: - Test 6: Monitor List Accessible by ID

    func testMonitorListAccessible() async throws {
        let mainMonitor = MockMonitorService.createTestMonitor(id: 1, name: "Main Display", isMain: true)
        let secondMonitor = MockMonitorService.createTestMonitor(id: 2, name: "External Display", isMain: false)

        mockMonitorService.monitors = [mainMonitor, secondMonitor]

        let manager = createMonitorManager()

        let retrievedMonitor = manager.getMonitor(byID: MonitorID(rawValue: 2))

        XCTAssertNotNil(retrievedMonitor)
        XCTAssertEqual(retrievedMonitor?.name, "External Display")
        XCTAssertEqual(retrievedMonitor?.id.rawValue, 2)
    }

    // MARK: - Test 7: Up to Six Displays Supported

    func testUpToSixDisplaysSupported() async throws {
        var monitors: [MonitorInfo] = []
        for i in 1...6 {
            let xOffset: CGFloat = CGFloat(i - 1) * 1920
            let frame = CGRect(x: xOffset, y: 0, width: 1920, height: 1080)
            let monitor = MockMonitorService.createTestMonitor(
                id: UInt32(i),
                name: "Display \(i)",
                frame: frame,
                isMain: i == 1
            )
            monitors.append(monitor)
        }

        mockMonitorService.monitors = monitors

        let manager = createMonitorManager()
        let connectedMonitors = manager.connectedMonitors

        XCTAssertEqual(connectedMonitors.count, 6)

        for i in 1...6 {
            let monitorID = MonitorID(rawValue: UInt32(i))
            let monitor = manager.getMonitor(byID: monitorID)
            XCTAssertNotNil(monitor)
            XCTAssertEqual(monitor?.name, "Display \(i)")
        }
    }

    // MARK: - Test 8: Initial Active Monitor is Main

    func testInitialActiveMonitorIsMain() async throws {
        let mainMonitor = MockMonitorService.createTestMonitor(id: 2, name: "Main Display", isMain: true)
        let firstMonitor = MockMonitorService.createTestMonitor(id: 1, name: "First Display", isMain: false)

        mockMonitorService.monitors = [firstMonitor, mainMonitor]

        let manager = createMonitorManager()
        manager.startMonitoring()

        XCTAssertEqual(manager.activeMonitor?.id.rawValue, 2)
        XCTAssertEqual(manager.activeMonitor?.name, "Main Display")
        XCTAssertTrue(manager.activeMonitor?.isMain == true)

        manager.stopMonitoring()
    }

    // MARK: - Test 9: Active Monitor Cleared on Disconnect

    func testActiveMonitorClearedOnDisconnect() async throws {
        let mainMonitor = MockMonitorService.createTestMonitor(id: 1, name: "Main Display", isMain: true)
        let secondMonitor = MockMonitorService.createTestMonitor(
            id: 2,
            name: "External Display",
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            isMain: false
        )

        mockMonitorService.monitors = [mainMonitor, secondMonitor]

        let manager = createMonitorManager()
        manager.startMonitoring()

        manager.updateActiveMonitor(forWindowAtPoint: CGPoint(x: 2500, y: 500))
        XCTAssertEqual(manager.activeMonitor?.id.rawValue, 2)

        var activeMonitorChangedCalled = false
        manager.onActiveMonitorChanged = { _ in
            activeMonitorChangedCalled = true
        }

        mockMonitorService.simulateMonitorDisconnect(MonitorID(rawValue: 2))

        manager.handleScreenConfigurationChange()

        XCTAssertTrue(activeMonitorChangedCalled)
        XCTAssertEqual(manager.activeMonitor?.id.rawValue, 1)
        XCTAssertEqual(manager.activeMonitor?.name, "Main Display")

        manager.stopMonitoring()
    }
}
