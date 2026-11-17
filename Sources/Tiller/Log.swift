import Foundation
import TillerCore

/// The Tiller log: the unified log, subsystem `com.tiller.Tiller`, and `~/Library/Logs/Tiller/tiller.jsonl`.
enum Log {
    static let directory = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Tiller")
    static let shared = EventLog(file: LogFile(directory: directory, name: "tiller"))

    static func event(_ name: LogEventName, level: LogLevel? = nil, _ fields: [String: LogValue] = [:]) {
        shared.log(name, level: level, fields)
    }

    static func ms(since start: DispatchTime) -> LogValue {
        .ms(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6)
    }
}
