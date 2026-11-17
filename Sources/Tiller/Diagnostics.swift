import AppKit
import ApplicationServices
import TillerCore

/// Writes the diagnostics zip.
enum Diagnostics {
    /// Tiller version and build, macOS version, Mac model, the Accessibility permission and the screens. `screens` is read on the main thread.
    static func systemFields(screens: [ScreenInfo]) -> [String: LogValue] {
        let info = Bundle.main.infoDictionary ?? [:]
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return [
            "version": .string(info["CFBundleShortVersionString"] as? String ?? ""),
            "build": .string(info["CFBundleVersion"] as? String ?? ""),
            "macOS": .string(ProcessInfo.processInfo.operatingSystemVersionString),
            "model": .string(String(cString: model)),
            "accessibility": .bool(AXIsProcessTrusted()),
            "screens": .array(screens.map { ["uuid": .string($0.uuid), "frame": .frame($0.frame), "desktop": .frame($0.desktop), "scale": .double($0.scale)] }),
        ]
    }

    /// Writes `Tiller-Diagnostics-<date>.zip` to `directory` and returns its URL. Call on a background queue.
    /// `titles` adds the window titles to `windows.json`.
    static func export(to directory: URL, system: [String: LogValue], settings: [String: LogValue], titles: Bool, controller: Controller) -> URL? {
        let start = DispatchTime.now()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let name = "Tiller-Diagnostics-\(formatter.string(from: Date()))"
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: name)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        guard (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else { return nil }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        func write(_ value: LogValue, _ file: String) { try? encoder.encode(value).write(to: folder.appending(path: file)) }
        write(.object(system.merging(["session": .string(Log.shared.session),
                                      "exportedAt": .string(Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(Date()))]) { $1 }),
              "state.json")
        write(.object(settings), "settings.json")
        write(controller.workspaceState(), "workspaces.json")
        WindowDump.write(to: folder.appending(path: "windows.json").path, titles: titles)
        Log.shared.flush()
        for url in Log.shared.fileURLs { try? FileManager.default.copyItem(at: url, to: folder.appending(path: url.lastPathComponent)) }
        run("/usr/bin/log", ["show", "--last", "2h", "--info", "--debug", "--predicate", "subsystem == \"\(EventLog.subsystem)\" AND process == \"Tiller\""],
            output: folder.appending(path: "unified-log.txt"))

        let zip = directory.appending(path: "\(name).zip")
        guard run("/usr/bin/ditto", ["-c", "-k", "--norsrc", "--noextattr", "--keepParent", folder.path, zip.path]) == 0 else { return nil }
        Log.event(.diagnosticsExported, ["path": .string(zip.path), "ms": Log.ms(since: start)])
        return zip
    }

    @discardableResult
    private static func run(_ path: String, _ arguments: [String], output: URL? = nil) -> Int32 {
        let p = Process()
        p.executableURL = URL(filePath: path)
        p.arguments = arguments
        if let output {
            FileManager.default.createFile(atPath: output.path, contents: nil)
            p.standardOutput = try? FileHandle(forWritingTo: output)
        }
        guard (try? p.run()) != nil else { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
