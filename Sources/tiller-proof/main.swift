import AppKit
import TillerCore

/// Runs the slice 1 end-to-end test and writes a proof bundle.
/// Usage: tiller-proof --out <dir> [--build <dir>] [--windows <n>] [--apps <bundle id,...>]
let args = CommandLine.arguments
func option(_ name: String) -> String? {
    args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
}
let out = URL(filePath: option("--out") ?? "Tests/Proof/slice-1")
let build = URL(filePath: option("--build") ?? "build")
let windowCount = Int(option("--windows") ?? "") ?? 5
let extraApps = option("--apps").map { $0.split(separator: ",").map(String.init) } ?? []
let testBundleID = "com.tiller.TestWindows"
// `leader` presses only the leader key, so that the screenshot shows the leader key overlay. The `esc` after it ends the layer.
// `v` switches the focused container to a vertical carousel. `f` and `r` test floating windows.
let defaultSteps = ["1", "l", "l", "h", "2", "k", "l", "j", "v", "leader", "esc", "3", "4", "l", "esc", "1", "f", "2", "f", "f", "r", "leader", "hover", "?", "esc"]
/// `--steps a,b,c` runs other steps.
let steps = option("--steps").map { $0.split(separator: ",").map(String.init) } ?? defaultSteps
/// `--appearance light|dark` sets the system appearance for the run. The original appearance is restored at the end.
let appearance = option("--appearance")
let keyLog = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Tiller/testwindows-keys.log")

@discardableResult
func run(_ path: String, _ arguments: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(filePath: path)
    p.arguments = arguments
    try! p.run()
    p.waitUntilExit()
    return p.terminationStatus
}

func wait(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

let center = DistributedNotificationCenter.default()
var ready = false
var lastResult: ActionReport?
center.addObserver(forName: .init("com.tiller.proof.ready"), object: nil, queue: .main) { _ in ready = true }
center.addObserver(forName: .init("com.tiller.proof.result"), object: nil, queue: .main) { note in
    guard let json = note.userInfo?["json"] as? String else { return }
    lastResult = try? JSONDecoder().decode(ActionReport.self, from: Data(json.utf8))
}

func fail(_ message: String) -> Never {
    print("FAIL: \(message)")
    if appearance != nil { setDarkMode(originalDark) }
    try? "# Proof run\n\nFAIL: \(message)\n".write(to: out.appending(path: "summary.md"), atomically: true, encoding: .utf8)
    run("/usr/bin/pkill", ["-x", "Tiller"])
    run("/usr/bin/pkill", ["-x", "TillerTestWindows"])
    exit(1)
}

func setDarkMode(_ dark: Bool) {
    run("/usr/bin/osascript", ["-e", "tell application \"System Events\" to tell appearance preferences to set dark mode to \(dark)"])
}
func isDarkMode() -> Bool {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(filePath: "/usr/bin/osascript")
    p.arguments = ["-e", "tell application \"System Events\" to tell appearance preferences to get dark mode"]
    p.standardOutput = pipe
    try! p.run()
    p.waitUntilExit()
    return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).contains("true")
}
let originalDark = isDarkMode()
if let appearance { setDarkMode(appearance == "dark") }

try? FileManager.default.removeItem(at: out)
try! FileManager.default.createDirectory(at: out.appending(path: "screenshots"), withIntermediateDirectories: true)

run("/usr/bin/pkill", ["-x", "Tiller"])
run("/usr/bin/pkill", ["-x", "TillerTestWindows"])
wait(0.5)
run("/usr/bin/open", ["-n", build.appending(path: "TillerTestWindows.app").path, "--args", "\(windowCount)"])
wait(1.5)
let managed = ([testBundleID] + extraApps).joined(separator: ",")
var tillerArgs = ["--proof", "--only-bundle-ids", managed]
/// `--leader <spec>` and `--keys <action id>=<spec>,...` set the shortcuts of Tiller for the run.
if let leader = option("--leader") { tillerArgs += ["--leader", leader] }
if let keys = option("--keys") { tillerArgs += ["--keys", keys] }
/// `--global <action id>=<spec>,...` sets global shortcuts for the run.
if let global = option("--global") { tillerArgs += ["--global", global] }
run("/usr/bin/open", [build.appending(path: "Tiller.app").path, "--args"] + tillerArgs)
let deadline = Date().addingTimeInterval(15)
while !ready && Date() < deadline { wait(0.1) }
if !ready { fail("Tiller didn't start its event tap in 15 seconds. Grant Accessibility permission to \(build.appending(path: "Tiller.app").path).") }

run("/usr/bin/open", ["-b", testBundleID])
wait(1)
let video = Process()
video.executableURL = URL(filePath: "/usr/sbin/screencapture")
// screencapture discards the video when it is interrupted, so the duration is fixed and the run waits for the end.
// Each step takes about 1.5 seconds. A window step and an app step take about 2.5 seconds.
let windowSteps = steps.filter { $0.hasPrefix("window:") || $0.hasPrefix("app:") }.count
video.arguments = ["-v", "-x", "-V", "\(steps.count * 2 + windowSteps + 4)", out.appending(path: "run.mov").path]
try! video.run()
wait(1.5)

func screenshot(_ name: String) {
    run("/usr/sbin/screencapture", ["-x", "-m", out.appending(path: "screenshots/\(name).png").path])
}
screenshot("00-start")

struct StepResult: Codable {
    var step: Int
    var key: String
    var passed: Bool
    var problems: [String]
    var report: ActionReport
}
var results: [StepResult] = []
/// Key log lines that a `pass:` step after a `click:` step must write: the title of the clicked window and the chord.
var clickedKeyLines: [String] = []
var floatingFrames: [WindowID: Rect] = [:]
/// The container and the ring index of each tiled window of a report.
func ring(_ r: ActionReport) -> [WindowID: [Int]] {
    var next: [Int: Int] = [:]
    var result: [WindowID: [Int]] = [:]
    for w in r.windows {
        result[w.id] = [w.container, next[w.container, default: 0]]
        next[w.container, default: 0] += 1
    }
    return result
}
/// The ring position before a `window:minimize:<title>` step, with the title as the key.
var savedRings: [String: [WindowID: [Int]]] = [:]
/// The report before an `app:hide:<bundle id>` step, with the bundle id as the key.
var reportsBeforeHide: [String: ActionReport] = [:]
/// The system focused window, the focused window of each container and the window server order after each close and minimize step.
var zOrderLines: [String] = []
/// On-screen window ids at window layer 0, front to back.
func frontToBack() -> [WindowID] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.compactMap { $0[kCGWindowLayer as String] as? Int == 0 ? $0[kCGWindowNumber as String] as? WindowID : nil }
}
/// The focused window of the workspace after the last step that reported a tiled focused window.
var tiledFocus: WindowID?
/// For each window, the window that was the focused window of the workspace just before it, when that window was still in a carousel.
var focusedBefore: [WindowID: WindowID] = [:]
for (index, key) in steps.enumerated() {
    lastResult = nil
    center.postNotificationName(.init("com.tiller.proof.press"), object: nil, userInfo: ["key": key], deliverImmediately: true)
    // The diagnostics export reads the unified log, which takes some seconds.
    let stepDeadline = Date().addingTimeInterval(key.hasPrefix("export-diagnostics") || key.hasPrefix("press:") ? 60 : 5)
    while lastResult == nil && Date() < stepDeadline { wait(0.02) }
    guard let report = lastResult else { fail("Tiller didn't send a result for key \(key) in 5 seconds.") }

    var problems: [String] = []
    for w in report.windows {
        guard let actual = w.actual else { problems.append("\(w.title): frame can't be read"); continue }
        if !actual.matches(w.expected) { problems.append("\(w.title): expected \(w.expected), actual \(actual)") }
    }
    if report.expectedFocused != report.actualFocused {
        problems.append("focused window: expected \(report.expectedFocused.map(String.init) ?? "none"), actual \(report.actualFocused.map(String.init) ?? "none")")
    }
    if report.windows.isEmpty && !key.hasPrefix("settings") && !key.hasPrefix("app:hide:") { problems.append("no windows in the workspace") }
    // Windows that open, close, are minimized or unminimized, and apps that are hidden or shown, after a layout key.
    if let previous = results.last?.report {
        let parts = key.split(separator: ":", maxSplits: 2).map(String.init)
        let target = parts.count > 2 ? parts[2] : ""
        let ids = Set(report.windows.map(\.id)), previousIDs = Set(previous.windows.map(\.id))
        switch (parts[0], parts.count > 1 ? parts[1] : "") {
        case ("window", "open"):
            let new = ids.subtracting(previousIDs)
            if new.count != 1 { problems.append("\(new.count) new tiled windows, expected 1") }
            if let id = new.first {
                if report.expectedFocused != id { problems.append("the new window isn't the focused window") }
                if let f = tiledFocus, let p = ring(previous)[f], ring(report)[id] != [p[0], p[1] + 1] {
                    problems.append("the new window is at \(ring(report)[id] ?? []), expected after the focused window at \(p)")
                }
            }
        case ("window", "open-floating"):
            if ids != previousIDs || report.movedWindows != 0 { problems.append("a new floating window changed a container") }
            for w in report.windows where previous.windows.first(where: { $0.id == w.id })?.actual != w.actual { problems.append("\(w.title) moved") }
            if report.floating.count != previous.floating.count + 1 { problems.append("\(report.floating.count) floating windows, expected \(previous.floating.count + 1)") }
        case ("window", "close"), ("window", "minimize"):
            if report.windows.contains(where: { $0.title == target }) { problems.append("\(target) is still in a carousel") }
            if report.windows.count != previous.windows.count - 1 { problems.append("\(report.windows.count) tiled windows, expected \(previous.windows.count - 1)") }
            if parts[1] == "minimize", let w = previous.windows.first(where: { $0.title == target }) { savedRings[target] = [w.id: ring(previous)[w.id]!] }
            // After the focused window is removed, the window that was focused just before it gets focus. When that window isn't
            // in the carousel, the window at the ring index of the removed window gets focus.
            if let removed = previous.windows.first(where: { $0.title == target })?.id, removed == tiledFocus, let from = ring(previous)[removed] {
                let left = previous.windows.filter { $0.container == from[0] && $0.id != removed }.map(\.id)
                let back = focusedBefore[removed].flatMap { left.contains($0) ? $0 : nil }
                if let expected = back ?? (left.isEmpty ? nil : left[from[1] % left.count]), report.expectedFocused != expected {
                    problems.append("focus is on \(report.expectedFocused.map(String.init) ?? "none"), expected \(expected) (\(back == nil ? "the next window" : "the window focused before"))")
                }
            }
        case ("window", "unminimize"):
            if let w = report.windows.first(where: { $0.title == target }) {
                if ring(report)[w.id] != savedRings[target]?[w.id] {
                    problems.append("\(target) is at \(ring(report)[w.id] ?? []), expected \(savedRings[target]?[w.id] ?? [])")
                }
            } else { problems.append("\(target) isn't in a carousel") }
        case ("close", "focused"):
            // The window that had focus is closed with its close button.
            if let closed = previous.actualFocused, report.windows.contains(where: { $0.id == closed }) { problems.append("the closed window \(closed) is still in a carousel") }
            if report.windows.count != previous.windows.count - 1 { problems.append("\(report.windows.count) tiled windows, expected \(previous.windows.count - 1)") }
        case ("app", "hide"):
            if report.windows.contains(where: { $0.bundleID == target }) { problems.append("a window of \(target) is still in a carousel") }
            reportsBeforeHide[target] = previous
        case ("app", "show"):
            guard let before = reportsBeforeHide[target] else { problems.append("app:hide:\(target) didn't run before"); break }
            if ring(report) != ring(before) { problems.append("the ring positions differ from the positions before app:hide:\(target)") }
            // The shown app is activated. When its focused window is the focused window from before the hide, the frames are the same.
            for w in report.windows where report.expectedFocused == before.expectedFocused && before.windows.first(where: { $0.id == w.id })?.actual != w.actual {
                problems.append("\(w.title) has another frame than before app:hide:\(target)")
            }
        default: break
        }
        // A move puts the focused window in front of the carousel of the next or previous container. Focus stays in the old container,
        // on the window after the moved window, unless the old container is then empty.
        if report.action.hasPrefix("move-window-"), let moved = tiledFocus, let from = ring(previous)[moved] {
            let to = ring(report)[moved]
            if report.action.hasSuffix(":not-moved") {
                if ring(report) != ring(previous) { problems.append("a window moved to another container") }
            } else if let to {
                let left = previous.windows.filter { $0.container == from[0] && $0.id != moved }.map(\.id)
                if to[0] == from[0] { problems.append("the focused window is still in container \(from[0] + 1)") }
                if !(report.fronts ?? []).contains(moved) { problems.append("the moved window isn't the focused window of container \(to[0] + 1)") }
                let expected = left.isEmpty ? moved : left[from[1] % left.count]
                if report.expectedFocused != expected { problems.append("focus is on \(report.expectedFocused.map(String.init) ?? "none"), expected \(expected)") }
            } else { problems.append("the moved window isn't in a carousel") }
        }
    }
    // After a window is closed, minimized or moved, the focused window of each carousel is in front of the other windows of that carousel.
    if key.hasPrefix("close:") || key.hasPrefix("window:close:") || key.hasPrefix("window:minimize:") || report.action.hasPrefix("move-window-") {
        let order = frontToBack()
        func title(_ id: WindowID?) -> String {
            guard let id else { return "none" }
            return (report.windows + report.floating).first { $0.id == id }?.title ?? "\(id)"
        }
        for front in report.fronts ?? [] {
            guard let c = report.windows.first(where: { $0.id == front })?.container, let f = order.firstIndex(of: front) else { continue }
            for w in report.windows where w.container == c && w.id != front && (order.firstIndex(of: w.id) ?? .max) < f {
                problems.append("\(w.title) is in front of \(title(front)), the focused window of container \(c + 1)")
            }
        }
        let tiled = Set(report.windows.map(\.id))
        zOrderLines.append("\(index + 1) \(key): system focused window \(title(report.actualFocused)), frontmost app \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"); "
            + "focused window of each container: \((report.fronts ?? []).map(title).joined(separator: ", ")); "
            + "tiled windows front to back: \(order.filter(tiled.contains).map { id in "\(title(id)) (container \((report.windows.first { $0.id == id }?.container ?? -1) + 1))" }.joined(separator: ", "))")
    }
    if let f = report.expectedFocused, report.windows.contains(where: { $0.id == f }) {
        if let old = tiledFocus, old != f, report.windows.contains(where: { $0.id == old }) { focusedBefore[f] = old }
        tiledFocus = f
    }
    // After `record:leader`, the next `chord:` step must set the leader key.
    if key.hasPrefix("chord:"), index > 0, steps[index - 1] == "record:leader", let chord = chordOf(key),
       !report.action.contains("leader=\(chord.spec)") {
        problems.append("the leader key wasn't recorded: \(report.action)")
    }
    // A click ends leader key mode and gives the clicked window focus.
    if key.hasPrefix("click:") && !report.action.contains("layer=false") { problems.append("leader key mode didn't end: \(report.action)") }
    // A `pass:` chord after a click must reach the clicked window. It is checked in the key log at the end of the run.
    if key.hasPrefix("pass:"), index > 0, steps[index - 1].hasPrefix("click:"), let chord = chordOf(key),
       let clicked = results.last?.report, let id = clicked.expectedFocused,
       let title = (clicked.windows + clicked.floating).first(where: { $0.id == id })?.title {
        clickedKeyLines.append("\(title) \(logSuffix(chord))")
    }
    // A `pass:` chord isn't a leader key, so leader key mode must stay off.
    if key.hasPrefix("pass:") && !report.action.contains("layer=false") { problems.append("leader key mode started: \(report.action)") }
    // A floating window keeps the frame it had when it was first seen as floating.
    for w in report.floating {
        if report.windows.contains(where: { $0.id == w.id }) { problems.append("\(w.title) is floating and tiled") }
        guard let actual = w.actual else { continue }
        if let first = floatingFrames[w.id], !actual.matches(first) {
            problems.append("\(w.title) is floating and moved from \(first) to \(actual)")
        }
        floatingFrames[w.id] = floatingFrames[w.id] ?? actual
    }
    for w in report.windows { floatingFrames[w.id] = nil }
    if key == "esc", let previous = results.last?.report {
        let before = Dictionary(uniqueKeysWithValues: previous.windows.map { ($0.id, $0.actual) })
        for w in report.windows where before[w.id] != w.actual { problems.append("\(w.title) moved after Esc") }
    }
    results.append(StepResult(step: index + 1, key: key, passed: problems.isEmpty, problems: problems, report: report))
    print("\(index + 1) \(key) \(report.action) moved=\(report.movedWindows) latencyMs=\(String(format: "%.1f", report.latencyMs)) \(problems.isEmpty ? "PASS" : "FAIL \(problems)")")
    wait(0.8)
    let shot = String(format: "%02d-%@-%@", index + 1, key, report.action.replacingOccurrences(of: ":", with: "-")).replacingOccurrences(of: "/", with: "_")
    screenshot(shot)
    // A `settings` step and a `scroll:` step report the window number of the settings window. The window is also captured alone.
    if key.hasPrefix("settings") || key.hasPrefix("scroll:"), let number = report.action.split(separator: " ").first(where: { $0.hasPrefix("window=") })?.dropFirst("window=".count) {
        run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(number), out.appending(path: "screenshots/\(String(format: "%02d", index + 1))-settings-window.png").path])
    }
    // The "Export Diagnostics…" button writes the zip to the Desktop. The zip is moved into the proof bundle.
    if let range = report.action.range(of: "zip=/") {
        let zip = URL(filePath: String(report.action[report.action.index(range.lowerBound, offsetBy: 4)...]))
        try? FileManager.default.moveItem(at: zip, to: out.appending(path: zip.lastPathComponent))
    }
}

while video.isRunning { wait(0.2) }

// Only the keys that the proof run sends are checked. Other lines come from your own typing during the run.
// A `pass:` step sends a chord that must reach the app, so its line is expected in the log and isn't a failure.
func chordOf(_ step: String) -> KeyChord? {
    if let colon = step.firstIndex(of: ":") { return KeyChord(spec: String(step[step.index(after: colon)...])) }
    return KeyChord(spec: step)
}
func modsText(_ m: Modifiers) -> String {
    [(Modifiers.control, "ctrl"), (.option, "opt"), (.shift, "shift"), (.command, "cmd")].filter { m.contains($0.0) }.map(\.1).joined(separator: "+")
}
// Each line in the key log ends with the key code and the modifiers. A line for a chord that the run sends
// while leader key mode is active is a failure. Your own typing during the run has other modifiers, so it isn't counted.
func logSuffix(_ chord: KeyChord) -> String { "keyCode=\(chord.keyCode) mods=\(modsText(chord.modifiers))" }
var sentChords = steps.compactMap(chordOf) + [KeyChord(spec: "esc")!, KeyChord(spec: "ctrl+opt+space")!]
if let leader = option("--leader").flatMap(KeyChord.init(spec:)) { sentChords.append(leader) }
let passLines = Set(steps.filter { $0.hasPrefix("pass:") }.compactMap(chordOf).map(logSuffix))
let proofLines = Set(sentChords.map(logSuffix)).subtracting(passLines)
let logLines = ((try? String(contentsOf: keyLog, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
let passReached = passLines.allSatisfy { pass in logLines.contains { $0.hasSuffix(pass) } }
let keysReachedApp = logLines.filter { line in proofLines.contains { line.hasSuffix($0) } }.map { $0 + "\n" }.joined()
let clickedKeysReached = clickedKeyLines.allSatisfy(logLines.contains)
let keyLogPassed = keysReachedApp.isEmpty && passReached && clickedKeysReached
try? FileManager.default.copyItem(at: keyLog, to: out.appending(path: "testwindows-keys.log"))
let allPassed = keyLogPassed && results.allSatisfy(\.passed)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try! encoder.encode(results).write(to: out.appending(path: "frames.json"))
let latency = results.filter { $0.key != "esc" }
    .map { "\($0.step)\t\($0.key)\t\($0.report.action)\tmoved=\($0.report.movedWindows)\tlatencyMs=\(String(format: "%.2f", $0.report.latencyMs))" }
try! latency.joined(separator: "\n").appending("\n").write(to: out.appending(path: "latency.log"), atomically: true, encoding: .utf8)

var summary = "# Proof run\n\nResult: \(allPassed ? "PASS" : "FAIL")\n\n"
summary += "Managed apps: \(managed)\n\n"
summary += "| Step | Key | Action | Windows moved | Tiled | Floating | Latency (ms) | Result |\n|---|---|---|---|---|---|---|---|\n"
for r in results {
    summary += "| \(r.step) | `\(r.key)` | \(r.report.action) | \(r.report.movedWindows) | \(r.report.windows.count) | \(r.report.floating.map(\.title).joined(separator: ", ")) | \(String(format: "%.1f", r.report.latencyMs)) | \(r.passed ? "PASS" : "FAIL: " + r.problems.joined(separator: "; ")) |\n"
}
summary += "\nKey presses that reached the test windows while the Tiller layer was active: \(keysReachedApp.isEmpty ? "0 (PASS)" : "FAIL\n\n```\n\(keysReachedApp)```")\n"
if !passLines.isEmpty { summary += "Chords that must reach the test windows (`pass:` steps): \(passReached ? "all reached (PASS)" : "FAIL")\n" }
if !clickedKeyLines.isEmpty {
    summary += "Chords after a click that must reach the clicked window: \(clickedKeysReached ? "all reached (PASS)" : "FAIL") (\(clickedKeyLines.map { "`\($0)`" }.joined(separator: ", ")))\n"
}
if !zOrderLines.isEmpty {
    summary += "\n## Window order after each close, minimize and move step\n\n" + zOrderLines.map { "- \($0)\n" }.joined()
    try! zOrderLines.joined(separator: "\n").appending("\n").write(to: out.appending(path: "zorder.log"), atomically: true, encoding: .utf8)
}
try! summary.write(to: out.appending(path: "summary.md"), atomically: true, encoding: .utf8)

run("/usr/bin/pkill", ["-x", "Tiller"])
run("/usr/bin/pkill", ["-x", "TillerTestWindows"])
if appearance != nil { setDarkMode(originalDark) }
print(allPassed ? "PASS" : "FAIL")
exit(allPassed ? 0 : 1)
