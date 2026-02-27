//
//  MonitorInfo.swift
//  Tiller
//

import Foundation

nonisolated struct MonitorID: Hashable, Equatable, Sendable {
    let rawValue: UInt32
}

nonisolated struct MonitorInfo: Equatable, Identifiable, Sendable {
    let id: MonitorID
    let name: String
    let frame: CGRect
    let visibleFrame: CGRect
    let isMain: Bool
    let scaleFactor: CGFloat
}
