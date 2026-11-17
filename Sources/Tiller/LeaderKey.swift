import AppKit
import TillerCore

enum Action: Equatable {
    case layout(LayoutKind)
    case focusWindow(Int)
    case focusContainer(Int)
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

    private(set) var isLayerActive = false {
        didSet { if oldValue != isLayerActive { onLayerChange(isLayerActive) } }
    }
    private var tap: CFMachPort?
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
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            Log.write("event tap re-enabled after \(type == .tapDisabledByTimeout ? "timeout" : "user input")")
            return pass
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp {
            return stoppedKeyUps.remove(code) != nil ? nil : pass
        }
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
            isLayerActive = false
            onToggle()
            return nil
        }
        guard isEnabled() else { return pass }
        let isLeader = shortcuts.isLeader(keyCode: UInt16(code), modifiers: modifiers)
        guard isLayerActive || isLeader else { return pass }

        stoppedKeyUps.insert(code)
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
        let received = DispatchTime.now()
        if !isLayerActive {
            isLayerActive = true
        } else if isLeader || code == Self.escapeKeyCode {
            isLayerActive = false
            onCancel()
        } else if code == Self.keyListKeyCode {
            onKeyList()
        } else if let id = shortcuts.action(keyCode: UInt16(code), modifiers: modifiers) {
            if shortcuts.exits(after: id) { isLayerActive = false }
            onAction(id.action, received)
        }
        return nil
    }
}
