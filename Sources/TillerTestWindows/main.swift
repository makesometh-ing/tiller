import AppKit

/// Opens windows with known titles for the proof runner. Each key press that reaches a window
/// is written to ~/Library/Logs/Tiller/testwindows-keys.log. While the Tiller layer is active,
/// that file must stay empty.
let keyLog = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Tiller/testwindows-keys.log")
try? FileManager.default.createDirectory(at: keyLog.deletingLastPathComponent(), withIntermediateDirectories: true)
try? Data().write(to: keyLog)

final class KeyLogView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let mods = [(NSEvent.ModifierFlags.control, "ctrl"), (.option, "opt"), (.shift, "shift"), (.command, "cmd")]
            .filter { flags.contains($0.0) }.map(\.1).joined(separator: "+")
        let line = "\(window?.title ?? "") keyCode=\(event.keyCode) mods=\(mods)\n"
        if let handle = try? FileHandle(forWritingTo: keyLog) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        }
    }
}

let count = CommandLine.arguments.dropFirst().compactMap { Int($0) }.first ?? 5
let colors: [NSColor] = [.systemBlue, .systemPurple, .systemPink, .systemOrange, .systemTeal, .systemGreen, .systemIndigo, .systemRed]
var windows: [NSWindow] = []
var tiledCount = 0
var floatingCount = 0

func makeWindow(title: String, label text: String, frame: NSRect, style: NSWindow.StyleMask, color: NSColor, textColor: NSColor, fontSize: CGFloat) -> NSWindow {
    let window = NSWindow(contentRect: frame, styleMask: style, backing: .buffered, defer: false)
    window.title = title
    window.isReleasedWhenClosed = false
    let view = KeyLogView()
    view.wantsLayer = true
    view.layer?.backgroundColor = color.cgColor
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: fontSize, weight: .bold)
    label.textColor = textColor
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                 label.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
    window.contentView = view
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)
    windows.append(window)
    return window
}

/// Opens a tiled window with the next number.
@discardableResult
func openTiled() -> NSWindow {
    tiledCount += 1
    let i = tiledCount
    return makeWindow(title: "Test \(i)", label: "\(i)", frame: NSRect(x: 120 + i * 60, y: 140 + i * 40, width: 640, height: 420),
                      style: [.titled, .closable, .miniaturizable, .resizable], color: colors[(i - 1) % colors.count].withAlphaComponent(0.85), textColor: .white, fontSize: 160)
}

/// Opens a window with a fixed size. The window rule floats it, like the WeChat update window.
func openFloating() {
    floatingCount += 1
    makeWindow(title: floatingCount == 1 ? "Test Floating" : "Test Floating \(floatingCount)", label: "F",
               frame: NSRect(x: 700 - floatingCount * 40, y: 400 - floatingCount * 40, width: 360, height: 240),
               style: [.titled, .closable], color: .systemYellow.withAlphaComponent(0.9), textColor: .black, fontSize: 120)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
// With "Prefer tabs" set to "Always" in System Settings, macOS merges the windows into one tabbed window.
NSWindow.allowsAutomaticWindowTabbing = false
for _ in 1...count { openTiled() }
openFloating()
windows[count - 1].makeKeyAndOrderFront(nil)

// Commands from Tiller in a proof run: `open`, `open-floating`, `close:<title>`, `minimize:<title>` and `unminimize:<title>`.
DistributedNotificationCenter.default().addObserver(forName: .init("com.tiller.testwindows.command"), object: nil, queue: .main) { note in
    guard let command = note.userInfo?["command"] as? String else { return }
    let parts = command.split(separator: ":", maxSplits: 1).map(String.init)
    let target = parts.count > 1 ? windows.first { $0.title == parts[1] } : nil
    switch parts[0] {
    case "open": openTiled()
    case "open-floating": openFloating()
    case "close": target?.performClose(nil)
    case "minimize": target?.miniaturize(nil)
    case "unminimize": target?.deminiaturize(nil)
    default: break
    }
}

app.activate()
app.run()
