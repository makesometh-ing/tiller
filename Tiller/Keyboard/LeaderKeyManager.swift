//
//  LeaderKeyManager.swift
//  Tiller
//

@preconcurrency import CoreGraphics
import Foundation

// MARK: - State

nonisolated enum LeaderState: Equatable, Sendable {
    case idle
    case leaderActive
    case subLayerActive(key: String)
}

// MARK: - Key Mapping (static key codes for tests)

nonisolated enum KeyMapping {
    static let space: UInt16 = 49
    static let escape: UInt16 = 53
    static let key1: UInt16 = 18
    static let key2: UInt16 = 19
    static let keyH: UInt16 = 4
    static let keyL: UInt16 = 37
    static let comma: UInt16 = 43
    static let period: UInt16 = 47

    static let optionFlag: UInt64 = 0x80000

    /// Legacy hardcoded lookup — kept for test compatibility. Production code uses KeybindingResolver.
    static func action(forKeyCode keyCode: UInt16, shift: Bool) -> KeyAction? {
        switch (keyCode, shift) {
        case (key1, false): return .switchLayout(.monocle)
        case (key2, false): return .switchLayout(.splitHalves)
        case (keyH, false): return .moveWindow(.left)
        case (keyL, false): return .moveWindow(.right)
        case (keyH, true): return .focusContainer(.left)
        case (keyL, true): return .focusContainer(.right)
        case (comma, true): return .cycleWindow(.previous)
        case (period, true): return .cycleWindow(.next)
        case (escape, _): return .exitLeader
        default: return nil
        }
    }
}

// MARK: - LeaderKeyManager

final class LeaderKeyManager {

    private(set) var state: LeaderState = .idle
    var onAction: ((KeyAction) -> Void)?
    var onStateChanged: ((LeaderState) -> Void)?

    private let configManager: ConfigManager
    private var resolver: KeybindingResolver
    nonisolated(unsafe) private var eventTap: CFMachPort?
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?
    private var timeoutTask: Task<Void, Never>?

    init(configManager: ConfigManager) {
        self.configManager = configManager
        self.resolver = KeybindingResolver(config: configManager.getConfig().keybindings)
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    // MARK: - Public API

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: LeaderKeyManager.eventTapCallback,
            userInfo: selfPtr
        ) else {
            TillerLogger.debug("keyboard", "[LeaderKey] ERROR: Failed to create CGEventTap — accessibility permission may be missing")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        TillerLogger.debug("keyboard", "[LeaderKey] Event tap started")
    }

    func stop() {
        stopEventTap()
        exitLeaderMode()
    }

    func updateBindings(from config: KeybindingsConfig) {
        resolver = KeybindingResolver(config: config)
    }

    // MARK: - State Machine

    func handleKeyEvent(keyCode: UInt16, flags: CGEventFlags, eventType: CGEventType) -> Bool {
        let isShift = flags.rawValue & UInt64(CGEventFlags.maskShift.rawValue) != 0

        TillerLogger.debug("keyboard", "[LeaderKey] Event: keyCode=\(keyCode) flags=0x\(String(flags.rawValue, radix: 16)) type=\(eventType.rawValue) state=\(state) leaderKeyCode=\(resolver.leaderKeyCode) leaderMask=0x\(String(resolver.leaderModifierMask, radix: 16))")

        switch state {
        case .idle:
            return handleIdleKeyEvent(keyCode: keyCode, flags: flags, eventType: eventType)

        case .leaderActive, .subLayerActive:
            return handleLeaderKeyEvent(keyCode: keyCode, flags: flags, eventType: eventType, isShift: isShift)
        }
    }

    // MARK: - Idle State

    private func handleIdleKeyEvent(keyCode: UInt16, flags: CGEventFlags, eventType: CGEventType) -> Bool {
        if eventType == .keyDown && resolver.isLeaderTrigger(keyCode: keyCode, flags: flags.rawValue) {
            enterLeaderMode()
            return true
        }
        return false
    }

    // MARK: - Leader Active State

    private func handleLeaderKeyEvent(keyCode: UInt16, flags: CGEventFlags, eventType: CGEventType, isShift: Bool) -> Bool {
        guard eventType == .keyDown else { return true }

        // Leader trigger again exits leader
        if resolver.isLeaderTrigger(keyCode: keyCode, flags: flags.rawValue) {
            exitLeaderMode()
            return true
        }

        // Config-driven dispatch
        if let resolved = resolver.resolve(keyCode: keyCode, shift: isShift) {
            dispatchAction(resolved.action, staysInLeader: resolved.staysInLeader)
            return true
        }

        // Unrecognized key: consume but stay in leader, reset timeout
        resetTimeout()
        return true
    }

    // MARK: - Leader Mode Transitions

    private func enterLeaderMode() {
        state = .leaderActive
        onStateChanged?(.leaderActive)
        resetTimeout()
        TillerLogger.debug("keyboard", "[LeaderKey] Leader mode activated")
    }

    func exitLeaderMode() {
        guard state != .idle else { return }
        state = .idle
        onStateChanged?(.idle)
        timeoutTask?.cancel()
        timeoutTask = nil
        TillerLogger.debug("keyboard", "[LeaderKey] Leader mode deactivated")
    }

    // MARK: - Action Dispatch

    private func dispatchAction(_ action: KeyAction, staysInLeader: Bool) {
        TillerLogger.debug("keyboard", "[LeaderKey] Dispatching action: \(action)")
        onAction?(action)

        if staysInLeader {
            resetTimeout()
        } else {
            exitLeaderMode()
        }
    }

    // MARK: - Timeout

    private func resetTimeout() {
        timeoutTask?.cancel()

        let timeout = configManager.getConfig().leaderTimeout
        guard timeout > 0 else { return }

        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.exitLeaderMode()
                TillerLogger.debug("keyboard", "[LeaderKey] Leader mode timed out after \(timeout)s")
            } catch {
                // Cancelled — expected during timeout reset
            }
        }
    }

    // MARK: - Event Tap

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
            TillerLogger.debug("keyboard", "[LeaderKey] Event tap stopped")
        }
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, eventType, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let manager = Unmanaged<LeaderKeyManager>.fromOpaque(userInfo).takeUnretainedValue()
        return MainActor.assumeIsolated {
            if eventType == .tapDisabledByUserInput || eventType == .tapDisabledByTimeout {
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            let consumed = manager.handleKeyEvent(keyCode: keyCode, flags: flags, eventType: eventType)

            if consumed {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }
    }
}
