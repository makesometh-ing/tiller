//
//  NotificationService.swift
//  Tiller
//

import Foundation

protocol NotificationServiceProtocol {
    func showConfigValidationError(_ error: ConfigValidationError)
    func showConfigParseError(_ error: Error)
    func showAccessibilityPermissionDenied()
    func showAccessibilityPermissionGranted()
}

final class SystemNotificationService: NotificationServiceProtocol {
    func showConfigValidationError(_ error: ConfigValidationError) {
        print("[Tiller Config] Validation error: \(error.description)")
    }

    func showConfigParseError(_ error: Error) {
        print("[Tiller Config] Parse error: \(error.localizedDescription)")
    }

    func showAccessibilityPermissionDenied() {
        print("[Tiller] Accessibility permission denied. Please grant access in System Preferences > Privacy & Security > Accessibility.")
    }

    func showAccessibilityPermissionGranted() {
        print("[Tiller] Accessibility permission granted.")
    }
}

final class MockNotificationService: NotificationServiceProtocol {
    private(set) var validationErrors: [ConfigValidationError] = []
    private(set) var parseErrors: [Error] = []
    private(set) var accessibilityDeniedCount: Int = 0
    private(set) var accessibilityGrantedCount: Int = 0

    func showConfigValidationError(_ error: ConfigValidationError) {
        validationErrors.append(error)
    }

    func showConfigParseError(_ error: Error) {
        parseErrors.append(error)
    }

    func showAccessibilityPermissionDenied() {
        accessibilityDeniedCount += 1
    }

    func showAccessibilityPermissionGranted() {
        accessibilityGrantedCount += 1
    }

    func reset() {
        validationErrors = []
        parseErrors = []
        accessibilityDeniedCount = 0
        accessibilityGrantedCount = 0
    }
}
