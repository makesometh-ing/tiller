//
//  MonitorTests.swift
//  TillerTests
//

import CoreGraphics
import Testing
@testable import Tiller

struct MonitorTests {
    let mockMonitorService: MockMonitorService

    init() {
        mockMonitorService = MockMonitorService()
    }

    private func createMonitorManager() -> MonitorManager {
        return MonitorManager(monitorService: mockMonitorService)
    }

    // MARK: - Test 1: Monitor Enumeration

    @Test func monitorEnumeration() async throws {
        let mainMonitor = MockMonitorService.createTestMonitor(id: 1, name: "Main Display", isMain: true)
        let secondMonitor = MockMonitorService.createTestMonitor(id: 2, name: "External Display", isMain: false)

        mockMonitorService.monitors = [mainMonitor, secondMonitor]

        let manager = createMonitorManager()
        let monitors = manager.connectedMonitors

        #expect(monitors.count == 2)
        #expect(monitors.contains { $0.name == "Main Display" })
        #expect(monitors.contains { $0.name == "External Display" })
    }

    // MARK: - Test 2: Usable Frame Calculation

    @Test func usableFrameCalculation() async throws {
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

        #expect(monitors.count == 1)
        #expect(monitors[0].frame == fullFrame)
        #expect(monitors[0].visibleFrame == visibleFrame)
        #expect(monitors[0].frame.height != monitors[0].visibleFrame.height)
    }

    // MARK: - Test 3: Active Monitor Tracking

    @Test func activeMonitorTracking() async throws {
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

        #expect(manager.activeMonitor?.id.rawValue == 1)

        manager.updateActiveMonitor(forWindowAtPoint: CGPoint(x: 2500, y: 500))

        #expect(manager.activeMonitor?.id.rawValue == 2)

        manager.stopMonitoring()
    }

    // MARK: - Test 4: Monitor Connect Event

    @Test func monitorConnectEvent() async throws {
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

        #expect(receivedEvents.contains(.configurationChanged))

        manager.stopMonitoring()
    }

    // MARK: - Test 5: Monitor Disconnect Event

    @Test func monitorDisconnectEvent() async throws {
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

        #expect(receivedEvents.contains(.configurationChanged))
        #expect(manager.connectedMonitors.count == 1)

        manager.stopMonitoring()
    }

    // MARK: - Test 6: Monitor List Accessible by ID

    @Test func monitorListAccessible() async throws {
        let mainMonitor = MockMonitorService.createTestMonitor(id: 1, name: "Main Display", isMain: true)
        let secondMonitor = MockMonitorService.createTestMonitor(id: 2, name: "External Display", isMain: false)

        mockMonitorService.monitors = [mainMonitor, secondMonitor]

        let manager = createMonitorManager()

        let retrievedMonitor = manager.getMonitor(byID: MonitorID(rawValue: 2))

        #expect(retrievedMonitor != nil)
        #expect(retrievedMonitor?.name == "External Display")
        #expect(retrievedMonitor?.id.rawValue == 2)
    }

    // MARK: - Test 7: Up to Six Displays Supported

    @Test func upToSixDisplaysSupported() async throws {
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

        #expect(connectedMonitors.count == 6)

        for i in 1...6 {
            let monitorID = MonitorID(rawValue: UInt32(i))
            let monitor = manager.getMonitor(byID: monitorID)
            #expect(monitor != nil)
            #expect(monitor?.name == "Display \(i)")
        }
    }

    // MARK: - Test 8: Initial Active Monitor is Main

    @Test func initialActiveMonitorIsMain() async throws {
        let mainMonitor = MockMonitorService.createTestMonitor(id: 2, name: "Main Display", isMain: true)
        let firstMonitor = MockMonitorService.createTestMonitor(id: 1, name: "First Display", isMain: false)

        mockMonitorService.monitors = [firstMonitor, mainMonitor]

        let manager = createMonitorManager()
        manager.startMonitoring()

        #expect(manager.activeMonitor?.id.rawValue == 2)
        #expect(manager.activeMonitor?.name == "Main Display")
        #expect(manager.activeMonitor?.isMain == true)

        manager.stopMonitoring()
    }

    // MARK: - Test 9: Active Monitor Cleared on Disconnect

    @Test func activeMonitorClearedOnDisconnect() async throws {
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
        #expect(manager.activeMonitor?.id.rawValue == 2)

        var activeMonitorChangedCalled = false
        manager.onActiveMonitorChanged = { _ in
            activeMonitorChangedCalled = true
        }

        mockMonitorService.simulateMonitorDisconnect(MonitorID(rawValue: 2))

        manager.handleScreenConfigurationChange()

        #expect(activeMonitorChangedCalled)
        #expect(manager.activeMonitor?.id.rawValue == 1)
        #expect(manager.activeMonitor?.name == "Main Display")

        manager.stopMonitoring()
    }
}
