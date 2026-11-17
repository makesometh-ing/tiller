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
run("/usr/bin/open", [build.appending(path: "Tiller.app").path, "--args"] + tillerArgs)
let deadline = Date().addingTimeInterval(15)
while !ready && Date() < deadline { wait(0.1) }
if !ready { fail("Tiller didn't start its event tap in 15 seconds. Grant Accessibility permission to \(build.appending(path: "Tiller.app").path).") }

run("/usr/bin/open", ["-b", testBundleID])
wait(1)
let video = Process()
video.executableURL = URL(filePath: "/usr/sbin/screencapture")
// screencapture discards the video when it is interrupted, so the duration is fixed and the run waits for the end.
// Each step takes about 1.5 seconds.
video.arguments = ["-v", "-x", "-V", "\(steps.count * 2 + 4)", out.appending(path: "run.mov").path]
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
for (index, key) in steps.enumerated() {
    lastResult = nil
    center.postNotificationName(.init("com.tiller.proof.press"), object: nil, userInfo: ["key": key], deliverImmediately: true)
    // The diagnostics export reads the unified log, which takes some seconds.
    let stepDeadline = Date().addingTimeInterval(key.hasPrefix("export-diagnostics") ? 60 : 5)
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
    if report.windows.isEmpty && !key.hasPrefix("settings") { problems.append("no windows in the workspace") }
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
    screenshot(String(format: "%02d-%@-%@", index + 1, key, report.action.replacingOccurrences(of: ":", with: "-")).replacingOccurrences(of: "/", with: "_"))
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
try! summary.write(to: out.appending(path: "summary.md"), atomically: true, encoding: .utf8)

run("/usr/bin/pkill", ["-x", "Tiller"])
run("/usr/bin/pkill", ["-x", "TillerTestWindows"])
if appearance != nil { setDarkMode(originalDark) }
print(allPassed ? "PASS" : "FAIL")
exit(allPassed ? 0 : 1)
