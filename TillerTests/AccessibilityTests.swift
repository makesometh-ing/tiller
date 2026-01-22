//
//  AccessibilityTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

@MainActor
final class AccessibilityTests: XCTestCase {
    private var mockAccessibilityService: MockAccessibilityService!
    private var mockNotificationService: MockNotificationService!

    override func setUp() async throws {
        try await super.setUp()
        mockAccessibilityService = MockAccessibilityService()
        mockNotificationService = MockNotificationService()
    }

    override func tearDown() async throws {
        mockAccessibilityService = nil
        mockNotificationService = nil
        try await super.tearDown()
    }

    private func createAccessibilityManager(pollingInterval: TimeInterval = 2.0) -> AccessibilityManager {
        return AccessibilityManager(
            accessibilityService: mockAccessibilityService,
            notificationService: mockNotificationService,
            pollingInterval: pollingInterval
        )
    }

    // MARK: - Test 1: Permission Status Check

    func testPermissionStatusCheck() async throws {
        let manager = createAccessibilityManager()

        mockAccessibilityService.isGranted = false
        XCTAssertEqual(manager.checkPermissionStatus(), .denied)

        mockAccessibilityService.isGranted = true
        XCTAssertEqual(manager.checkPermissionStatus(), .granted)
    }

    // MARK: - Test 2: Permission Granted

    func testPermissionGranted() async throws {
        mockAccessibilityService.isGranted = true
        let manager = createAccessibilityManager()

        let result = manager.requestPermissionsOnLaunch()

        XCTAssertEqual(result, .permissionGranted)
        XCTAssertEqual(manager.currentStatus, .granted)
        XCTAssertEqual(mockNotificationService.accessibilityDeniedCount, 0)
    }

    // MARK: - Test 3: Permission Denied

    func testPermissionDenied() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager()

        let result = manager.requestPermissionsOnLaunch()

        XCTAssertTrue(result == .promptShown || result == .permissionDenied)
        XCTAssertEqual(manager.currentStatus, .denied)
        XCTAssertEqual(mockNotificationService.accessibilityDeniedCount, 1)
    }

    // MARK: - Test 4: Permission Check Available to Modules

    func testPermissionCheckAvailableToModules() async throws {
        mockAccessibilityService.isGranted = true
        let manager = createAccessibilityManager()

        _ = manager.requestPermissionsOnLaunch()

        let status = manager.currentStatus
        XCTAssertEqual(status, .granted)

        let checkResult = manager.checkPermissionStatus()
        XCTAssertEqual(checkResult, .granted)
    }

    // MARK: - Test 5: Status Change Callback

    func testStatusChangeCallback() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager()

        var callbackStatuses: [AccessibilityPermissionStatus] = []
        manager.onPermissionStatusChanged = { status in
            callbackStatuses.append(status)
        }

        _ = manager.requestPermissionsOnLaunch()

        XCTAssertTrue(callbackStatuses.contains(.denied))

        mockAccessibilityService.isGranted = true

        let expectation = XCTestExpectation(description: "Permission granted callback")
        manager.onPermissionStatusChanged = { status in
            if status == .granted {
                expectation.fulfill()
            }
        }

        manager.startPolling()

        await fulfillment(of: [expectation], timeout: 5.0)

        manager.stopPolling()

        XCTAssertEqual(manager.currentStatus, .granted)
        XCTAssertEqual(mockNotificationService.accessibilityGrantedCount, 1)
    }

    // MARK: - Test 6: Request Accessibility Called with Prompt

    func testRequestAccessibilityCalledWithPrompt() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager()

        _ = manager.requestPermissionsOnLaunch()

        XCTAssertEqual(mockAccessibilityService.requestCallCount, 1)
        XCTAssertEqual(mockAccessibilityService.lastShowPromptValue, true)
    }

    // MARK: - Test 7: Polling Stops After Grant

    func testPollingStopsAfterGrant() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager(pollingInterval: 0.1)

        _ = manager.requestPermissionsOnLaunch()

        mockAccessibilityService.isGranted = true

        let expectation = XCTestExpectation(description: "Permission granted")
        manager.onPermissionStatusChanged = { status in
            if status == .granted {
                expectation.fulfill()
            }
        }

        manager.startPolling()

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(manager.currentStatus, .granted)
    }

    // MARK: - Test 8: Initial Status is Not Determined

    func testInitialStatusIsNotDetermined() async throws {
        let manager = createAccessibilityManager()

        XCTAssertEqual(manager.currentStatus, .notDetermined)
    }

    // MARK: - Test 9: Already Granted Returns Immediately

    func testAlreadyGrantedReturnsImmediately() async throws {
        mockAccessibilityService.isGranted = true
        let manager = createAccessibilityManager()

        let result = manager.requestPermissionsOnLaunch()

        XCTAssertEqual(result, .permissionGranted)
        XCTAssertEqual(mockAccessibilityService.requestCallCount, 0)
    }

    // MARK: - Test 10: Notification Service Shows Denied Message

    func testNotificationServiceShowsDeniedMessage() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager()

        _ = manager.requestPermissionsOnLaunch()

        XCTAssertEqual(mockNotificationService.accessibilityDeniedCount, 1)
        XCTAssertEqual(mockNotificationService.accessibilityGrantedCount, 0)
    }
}
