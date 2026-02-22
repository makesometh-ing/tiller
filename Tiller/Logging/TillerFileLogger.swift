//
//  TillerFileLogger.swift
//  Tiller
//
//  File-based debug logger that writes to ~/.tiller/logs/tiller-debug.log (default).
//  The log path can be overridden via `logLocation` in ~/.config/tiller/config.json.
//  Designed for agent-queryable diagnostics — agents can Read this file after a test run.
//

import Foundation

/// File-based debug logger that writes timestamped entries to disk.
///
/// Default path: `~/.tiller/logs/tiller-debug.log`
/// Override via config: set `logLocation` in `~/.config/tiller/config.json`
///
/// The log file is replaced on each app launch (current session only).
///
/// Usage:
///   `TillerFileLogger.shared.log("window-discovery", "AXResizable failed for window \(id)")`
///
/// Or via the convenience on TillerLogger:
///   `TillerLogger.debug("window-discovery", "AXResizable failed for window \(id)")`
final class TillerFileLogger: @unchecked Sendable {
    static let shared = TillerFileLogger()

    private let fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "ing.makesometh.Tiller.file-logger")
    private let dateFormatter: DateFormatter
    let logFileURL: URL

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        // Resolve log path: check config for override, otherwise use default
        let resolvedPath = Self.resolveLogPath()
        logFileURL = URL(fileURLWithPath: resolvedPath)

        let logDir = logFileURL.deletingLastPathComponent()

        // Create log directory if needed
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        // Replace on launch — fresh log each session
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)

        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()

        // Write session header
        let header = "=== Tiller debug log started at \(ISO8601DateFormatter().string(from: Date())) ===\n"
        header.data(using: .utf8).map { fileHandle?.write($0) }

        let pathLine = "=== Log path: \(logFileURL.path) ===\n"
        pathLine.data(using: .utf8).map { fileHandle?.write($0) }
    }

    deinit {
        fileHandle?.closeFile()
    }

    /// Log a debug message to the file.
    /// - Parameters:
    ///   - category: Log category (e.g. "window-discovery", "orchestration")
    ///   - message: The log message
    func log(_ category: String, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(category)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        queue.async { [weak self] in
            self?.fileHandle?.write(data)
        }
    }

    /// Resolve the log file path by checking config, falling back to default.
    private static func resolveLogPath() -> String {
        let configPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".config/tiller/config.json")

        if let data = FileManager.default.contents(atPath: configPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let customPath = json["logLocation"] as? String,
           !customPath.isEmpty {
            // Expand ~ in paths
            return (customPath as NSString).expandingTildeInPath
        }

        return TillerConfig.defaultLogPath
    }
}
