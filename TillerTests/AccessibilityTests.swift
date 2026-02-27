//
//  AccessibilityTests.swift
//  TillerTests
//

import Foundation
import Testing
@testable import Tiller

struct AccessibilityTests {
    let mockAccessibilityService: MockAccessibilityService
    let mockNotificationService: MockNotificationService

    init() {
        mockAccessibilityService = MockAccessibilityService()
        mockNotificationService = MockNotificationService()
    }

    private func createAccessibilityManager(pollingInterval: TimeInterval = 2.0) -> AccessibilityManager {
        return AccessibilityManager(
            accessibilityService: mockAccessibilityService,
            notificationService: mockNotificationService,
            pollingInterval: pollingInterval
        )
    }

    // MARK: - Test 1: Permission Status Check

    @Test func permissionStatusCheck() async throws {
        let manager = createAccessibilityManager()

        mockAccessibilityService.isGranted = false
        #expect(manager.checkPermissionStatus() == .denied)

        mockAccessibilityService.isGranted = true
        #expect(manager.checkPermissionStatus() == .granted)
    }

    // MARK: - Test 2: Permission Granted

    @Test func permissionGranted() async throws {
        mockAccessibilityService.isGranted = true
        let manager = createAccessibilityManager()

        let result = manager.requestPermissionsOnLaunch()

        #expect(result == .permissionGranted)
        #expect(manager.currentStatus == .granted)
        #expect(mockNotificationService.accessibilityDeniedCount == 0)
    }

    // MARK: - Test 3: Permission Denied

    @Test func permissionDenied() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager()

        let result = manager.requestPermissionsOnLaunch()

        #expect(result == .promptShown || result == .permissionDenied)
        #expect(manager.currentStatus == .denied)
        #expect(mockNotificationService.accessibilityDeniedCount == 1)
    }

    // MARK: - Test 4: Permission Check Available to Modules

    @Test func permissionCheckAvailableToModules() async throws {
        mockAccessibilityService.isGranted = true
        let manager = createAccessibilityManager()

        _ = manager.requestPermissionsOnLaunch()

        let status = manager.currentStatus
        #expect(status == .granted)

        let checkResult = manager.checkPermissionStatus()
        #expect(checkResult == .granted)
    }

    // MARK: - Test 5: Status Change Callback

    @Test(.timeLimit(.minutes(1))) func statusChangeCallback() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager(pollingInterval: 0.1)

        var callbackStatuses: [AccessibilityPermissionStatus] = []
        manager.onPermissionStatusChanged = { status in
            callbackStatuses.append(status)
        }

        _ = manager.requestPermissionsOnLaunch()

        #expect(callbackStatuses.contains(.denied))

        mockAccessibilityService.isGranted = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            manager.onPermissionStatusChanged = { status in
                if status == .granted {
                    continuation.resume()
                }
            }
            manager.startPolling()
        }

        manager.stopPolling()

        #expect(manager.currentStatus == .granted)
        #expect(mockNotificationService.accessibilityGrantedCount == 1)
    }

    // MARK: - Test 6: Request Accessibility Called with Prompt

    @Test func requestAccessibilityCalledWithPrompt() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager()

        _ = manager.requestPermissionsOnLaunch()

        #expect(mockAccessibilityService.requestCallCount == 1)
        #expect(mockAccessibilityService.lastShowPromptValue == true)
    }

    // MARK: - Test 7: Polling Stops After Grant

    @Test(.timeLimit(.minutes(1))) func pollingStopsAfterGrant() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager(pollingInterval: 0.1)

        _ = manager.requestPermissionsOnLaunch()

        mockAccessibilityService.isGranted = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            manager.onPermissionStatusChanged = { status in
                if status == .granted {
                    continuation.resume()
                }
            }
            manager.startPolling()
        }

        #expect(manager.currentStatus == .granted)
    }

    // MARK: - Test 8: Initial Status is Not Determined

    @Test func initialStatusIsNotDetermined() async throws {
        let manager = createAccessibilityManager()

        #expect(manager.currentStatus == .notDetermined)
    }

    // MARK: - Test 9: Already Granted Returns Immediately

    @Test func alreadyGrantedReturnsImmediately() async throws {
        mockAccessibilityService.isGranted = true
        let manager = createAccessibilityManager()

        let result = manager.requestPermissionsOnLaunch()

        #expect(result == .permissionGranted)
        #expect(mockAccessibilityService.requestCallCount == 0)
    }

    // MARK: - Test 10: Notification Service Shows Denied Message

    @Test func notificationServiceShowsDeniedMessage() async throws {
        mockAccessibilityService.isGranted = false
        let manager = createAccessibilityManager()

        _ = manager.requestPermissionsOnLaunch()

        #expect(mockNotificationService.accessibilityDeniedCount == 1)
        #expect(mockNotificationService.accessibilityGrantedCount == 0)
    }
}
