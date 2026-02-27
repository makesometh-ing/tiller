//
//  AccessibilityPermission.swift
//  Tiller
//

import Foundation

nonisolated enum AccessibilityPermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

nonisolated enum AccessibilityCheckResult: Equatable, Sendable {
    case permissionGranted
    case permissionDenied
    case promptShown
}
