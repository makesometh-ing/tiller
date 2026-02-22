//
//  TillerLogger.swift
//  Tiller
//

import os

/// Structured logging categories for Tiller.
///
/// For OSLog (production errors):
///   `TillerLogger.orchestration.error("critical failure")`
///
/// For file-based debug logging (agent-queryable):
///   `TillerLogger.debug("window-discovery", "AXResizable = true for window 1234")`
///
/// Debug logs are written to `.logs/tiller-debug.log` in the project root.
/// Agents can read this file after a test run to diagnose issues.
enum TillerLogger {
    private static let subsystem = "ing.makesometh.Tiller"

    // MARK: - OSLog loggers (for .error level — persisted by unified logging)

    static let orchestration = Logger(subsystem: subsystem, category: "orchestration")
    static let windowDiscovery = Logger(subsystem: subsystem, category: "window-discovery")
    static let layout = Logger(subsystem: subsystem, category: "layout")
    static let animation = Logger(subsystem: subsystem, category: "animation")
    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    static let config = Logger(subsystem: subsystem, category: "config")

    // MARK: - File-based debug logging (always persisted, agent-readable)

    /// Write a debug message to `.logs/tiller-debug.log`.
    /// Use this for all diagnostic output that agents need to read.
    static func debug(_ category: String, _ message: String) {
        TillerFileLogger.shared.log(category, message)
    }
}
