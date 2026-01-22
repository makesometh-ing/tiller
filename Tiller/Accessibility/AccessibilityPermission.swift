//
//  AccessibilityPermission.swift
//  Tiller
//

import Foundation

enum AccessibilityPermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

enum AccessibilityCheckResult: Equatable, Sendable {
    case permissionGranted
    case permissionDenied
    case promptShown
}
