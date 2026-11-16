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

let app = NSApplication.shared
app.setActivationPolicy(.regular)
// With "Prefer tabs" set to "Always" in System Settings, macOS merges the windows into one tabbed window.
NSWindow.allowsAutomaticWindowTabbing = false
for i in 1...count {
    let window = NSWindow(contentRect: NSRect(x: 120 + i * 60, y: 140 + i * 40, width: 640, height: 420),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Test \(i)"
    window.isReleasedWhenClosed = false
    let view = KeyLogView()
    view.wantsLayer = true
    view.layer?.backgroundColor = colors[(i - 1) % colors.count].withAlphaComponent(0.85).cgColor
    let label = NSTextField(labelWithString: "\(i)")
    label.font = .systemFont(ofSize: 160, weight: .bold)
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                 label.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
    window.contentView = view
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)
    windows.append(window)
}
// A window with a fixed size. The window rule floats it, like the WeChat update window.
let fixed = NSWindow(contentRect: NSRect(x: 700, y: 400, width: 360, height: 240),
                     styleMask: [.titled, .closable], backing: .buffered, defer: false)
fixed.title = "Test Floating"
fixed.isReleasedWhenClosed = false
let fixedView = KeyLogView()
fixedView.wantsLayer = true
fixedView.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.9).cgColor
let fixedLabel = NSTextField(labelWithString: "F")
fixedLabel.font = .systemFont(ofSize: 120, weight: .bold)
fixedLabel.textColor = .black
fixedLabel.translatesAutoresizingMaskIntoConstraints = false
fixedView.addSubview(fixedLabel)
NSLayoutConstraint.activate([fixedLabel.centerXAnchor.constraint(equalTo: fixedView.centerXAnchor),
                             fixedLabel.centerYAnchor.constraint(equalTo: fixedView.centerYAnchor)])
fixed.contentView = fixedView
fixed.makeKeyAndOrderFront(nil)
windows.append(fixed)
windows[count - 1].makeKeyAndOrderFront(nil)

app.activate()
app.run()
