import Foundation
import Testing
@testable import TillerCore

@Test func eventIsOneJSONLineWithTheRequiredFields() throws {
    let ts = Date(timeIntervalSince1970: 1_795_000_000.4125)
    let event = LogEvent(ts: ts, name: .actionDone, session: "S1",
                         fields: ["action": "focus-next-window", "moved": 4, "totalMs": .ms(31.23456), "ok": true,
                                  "setFramesMs": [["app": "com.tiller.TestWindows", "windows": 4, "ms": .ms(12.5)]]])
    let line = event.jsonLine()
    #expect(!line.contains("\n"))
    let object = try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
    #expect(Set(object.keys) == ["ts", "level", "cat", "event", "session", "fields"])
    #expect(object["ts"] as? String == "2026-11-18T11:06:40.412Z")
    #expect(object["level"] as? String == "info")
    #expect(object["cat"] as? String == "action")
    #expect(object["event"] as? String == "action.done")
    #expect(object["session"] as? String == "S1")
    let fields = try #require(object["fields"] as? [String: Any])
    #expect(fields["totalMs"] as? Double == 31.23)
    #expect(fields["moved"] as? Int == 4)
    #expect((fields["setFramesMs"] as? [[String: Any]])?.first?["app"] as? String == "com.tiller.TestWindows")
}

@Test func errorEventsHaveTheErrorLevel() {
    for name in [LogEventName.actionSlow, .windowFrameMismatch, .axError, .tapDisabled] {
        #expect(LogEvent(name: name, session: "S", fields: [:]).level == .error)
    }
    #expect(LogEvent(name: .axCall, session: "S", fields: [:]).level == .debug)
    #expect(LogEvent(name: .actionDone, level: .error, session: "S", fields: [:]).level == .error)
}

@Test func eachEventHasACategoryPrefix() {
    // The event name starts with a word of its category, or with `app`, `tap` or `leader`.
    for name in LogEventName.allCases {
        let prefix = String(name.rawValue.split(separator: ".")[0])
        let expected: [String: LogCategory] = ["app": .lifecycle, "tap": .lifecycle, "leader": .keys, "diagnostics": .settings]
        #expect(name.category == expected[prefix] ?? LogCategory(rawValue: prefix), "\(name.rawValue)")
    }
}

@Test func logFileRotatesAtTheSizeLimitAndKeepsThreeFiles() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: "tiller-log-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = LogFile(directory: dir, name: "tiller", maxBytes: 100, keep: 3)
    let line = String(repeating: "a", count: 39)  // 40 bytes with the line break.
    for i in 0..<10 { file.append(line.replacingCharacters(in: line.startIndex...line.startIndex, with: "\(i)")) }
    file.flush()
    #expect(file.urls.map(\.lastPathComponent) == ["tiller.jsonl", "tiller.1.jsonl", "tiller.2.jsonl"])
    let contents = try file.urls.map { try String(contentsOf: $0, encoding: .utf8) }
    // 2 lines fit in 100 bytes. The 10 lines are in 5 files. The 2 oldest files were removed.
    #expect(contents.map { $0.split(separator: "\n").map { String($0.prefix(1)) } } == [["8", "9"], ["6", "7"], ["4", "5"]])
    for url in file.urls { #expect((try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0) <= 100) }
}

@Test func logFileAppendsToAnExistingFile() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: "tiller-log-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    LogFile(directory: dir, name: "tiller").append("first")
    let file = LogFile(directory: dir, name: "tiller")
    file.append("second")
    file.flush()
    #expect(try String(contentsOf: file.urls[0], encoding: .utf8) == "first\nsecond\n")
}

@Test func aLogCallTakesLessThanFiftyMicrosecondsOnTheCallingQueue() {
    let dir = FileManager.default.temporaryDirectory.appending(path: "tiller-log-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let log = EventLog(file: LogFile(directory: dir, name: "tiller"), subsystem: "com.tiller.Tiller.tests")
    let n = 2000
    let start = DispatchTime.now().uptimeNanoseconds
    for i in 0..<n {
        log.log(.actionDone, ["action": "focus-next-window", "screen": "37D8832A-2D66-02CA-B9F7-8F30A301B230", "layout": "fullScreen",
                              "moved": .int(i), "windowListMs": .ms(12.3), "focusReadMs": .ms(0.4), "focusMs": .ms(5.1), "totalMs": .ms(30.2),
                              "setFramesMs": [["app": "com.tiller.TestWindows", "windows": 4, "ms": .ms(10.2)]]])
    }
    let perCallMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 / Double(n)
    log.flush()
    print("EventLog.log on the calling queue: \(String(format: "%.4f", perCallMs)) ms for each call")
    #expect(perCallMs < 0.05)
    #expect(log.fileURLs.count == 1)
}

@Test func debugEventsArentWrittenToTheFile() {
    let dir = FileManager.default.temporaryDirectory.appending(path: "tiller-log-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let log = EventLog(file: LogFile(directory: dir, name: "tiller"), subsystem: "com.tiller.Tiller.tests")
    log.log(.axCall, ["function": "setFrame", "ms": .ms(1)])
    log.log(.actionDone, ["action": "rearrange", "moved": 0, "totalMs": .ms(1)])
    log.flush()
    let text = (try? String(contentsOf: log.fileURLs[0], encoding: .utf8)) ?? ""
    #expect(text.split(separator: "\n").count == 1)
    #expect(text.contains("action.done"))
}
