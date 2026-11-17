import CoreGraphics
import Foundation
import os

public enum LogLevel: String, Codable, Sendable {
    case error, info, debug
}

public enum LogCategory: String, Codable, CaseIterable, Sendable {
    case lifecycle, keys, action, window, ax, overlay, settings, display
}

/// The events of the Tiller log. Each event has one category and a default level.
public enum LogEventName: String, CaseIterable, Sendable {
    case appLaunch = "app.launch"
    case appEnabled = "app.enabled"
    case appDisabled = "app.disabled"
    case appTerminate = "app.terminate"
    case tapStarted = "tap.started"
    case tapDisabled = "tap.disabled"
    case leaderStart = "leader.start"
    case leaderEnd = "leader.end"
    case leaderKey = "leader.key"
    case globalKey = "global.key"
    case actionDone = "action.done"
    case actionSlow = "action.slow"
    case actionFocus = "action.focus"
    case windowClassified = "window.classified"
    case windowFrameMismatch = "window.frameMismatch"
    case windowClosed = "window.closed"
    case axError = "ax.error"
    case axCall = "ax.call"
    case overlayShown = "overlay.shown"
    case overlayHidden = "overlay.hidden"
    case settingsChanged = "settings.changed"
    case diagnosticsExported = "diagnostics.exported"
    case displayChanged = "display.changed"

    public var category: LogCategory {
        switch self {
        case .appLaunch, .appEnabled, .appDisabled, .appTerminate, .tapStarted, .tapDisabled: .lifecycle
        case .leaderStart, .leaderEnd, .leaderKey, .globalKey: .keys
        case .actionDone, .actionSlow, .actionFocus: .action
        case .windowClassified, .windowFrameMismatch, .windowClosed: .window
        case .axError, .axCall: .ax
        case .overlayShown, .overlayHidden: .overlay
        case .settingsChanged, .diagnosticsExported: .settings
        case .displayChanged: .display
        }
    }

    public var level: LogLevel {
        switch self {
        case .tapDisabled, .actionSlow, .windowFrameMismatch, .axError: .error
        case .axCall: .debug
        default: .info
        }
    }
}

/// A typed value of a log field.
public enum LogValue: Encodable, Equatable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([LogValue])
    case object([String: LogValue])
    case null

    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(arrayLiteral elements: LogValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, LogValue)...) { self = .object(Dictionary(elements, uniquingKeysWith: { $1 })) }

    /// A time in milliseconds, rounded to 0.01 ms.
    public static func ms(_ value: Double) -> LogValue { .double((value * 100).rounded() / 100) }

    /// A frame as `[x, y, width, height]`.
    public static func frame(_ r: CGRect) -> LogValue { .array([r.minX, r.minY, r.width, r.height].map { .double(Double($0)) }) }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    /// The value without the `title` and `titles` keys, at each depth.
    public var withoutTitles: LogValue {
        switch self {
        case .object(let o): .object(o.filter { $0.key != "title" && $0.key != "titles" }.mapValues(\.withoutTitles))
        case .array(let a): .array(a.map(\.withoutTitles))
        default: self
        }
    }
}

/// "Debug logging" turns off 24 hours after it is turned on, so that it doesn't stay on by mistake.
public enum DebugLogging {
    public static let duration: TimeInterval = 24 * 60 * 60

    /// The hours until debug logging turns off, rounded up. nil when it is off.
    public static func hoursLeft(until: Date?, now: Date) -> Int? {
        guard let until, until > now else { return nil }
        return Int((until.timeIntervalSince(now) / 3600).rounded(.up))
    }
}

/// One line of the JSON Lines log.
public struct LogEvent: Encodable, Sendable {
    public var ts: Date
    public var level: LogLevel
    public var cat: LogCategory
    public var event: String
    public var session: String
    public var fields: [String: LogValue]

    public init(ts: Date = Date(), name: LogEventName, level: LogLevel? = nil, session: String, fields: [String: LogValue]) {
        self.ts = ts
        self.level = level ?? name.level
        self.cat = name.category
        self.event = name.rawValue
        self.session = session
        self.fields = fields
    }

    enum CodingKeys: String, CodingKey { case ts, level, cat, event, session, fields }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // UTC with milliseconds, for example 2026-11-16T17:29:03.412Z.
        try c.encode(Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(ts), forKey: .ts)
        try c.encode(level, forKey: .level)
        try c.encode(cat, forKey: .cat)
        try c.encode(event, forKey: .event)
        try c.encode(session, forKey: .session)
        try c.encode(fields, forKey: .fields)
    }

    /// The JSON text of the event, without a line break.
    public func jsonLine() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
}

/// Appends lines to `<name>.jsonl` in `directory`. Before a line makes the file bigger than `maxBytes`, the files are rotated:
/// `<name>.1.jsonl` becomes `<name>.2.jsonl`, and `<name>.jsonl` becomes `<name>.1.jsonl`. `keep` files are kept.
/// It isn't thread-safe. `EventLog` calls it on one queue.
public final class LogFile: @unchecked Sendable {
    public let directory: URL
    public let name: String
    public let maxBytes: Int
    public let keep: Int
    private var handle: FileHandle?
    private var size = 0

    public init(directory: URL, name: String, maxBytes: Int = 5 * 1024 * 1024, keep: Int = 3) {
        self.directory = directory
        self.name = name
        self.maxBytes = maxBytes
        self.keep = keep
    }

    /// The log files, newest first. Only files that exist are listed.
    public var urls: [URL] {
        (0..<keep).map(url).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func url(_ index: Int) -> URL {
        directory.appending(path: index == 0 ? "\(name).jsonl" : "\(name).\(index).jsonl")
    }

    public func append(_ line: String) {
        let data = Data((line + "\n").utf8)
        if handle == nil { open() }
        if size > 0 && size + data.count > maxBytes { rotate() }
        handle?.write(data)
        size += data.count
    }

    private func open() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let current = url(0)
        if !FileManager.default.fileExists(atPath: current.path) { FileManager.default.createFile(atPath: current.path, contents: nil) }
        handle = try? FileHandle(forWritingTo: current)
        size = Int((try? handle?.seekToEnd()) ?? 0)
    }

    private func rotate() {
        try? handle?.close()
        handle = nil
        let fm = FileManager.default
        try? fm.removeItem(at: url(keep - 1))
        for i in stride(from: keep - 2, through: 0, by: -1) { try? fm.moveItem(at: url(i), to: url(i + 1)) }
        open()
    }

    /// Writes the buffered data to disk.
    public func flush() { try? handle?.synchronize() }
}

/// Writes each event to the Apple unified log, subsystem `com.tiller.Tiller`, and to a JSON Lines file.
/// The calling queue only creates the event. Encoding and writes run on one background queue.
public final class EventLog: @unchecked Sendable {
    public static let subsystem = "com.tiller.Tiller"
    /// A random id for each launch. It separates the events of two launches in one file.
    public let session = UUID().uuidString
    private let file: LogFile
    private let queue = DispatchQueue(label: "tiller.log", qos: .utility)
    private let loggers: [LogCategory: Logger]
    /// Read and written on `queue`.
    private var debugToFile = false
    private var titles = false

    /// The unit tests use another `subsystem`, so that their events aren't in the diagnostics zip.
    public init(file: LogFile, subsystem: String = EventLog.subsystem) {
        self.file = file
        loggers = Dictionary(uniqueKeysWithValues: LogCategory.allCases.map { ($0, Logger(subsystem: subsystem, category: $0.rawValue)) })
    }

    public var fileURLs: [URL] { queue.sync { file.urls } }

    /// `debugToFile` writes `debug` events to the file too. Without `titles`, the `title` and `titles` fields are removed from each event.
    /// The settings apply to the events logged after this call.
    public func set(debugToFile: Bool, titles: Bool) {
        queue.async { self.debugToFile = debugToFile; self.titles = titles }
    }

    public func log(_ name: LogEventName, level: LogLevel? = nil, _ fields: [String: LogValue] = [:]) {
        let event = LogEvent(name: name, level: level, session: session, fields: fields)
        queue.async { [self] in
            var event = event
            if !titles, case .object(let fields) = LogValue.object(event.fields).withoutTitles { event.fields = fields }
            let line = event.jsonLine()
            let logger = loggers[event.cat]!
            switch event.level {
            case .error: logger.error("\(line, privacy: .public)")
            case .info: logger.info("\(line, privacy: .public)")
            case .debug: logger.debug("\(line, privacy: .public)")
            }
            if event.level != .debug || debugToFile { file.append(line) }
        }
    }

    /// Waits for the queued events and writes them to disk. Call before the app quits.
    public func flush() { queue.sync { file.flush() } }
}
