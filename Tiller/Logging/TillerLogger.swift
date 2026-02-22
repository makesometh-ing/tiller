//
//  TillerLogger.swift
//  Tiller
//

import os

/// Structured logging categories for Tiller.
///
/// Usage: `TillerLogger.orchestration.info("message")`
///
/// Query logs:
///   log stream --predicate 'subsystem == "ing.makesometh.Tiller"' --level debug
///   log show --predicate 'subsystem == "ing.makesometh.Tiller"' --last 1h > tiller-logs.txt
enum TillerLogger {
    private static let subsystem = "ing.makesometh.Tiller"

    static let orchestration = Logger(subsystem: subsystem, category: "orchestration")
    static let windowDiscovery = Logger(subsystem: subsystem, category: "window-discovery")
    static let layout = Logger(subsystem: subsystem, category: "layout")
    static let animation = Logger(subsystem: subsystem, category: "animation")
    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    static let config = Logger(subsystem: subsystem, category: "config")
}
