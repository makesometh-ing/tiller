//
//  AccessibilityManager.swift
//  Tiller
//

import ApplicationServices
import Foundation

protocol AccessibilityServiceProtocol {
    func isAccessibilityGranted() -> Bool
    func requestAccessibility(showPrompt: Bool) -> Bool
}

final class SystemAccessibilityService: AccessibilityServiceProtocol {
    func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibility(showPrompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: showPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

final class MockAccessibilityService: AccessibilityServiceProtocol {
    var isGranted: Bool = false
    var requestCallCount: Int = 0
    var lastShowPromptValue: Bool?

    func isAccessibilityGranted() -> Bool {
        return isGranted
    }

    func requestAccessibility(showPrompt: Bool) -> Bool {
        requestCallCount += 1
        lastShowPromptValue = showPrompt
        return isGranted
    }
}

@MainActor
final class AccessibilityManager {
    static let shared = AccessibilityManager()

    private let accessibilityService: AccessibilityServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval

    private var _currentStatus: AccessibilityPermissionStatus = .notDetermined

    var onPermissionStatusChanged: ((AccessibilityPermissionStatus) -> Void)?

    private init() {
        self.accessibilityService = SystemAccessibilityService()
        self.notificationService = SystemNotificationService()
        self.pollingInterval = 2.0
    }

    init(
        accessibilityService: AccessibilityServiceProtocol,
        notificationService: NotificationServiceProtocol,
        pollingInterval: TimeInterval = 2.0
    ) {
        self.accessibilityService = accessibilityService
        self.notificationService = notificationService
        self.pollingInterval = pollingInterval
    }

    var currentStatus: AccessibilityPermissionStatus {
        return _currentStatus
    }

    func checkPermissionStatus() -> AccessibilityPermissionStatus {
        if accessibilityService.isAccessibilityGranted() {
            return .granted
        }
        return .denied
    }

    @discardableResult
    func requestPermissionsOnLaunch() -> AccessibilityCheckResult {
        if accessibilityService.isAccessibilityGranted() {
            updateStatus(.granted)
            return .permissionGranted
        }

        let wasPromptShown = accessibilityService.requestAccessibility(showPrompt: true)

        if accessibilityService.isAccessibilityGranted() {
            updateStatus(.granted)
            return .permissionGranted
        }

        updateStatus(.denied)
        notificationService.showAccessibilityPermissionDenied()

        if wasPromptShown {
            startPolling()
            return .promptShown
        }

        return .permissionDenied
    }

    func startPolling() {
        stopPolling()

        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForPermissionChange()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkForPermissionChange() {
        let newStatus = checkPermissionStatus()

        if newStatus != _currentStatus {
            updateStatus(newStatus)

            if newStatus == .granted {
                notificationService.showAccessibilityPermissionGranted()
                stopPolling()
            }
        }
    }

    private func updateStatus(_ newStatus: AccessibilityPermissionStatus) {
        let previousStatus = _currentStatus
        _currentStatus = newStatus

        if previousStatus != newStatus {
            onPermissionStatusChanged?(newStatus)
        }
    }

    deinit {
        pollingTimer?.invalidate()
    }
}
