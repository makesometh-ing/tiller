import AppKit
import TillerCore

enum Action: Equatable {
    case layout(LayoutKind)
    case focusWindow(Int)
    case focusContainer(Int)
    /// Moves the focused window to the container `offset` positions away. Focus stays in the old container.
    case moveWindow(Int)
    /// Floats the focused tiled window, or tiles the focused window that was floated with this action.
    case toggleFloat
    /// Raises the floating windows of the focused app. The front floating window gets focus.
    case raiseFloating
    /// Switches the carousel of the focused container between horizontal and vertical.
    case toggleAxis
    case turnOff
}

/// Reads key presses with an event tap. After the leader key, the next key presses don't reach the focused app.
/// The layer ends after `Esc`, after a second leader key press, or after an action with the "Exit after" setting on.
final class LeaderKey {
    static let escapeKeyCode: Int64 = 53
    static let keyListKeyCode: Int64 = 44  // The `/` key. `?` is shift and `/`.

    /// Read on the main thread for each key press, so that changes in the settings apply at once.
    var shortcuts: () -> Shortcuts = { .standard }
    /// When set, the next key press is passed to this function and nothing else is done with it.
    /// `Esc` passes nil. The settings window sets it while a shortcut field records.
    var recorder: ((KeyChord?) -> Void)?

    var onLayerChange: (Bool) -> Void = { _ in }
    /// Called on the main thread with the action and the time the key press was received.
    var onAction: (Action, DispatchTime) -> Void = { _, _ in }
    var onCancel: () -> Void = {}
    /// Called on the main thread when `?` is pressed. The layer stays active.
    var onKeyList: () -> Void = {}
    /// When false, only the `toggle` chord is stopped. Each other key press goes to the focused app.
    var isEnabled: () -> Bool = { true }
    /// Called on the main thread when the `toggle` chord is pressed. Leader key mode ends.
    var onToggle: () -> Void = {}

    /// Called on the main thread for a mouse down while leader key mode is active, with the location in Accessibility coordinates.
    /// Returns false when the click doesn't end leader key mode, for example a click on the key bar.
    var clickEndsLayer: (CGPoint) -> Bool = { _ in true }
    /// The time of the last mouse down. Read and written on the main thread.
    private(set) var lastMouseDown: DispatchTime?

    private(set) var isLayerActive = false {
        didSet { if oldValue != isLayerActive { onLayerChange(isLayerActive) } }
    }
    /// The time of the last key down, for the `tap.disabled` log event.
    private var lastKeyDown: DispatchTime?
    /// True when the listen-only mouse tap started.
    private(set) var mouseTapStarted = false

    /// Starts or ends leader key mode and writes `leader.start` or `leader.end`.
    private func setLayer(_ active: Bool, reason: String, _ fields: [String: LogValue] = [:]) {
        guard active != isLayerActive else { return }
        Log.event(active ? .leaderStart : .leaderEnd, fields.merging(["reason": .string(reason)]) { $1 })
        isLayerActive = active
    }
    private var tap: CFMachPort?
    /// A listen-only tap for mouse down events. It can't stop or delay a click.
    private var mouseTap: CFMachPort?
    /// Key codes whose key down event was stopped. Their key up event is stopped too.
    private var stoppedKeyUps = Set<Int64>()

    func start() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        // Key remappers such as Hyperkey add modifier flags in their own session event tap.
        // The annotated session tap point receives each event after every session tap.
        tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                Unmanaged<LeaderKey>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return false }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        let mouseMask = [CGEventType.leftMouseDown, .rightMouseDown, .otherMouseDown].reduce(0) { $0 | (1 << $1.rawValue) }
        mouseTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
            eventsOfInterest: CGEventMask(mouseMask),
            callback: { _, type, event, refcon in
                Unmanaged<LeaderKey>.fromOpaque(refcon!).takeUnretainedValue().handleMouse(type, event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let mouseTap {
            CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, mouseTap, 0), .commonModes)
            CGEvent.tapEnable(tap: mouseTap, enable: true)
            mouseTapStarted = true
        }
        return true
    }

    /// A click ends leader key mode. The click goes to the window under the pointer.
    private func handleMouse(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let mouseTap { CGEvent.tapEnable(tap: mouseTap, enable: true) }
            Log.event(.tapDisabled, ["tap": "mouse", "reason": type == .tapDisabledByTimeout ? "timeout" : "userInput"])
            return
        }
        lastMouseDown = .now()
        guard isLayerActive, clickEndsLayer(event.location) else { return }
        // `timestamp` is the time of the click in nanoseconds since boot.
        let tapMs = Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - event.timestamp) / 1e6
        setLayer(false, reason: "click", ["x": .int(Int(event.location.x)), "y": .int(Int(event.location.y)), "clickToTapMs": .ms(tapMs)])
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            // A timeout means that a callback took too long.
            Log.event(.tapDisabled, ["tap": "keys", "reason": type == .tapDisabledByTimeout ? "timeout" : "userInput",
                                     "msSinceLastKey": lastKeyDown.map(Log.ms(since:)) ?? .null])
            return pass
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp {
            return stoppedKeyUps.remove(code) != nil ? nil : pass
        }
        lastKeyDown = .now()
        let modifiers = Modifiers(event.flags)
        if let recorder {
            stoppedKeyUps.insert(code)
            guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return nil }
            self.recorder = nil
            recorder(code == Self.escapeKeyCode && modifiers.isEmpty ? nil : KeyChord(keyCode: UInt16(code), modifiers: modifiers))
            return nil
        }
        let shortcuts = shortcuts()
        if KeyChord(keyCode: UInt16(code), modifiers: modifiers) == shortcuts.toggle {
            stoppedKeyUps.insert(code)
            guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return nil }
            setLayer(false, reason: "toggle")
            onToggle()
            return nil
        }
        guard isEnabled() else { return pass }
        if let id = shortcuts.globalAction(keyCode: UInt16(code), modifiers: modifiers) {
            // A global shortcut does its action in every app, also in leader key mode. Leader key mode doesn't change, except for `turnOff`.
            stoppedKeyUps.insert(code)
            guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return nil }
            Log.event(.globalKey, ["chord": .string(KeyChord(keyCode: UInt16(code), modifiers: modifiers).spec), "action": .string(id.rawValue)])
            if id == .turnOff { setLayer(false, reason: "action", ["action": .string(id.rawValue)]) }
            onAction(id.action, .now())
            return nil
        }
        let isLeader = shortcuts.isLeader(keyCode: UInt16(code), modifiers: modifiers)
        guard isLayerActive || isLeader else { return pass }

        stoppedKeyUps.insert(code)
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
        let received = DispatchTime.now()
        let chord = LogValue.string(KeyChord(keyCode: UInt16(code), modifiers: modifiers).spec)
        if !isLayerActive {
            setLayer(true, reason: "leader", ["chord": chord])
        } else if isLeader || code == Self.escapeKeyCode {
            Log.event(.leaderKey, ["chord": chord, "action": isLeader ? "leader" : "esc"])
            setLayer(false, reason: isLeader ? "leader" : "esc")
            onCancel()
        } else if code == Self.keyListKeyCode {
            Log.event(.leaderKey, ["chord": chord, "action": "keyList"])
            onKeyList()
        } else if let id = shortcuts.action(keyCode: UInt16(code), modifiers: modifiers) {
            Log.event(.leaderKey, ["chord": chord, "action": .string(id.rawValue)])
            if shortcuts.exits(after: id) { setLayer(false, reason: "action", ["action": .string(id.rawValue)]) }
            onAction(id.action, received)
        } else {
            Log.event(.leaderKey, ["chord": chord, "action": "unbound"])
        }
        return nil
    }
}
