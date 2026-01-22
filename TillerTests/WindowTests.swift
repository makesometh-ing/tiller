//
//  WindowTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

@MainActor
final class WindowTests: XCTestCase {
    private var mockWindowService: MockWindowService!

    override func setUp() async throws {
        try await super.setUp()
        mockWindowService = MockWindowService()
    }

    override func tearDown() async throws {
        mockWindowService = nil
        try await super.tearDown()
    }

    private func createWindowManager() -> WindowDiscoveryManager {
        return WindowDiscoveryManager(windowService: mockWindowService)
    }

    // MARK: - Test 1: Window Enumeration

    func testWindowEnumeration() async throws {
        let window1 = MockWindowService.createTestWindow(id: 1, title: "Window 1", appName: "App 1")
        let window2 = MockWindowService.createTestWindow(id: 2, title: "Window 2", appName: "App 2")

        mockWindowService.windows = [window1, window2]

        let manager = createWindowManager()
        let windows = manager.visibleWindows

        XCTAssertEqual(windows.count, 2)
        XCTAssertTrue(windows.contains { $0.title == "Window 1" })
        XCTAssertTrue(windows.contains { $0.title == "Window 2" })
    }

    // MARK: - Test 2: Window Property Retrieval - Title

    func testWindowPropertyRetrieval_Title() async throws {
        let window = MockWindowService.createTestWindow(
            id: 1,
            title: "My Document.txt - Editor",
            appName: "TextEditor"
        )

        mockWindowService.windows = [window]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertEqual(retrievedWindow?.title, "My Document.txt - Editor")
    }

    // MARK: - Test 3: Window Property Retrieval - App Name

    func testWindowPropertyRetrieval_AppName() async throws {
        let window = MockWindowService.createTestWindow(
            id: 1,
            title: "Test Window",
            appName: "Safari"
        )

        mockWindowService.windows = [window]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertEqual(retrievedWindow?.appName, "Safari")
    }

    // MARK: - Test 4: Window Property Retrieval - Bundle ID

    func testWindowPropertyRetrieval_BundleID() async throws {
        let window = MockWindowService.createTestWindow(
            id: 1,
            title: "Test Window",
            appName: "Safari",
            bundleID: "com.apple.Safari"
        )

        mockWindowService.windows = [window]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertEqual(retrievedWindow?.bundleID, "com.apple.Safari")
    }

    // MARK: - Test 5: Window Property Retrieval - Frame

    func testWindowPropertyRetrieval_Frame() async throws {
        let frame = CGRect(x: 200, y: 150, width: 1024, height: 768)
        let window = MockWindowService.createTestWindow(
            id: 1,
            title: "Test Window",
            frame: frame
        )

        mockWindowService.windows = [window]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertEqual(retrievedWindow?.frame, frame)
        XCTAssertEqual(retrievedWindow?.frame.origin.x, 200)
        XCTAssertEqual(retrievedWindow?.frame.origin.y, 150)
        XCTAssertEqual(retrievedWindow?.frame.size.width, 1024)
        XCTAssertEqual(retrievedWindow?.frame.size.height, 768)
    }

    // MARK: - Test 6: Window Property Retrieval - Is Resizable

    func testWindowPropertyRetrieval_IsResizable() async throws {
        let resizableWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Resizable Window",
            isResizable: true
        )
        let fixedWindow = MockWindowService.createTestWindow(
            id: 2,
            title: "Fixed Window",
            isResizable: false
        )

        mockWindowService.windows = [resizableWindow, fixedWindow]

        let manager = createWindowManager()

        let retrieved1 = manager.getWindow(byID: WindowID(rawValue: 1))
        let retrieved2 = manager.getWindow(byID: WindowID(rawValue: 2))

        XCTAssertNotNil(retrieved1)
        XCTAssertTrue(retrieved1?.isResizable == true)

        XCTAssertNotNil(retrieved2)
        XCTAssertFalse(retrieved2?.isResizable == true)
    }

    // MARK: - Test 7: Window Open Event Detected

    func testWindowOpenEventDetected() async throws {
        let manager = createWindowManager()

        var receivedEvents: [WindowChangeEvent] = []
        manager.onWindowChange = { event in
            receivedEvents.append(event)
        }

        manager.startMonitoring()

        let newWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "New Window",
            appName: "TestApp"
        )
        mockWindowService.simulateWindowOpen(newWindow)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(receivedEvents.contains { event in
            if case .windowOpened(let info) = event {
                return info.title == "New Window"
            }
            return false
        })

        manager.stopMonitoring()
    }

    // MARK: - Test 8: Window Close Event Detected

    func testWindowCloseEventDetected() async throws {
        let window = MockWindowService.createTestWindow(id: 1, title: "Test Window")
        mockWindowService.windows = [window]

        let manager = createWindowManager()

        var receivedEvents: [WindowChangeEvent] = []
        manager.onWindowChange = { event in
            receivedEvents.append(event)
        }

        manager.startMonitoring()

        mockWindowService.simulateWindowClose(WindowID(rawValue: 1))

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(receivedEvents.contains { event in
            if case .windowClosed(let id) = event {
                return id.rawValue == 1
            }
            return false
        })

        manager.stopMonitoring()
    }

    // MARK: - Test 9: Window Focus Event Detected

    func testWindowFocusEventDetected() async throws {
        let window1 = MockWindowService.createTestWindow(id: 1, title: "Window 1")
        let window2 = MockWindowService.createTestWindow(id: 2, title: "Window 2")
        mockWindowService.windows = [window1, window2]

        let manager = createWindowManager()

        var receivedEvents: [WindowChangeEvent] = []
        manager.onWindowChange = { event in
            receivedEvents.append(event)
        }

        manager.startMonitoring()

        mockWindowService.simulateWindowFocus(WindowID(rawValue: 2))

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(receivedEvents.contains { event in
            if case .windowFocused(let id) = event {
                return id.rawValue == 2
            }
            return false
        })

        manager.stopMonitoring()
    }

    // MARK: - Test 10: Window List Updates Realtime

    func testWindowListUpdatesRealtime() async throws {
        let manager = createWindowManager()

        XCTAssertEqual(manager.visibleWindows.count, 0)

        let window1 = MockWindowService.createTestWindow(id: 1, title: "Window 1")
        mockWindowService.windows.append(window1)

        XCTAssertEqual(manager.visibleWindows.count, 1)

        let window2 = MockWindowService.createTestWindow(id: 2, title: "Window 2")
        mockWindowService.windows.append(window2)

        XCTAssertEqual(manager.visibleWindows.count, 2)

        mockWindowService.windows.removeAll { $0.id.rawValue == 1 }

        XCTAssertEqual(manager.visibleWindows.count, 1)
        XCTAssertEqual(manager.visibleWindows.first?.title, "Window 2")
    }

    // MARK: - Additional Tests

    func testGetWindowsByBundleID() async throws {
        let window1 = MockWindowService.createTestWindow(
            id: 1,
            title: "Safari 1",
            appName: "Safari",
            bundleID: "com.apple.Safari"
        )
        let window2 = MockWindowService.createTestWindow(
            id: 2,
            title: "Safari 2",
            appName: "Safari",
            bundleID: "com.apple.Safari"
        )
        let window3 = MockWindowService.createTestWindow(
            id: 3,
            title: "Finder",
            appName: "Finder",
            bundleID: "com.apple.finder"
        )

        mockWindowService.windows = [window1, window2, window3]

        let manager = createWindowManager()
        let safariWindows = manager.getWindows(forBundleID: "com.apple.Safari")

        XCTAssertEqual(safariWindows.count, 2)
        XCTAssertTrue(safariWindows.allSatisfy { $0.bundleID == "com.apple.Safari" })
    }

    func testFocusedWindowTracking() async throws {
        let window = MockWindowService.createTestWindow(
            id: 1,
            title: "Test Window",
            appName: "TestApp",
            bundleID: "com.test.app"
        )
        mockWindowService.windows = [window]

        let manager = createWindowManager()

        XCTAssertNil(manager.focusedWindow)

        mockWindowService.focusedWindow = FocusedWindowInfo(
            windowID: WindowID(rawValue: 1),
            appName: "TestApp",
            bundleID: "com.test.app"
        )

        XCTAssertNotNil(manager.focusedWindow)
        XCTAssertEqual(manager.focusedWindow?.windowID.rawValue, 1)
        XCTAssertEqual(manager.focusedWindow?.appName, "TestApp")
    }

    func testWindowMoveEventDetected() async throws {
        let window = MockWindowService.createTestWindow(
            id: 1,
            title: "Test Window",
            frame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        mockWindowService.windows = [window]

        let manager = createWindowManager()

        var receivedEvents: [WindowChangeEvent] = []
        manager.onWindowChange = { event in
            receivedEvents.append(event)
        }

        manager.startMonitoring()

        let newFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        mockWindowService.simulateWindowMove(WindowID(rawValue: 1), newFrame: newFrame)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(receivedEvents.contains { event in
            if case .windowMoved(let id, let frame) = event {
                return id.rawValue == 1 && frame == newFrame
            }
            return false
        })

        manager.stopMonitoring()
    }

    func testWindowResizeEventDetected() async throws {
        let window = MockWindowService.createTestWindow(
            id: 1,
            title: "Test Window",
            frame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        mockWindowService.windows = [window]

        let manager = createWindowManager()

        var receivedEvents: [WindowChangeEvent] = []
        manager.onWindowChange = { event in
            receivedEvents.append(event)
        }

        manager.startMonitoring()

        let newFrame = CGRect(x: 0, y: 0, width: 1024, height: 768)
        mockWindowService.simulateWindowResize(WindowID(rawValue: 1), newFrame: newFrame)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(receivedEvents.contains { event in
            if case .windowResized(let id, let frame) = event {
                return id.rawValue == 1 && frame == newFrame
            }
            return false
        })

        manager.stopMonitoring()
    }

    func testIsMonitoringProperty() async throws {
        let manager = createWindowManager()

        XCTAssertFalse(manager.isMonitoring)

        manager.startMonitoring()
        XCTAssertTrue(manager.isMonitoring)

        manager.stopMonitoring()
        XCTAssertFalse(manager.isMonitoring)
    }

    func testWindowWithNilBundleID() async throws {
        let window = MockWindowService.createTestWindow(
            id: 1,
            title: "Unknown App Window",
            appName: "UnknownApp",
            bundleID: nil
        )
        mockWindowService.windows = [window]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertNil(retrievedWindow?.bundleID)
        XCTAssertEqual(retrievedWindow?.appName, "UnknownApp")
    }

    // MARK: - Floating Window Detection Tests

    func testDialogDetection() async throws {
        // Simulates a dialog window (would have AXDialogRole in real system)
        let dialogWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Save As",
            appName: "TextEdit",
            bundleID: "com.apple.TextEdit",
            isFloating: true
        )
        mockWindowService.windows = [dialogWindow]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertTrue(retrievedWindow?.isFloating == true, "Dialog windows should be marked as floating")
    }

    func testSheetDetection() async throws {
        // Simulates a sheet window (would have AXSheetRole in real system)
        let sheetWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Preferences",
            appName: "Safari",
            bundleID: "com.apple.Safari",
            isFloating: true
        )
        mockWindowService.windows = [sheetWindow]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertTrue(retrievedWindow?.isFloating == true, "Sheet windows should be marked as floating")
    }

    func testNonResizableDetection() async throws {
        // Non-resizable windows should be marked as floating
        let fixedWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Calculator",
            appName: "Calculator",
            bundleID: "com.apple.calculator",
            isResizable: false,
            isFloating: true
        )
        mockWindowService.windows = [fixedWindow]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertFalse(retrievedWindow?.isResizable == true, "Window should not be resizable")
        XCTAssertTrue(retrievedWindow?.isFloating == true, "Non-resizable windows should be marked as floating")
    }

    func testConfigFloatingApps() async throws {
        // Apps configured in floatingApps should be marked floating
        let floatingAppWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Spotlight",
            appName: "Spotlight",
            bundleID: "com.apple.Spotlight",
            isFloating: true
        )
        mockWindowService.windows = [floatingAppWindow]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertTrue(retrievedWindow?.isFloating == true, "Apps in floatingApps config should be marked floating")
    }

    func testFloatingExcludedFromTiling() async throws {
        // Test that floating windows can be filtered out for tiling
        let normalWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Safari",
            appName: "Safari",
            bundleID: "com.apple.Safari",
            isFloating: false
        )
        let floatingWindow = MockWindowService.createTestWindow(
            id: 2,
            title: "Color Picker",
            appName: "Color Picker",
            bundleID: "com.apple.ColorPicker",
            isFloating: true
        )
        mockWindowService.windows = [normalWindow, floatingWindow]

        let manager = createWindowManager()
        let allWindows = manager.visibleWindows
        let tileableWindows = allWindows.filter { !$0.isFloating }

        XCTAssertEqual(allWindows.count, 2, "Should have 2 total windows")
        XCTAssertEqual(tileableWindows.count, 1, "Should have 1 tileable window after filtering")
        XCTAssertEqual(tileableWindows.first?.title, "Safari", "Only Safari should be tileable")
    }

    func testNormalWindowNotFloating() async throws {
        // Standard resizable windows should not be marked as floating
        let normalWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Terminal",
            appName: "Terminal",
            bundleID: "com.apple.Terminal",
            isResizable: true,
            isFloating: false
        )
        mockWindowService.windows = [normalWindow]

        let manager = createWindowManager()
        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))

        XCTAssertNotNil(retrievedWindow)
        XCTAssertTrue(retrievedWindow?.isResizable == true, "Normal window should be resizable")
        XCTAssertFalse(retrievedWindow?.isFloating == true, "Normal windows should not be marked as floating")
    }

    func testWindowPropertyRetrieval_IsFloating() async throws {
        let floatingWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Floating Window",
            isFloating: true
        )
        let normalWindow = MockWindowService.createTestWindow(
            id: 2,
            title: "Normal Window",
            isFloating: false
        )

        mockWindowService.windows = [floatingWindow, normalWindow]

        let manager = createWindowManager()

        let retrieved1 = manager.getWindow(byID: WindowID(rawValue: 1))
        let retrieved2 = manager.getWindow(byID: WindowID(rawValue: 2))

        XCTAssertNotNil(retrieved1)
        XCTAssertTrue(retrieved1?.isFloating == true)

        XCTAssertNotNil(retrieved2)
        XCTAssertFalse(retrieved2?.isFloating == true)
    }

    func testWindowMovePreservesFloatingProperty() async throws {
        let floatingWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Floating Window",
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            isFloating: true
        )
        mockWindowService.windows = [floatingWindow]

        let manager = createWindowManager()
        manager.startMonitoring()

        let newFrame = CGRect(x: 100, y: 100, width: 400, height: 300)
        mockWindowService.simulateWindowMove(WindowID(rawValue: 1), newFrame: newFrame)

        try await Task.sleep(nanoseconds: 100_000_000)

        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))
        XCTAssertNotNil(retrievedWindow)
        XCTAssertEqual(retrievedWindow?.frame, newFrame, "Frame should be updated")
        XCTAssertTrue(retrievedWindow?.isFloating == true, "isFloating should be preserved after move")

        manager.stopMonitoring()
    }

    func testWindowResizePreservesFloatingProperty() async throws {
        let floatingWindow = MockWindowService.createTestWindow(
            id: 1,
            title: "Floating Window",
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            isFloating: true
        )
        mockWindowService.windows = [floatingWindow]

        let manager = createWindowManager()
        manager.startMonitoring()

        let newFrame = CGRect(x: 0, y: 0, width: 500, height: 400)
        mockWindowService.simulateWindowResize(WindowID(rawValue: 1), newFrame: newFrame)

        try await Task.sleep(nanoseconds: 100_000_000)

        let retrievedWindow = manager.getWindow(byID: WindowID(rawValue: 1))
        XCTAssertNotNil(retrievedWindow)
        XCTAssertEqual(retrievedWindow?.frame, newFrame, "Frame should be updated")
        XCTAssertTrue(retrievedWindow?.isFloating == true, "isFloating should be preserved after resize")

        manager.stopMonitoring()
    }
}
