//
//  MonitorEvents.swift
//  Tiller
//

import Foundation

enum MonitorChangeEvent: Equatable, Sendable {
    case monitorConnected(MonitorInfo)
    case monitorDisconnected(MonitorID)
    case configurationChanged
}
