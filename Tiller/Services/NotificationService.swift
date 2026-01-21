//
//  NotificationService.swift
//  Tiller
//

import Foundation

protocol NotificationServiceProtocol {
    func showConfigValidationError(_ error: ConfigValidationError)
    func showConfigParseError(_ error: Error)
}

final class SystemNotificationService: NotificationServiceProtocol {
    func showConfigValidationError(_ error: ConfigValidationError) {
        print("[Tiller Config] Validation error: \(error.description)")
    }

    func showConfigParseError(_ error: Error) {
        print("[Tiller Config] Parse error: \(error.localizedDescription)")
    }
}

final class MockNotificationService: NotificationServiceProtocol {
    private(set) var validationErrors: [ConfigValidationError] = []
    private(set) var parseErrors: [Error] = []

    func showConfigValidationError(_ error: ConfigValidationError) {
        validationErrors.append(error)
    }

    func showConfigParseError(_ error: Error) {
        parseErrors.append(error)
    }

    func reset() {
        validationErrors = []
        parseErrors = []
    }
}
