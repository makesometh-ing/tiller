//
//  MonitorEvents.swift
//  Tiller
//

import Foundation

nonisolated enum MonitorChangeEvent: Equatable, Sendable {
    case monitorConnected(MonitorInfo)
    case monitorDisconnected(MonitorID)
    case configurationChanged
}
