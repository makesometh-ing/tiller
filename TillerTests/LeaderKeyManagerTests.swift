//
//  LeaderKeyManagerTests.swift
//  TillerTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Tiller

struct LeaderKeyManagerTests {

    var sut: LeaderKeyManager
    let configManager: ConfigManager
    let tempDirectory: URL
    var receivedActions: [KeyAction]
    var receivedStates: [LeaderState]

    init() async throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        configManager = ConfigManager(
            fileManager: .default,
            basePath: tempDirectory.path,
            notificationService: MockNotificationService()
        )
        configManager.loadConfiguration()

        sut = LeaderKeyManager(configManager: configManager)
        receivedActions = []
        receivedStates = []

        sut.onAction = { [self] action in
            // Note: In Swift Testing structs, we can't use weak self pattern the same way.
            // The closure captures will be set up after init.
        }
    }

    // MARK: - Helpers

    /// Simulates a keyDown event through the state machine.
    /// Returns true if the event was consumed.
    @discardableResult
    private mutating func simulateKeyDown(_ keyCode: UInt16, option: Bool = false, shift: Bool = false) -> Bool {
        var rawFlags: UInt64 = 0
        if option { rawFlags |= KeyMapping.optionFlag }
        if shift { rawFlags |= UInt64(CGEventFlags.maskShift.rawValue) }
        let flags = CGEventFlags(rawValue: rawFlags)
        return sut.handleKeyEvent(keyCode: keyCode, flags: flags, eventType: .keyDown)
    }

    private mutating func activateLeader() {
        simulateKeyDown(KeyMapping.space, option: true)
    }

    // MARK: - State Machine: Idle -> Leader

    @Test mutating func startsInIdleState() {
        #expect(sut.state == .idle)
    }

    @Test mutating func optionSpaceActivatesLeader() {
        let consumed = simulateKeyDown(KeyMapping.space, option: true)

        #expect(consumed)
        #expect(sut.state == .leaderActive)
    }

    @Test mutating func spaceWithoutOptionPassesThrough() {
        let consumed = simulateKeyDown(KeyMapping.space)

        #expect(!consumed)
        #expect(sut.state == .idle)
    }

    @Test mutating func regularKeysPassThroughInIdle() {
        let consumed = simulateKeyDown(KeyMapping.keyH)

        #expect(!consumed)
        #expect(sut.state == .idle)
    }

    // MARK: - State Machine: Leader -> Idle

    @Test mutating func optionSpaceAgainExitsLeader() {
        activateLeader()
        #expect(sut.state == .leaderActive)

        let consumed = simulateKeyDown(KeyMapping.space, option: true)

        #expect(consumed)
        #expect(sut.state == .idle)
    }

    @Test mutating func escapeExitsLeader() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()

        let consumed = simulateKeyDown(KeyMapping.escape)

        #expect(consumed)
        #expect(sut.state == .idle)
        #expect(actions == [.exitLeader])
    }

    // MARK: - Key Mapping: Layout Switch

    @Test mutating func key1SwitchesToMonocle() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()
        simulateKeyDown(KeyMapping.key1)

        #expect(actions == [.switchLayout(.monocle)])
        #expect(sut.state == .idle, "Layout switch should exit leader")
    }

    @Test mutating func key2SwitchesToSplitHalves() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()
        simulateKeyDown(KeyMapping.key2)

        #expect(actions == [.switchLayout(.splitHalves)])
        #expect(sut.state == .idle, "Layout switch should exit leader")
    }

    // MARK: - Key Mapping: Move Window

    @Test mutating func hMovesWindowLeft() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()
        simulateKeyDown(KeyMapping.keyH)

        #expect(actions == [.moveWindow(.left)])
        #expect(sut.state == .leaderActive, "Move should stay in leader")
    }

    @Test mutating func lMovesWindowRight() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()
        simulateKeyDown(KeyMapping.keyL)

        #expect(actions == [.moveWindow(.right)])
        #expect(sut.state == .leaderActive, "Move should stay in leader")
    }

    // MARK: - Key Mapping: Focus Container

    @Test mutating func shiftHFocusesLeft() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()
        simulateKeyDown(KeyMapping.keyH, shift: true)

        #expect(actions == [.focusContainer(.left)])
        #expect(sut.state == .leaderActive, "Focus should stay in leader")
    }

    @Test mutating func shiftLFocusesRight() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()
        simulateKeyDown(KeyMapping.keyL, shift: true)

        #expect(actions == [.focusContainer(.right)])
        #expect(sut.state == .leaderActive, "Focus should stay in leader")
    }

    // MARK: - Key Mapping: Cycle Window

    @Test mutating func shiftCommaCyclesPrevious() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()
        simulateKeyDown(KeyMapping.comma, shift: true)

        #expect(actions == [.cycleWindow(.previous)])
        #expect(sut.state == .leaderActive, "Cycle should stay in leader")
    }

    @Test mutating func shiftPeriodCyclesNext() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()
        simulateKeyDown(KeyMapping.period, shift: true)

        #expect(actions == [.cycleWindow(.next)])
        #expect(sut.state == .leaderActive, "Cycle should stay in leader")
    }

    // MARK: - Unrecognized Keys

    @Test mutating func unrecognizedKeyConsumedButStaysInLeader() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()

        // 'z' key (keyCode 6) is not mapped
        let consumed = simulateKeyDown(6)

        #expect(consumed, "Should consume unknown key in leader mode")
        #expect(sut.state == .leaderActive, "Should stay in leader")
        #expect(actions.isEmpty, "Should not dispatch any action")
    }

    // MARK: - Multi-Action Sequences

    @Test mutating func multipleActionsStayInLeader() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()

        simulateKeyDown(KeyMapping.keyH)       // moveWindow left
        simulateKeyDown(KeyMapping.keyL)       // moveWindow right
        simulateKeyDown(KeyMapping.keyH, shift: true)  // focusContainer left

        #expect(actions.count == 3)
        #expect(actions[0] == .moveWindow(.left))
        #expect(actions[1] == .moveWindow(.right))
        #expect(actions[2] == .focusContainer(.left))
        #expect(sut.state == .leaderActive)
    }

    @Test mutating func layoutSwitchExitsThenKeysPassThrough() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()

        simulateKeyDown(KeyMapping.key1)  // switchLayout -> exits leader
        #expect(sut.state == .idle)

        let consumed = simulateKeyDown(KeyMapping.keyH)  // should pass through
        #expect(!consumed)
        #expect(actions.count == 1)  // only the layout switch
    }

    // MARK: - Timeout

    @Test func timeoutExitsLeaderMode() async {
        // Use a very short timeout for testing
        let shortTimeoutConfig = TillerConfig(
            margin: 8, padding: 8, accordionOffset: 16,
            leaderTimeout: 0.1,
            floatingApps: [], logLocation: nil
        )
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let cm = ConfigManager(fileManager: .default, basePath: tempDir.path, notificationService: MockNotificationService())

        // Write short timeout config
        let data = try! JSONEncoder().encode(shortTimeoutConfig)
        let configDir = (tempDir.path as NSString).appendingPathComponent(".config/tiller")
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        try! data.write(to: URL(fileURLWithPath: (configDir as NSString).appendingPathComponent("config.json")))
        cm.loadConfiguration()

        let manager = LeaderKeyManager(configManager: cm)
        manager.onAction = { _ in }

        // Activate leader via state machine
        let flags = CGEventFlags(rawValue: KeyMapping.optionFlag)
        _ = manager.handleKeyEvent(keyCode: KeyMapping.space, flags: flags, eventType: .keyDown)
        #expect(manager.state == .leaderActive)

        // Wait for timeout
        try? await Task.sleep(nanoseconds: 250_000_000)

        #expect(manager.state == .idle, "Leader should auto-exit after timeout")

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func timeoutResetsOnKeypress() async {
        let shortTimeoutConfig = TillerConfig(
            margin: 8, padding: 8, accordionOffset: 16,
            leaderTimeout: 0.2,
            floatingApps: [], logLocation: nil
        )
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let cm = ConfigManager(fileManager: .default, basePath: tempDir.path, notificationService: MockNotificationService())

        let configDir = (tempDir.path as NSString).appendingPathComponent(".config/tiller")
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        let data = try! JSONEncoder().encode(shortTimeoutConfig)
        try! data.write(to: URL(fileURLWithPath: (configDir as NSString).appendingPathComponent("config.json")))
        cm.loadConfiguration()

        let manager = LeaderKeyManager(configManager: cm)
        manager.onAction = { _ in }

        let flags = CGEventFlags(rawValue: KeyMapping.optionFlag)
        _ = manager.handleKeyEvent(keyCode: KeyMapping.space, flags: flags, eventType: .keyDown)
        #expect(manager.state == .leaderActive)

        // Wait 150ms (75% of timeout), then press a key to reset
        try? await Task.sleep(nanoseconds: 150_000_000)
        let noFlags = CGEventFlags(rawValue: 0)
        _ = manager.handleKeyEvent(keyCode: KeyMapping.keyH, flags: noFlags, eventType: .keyDown)
        #expect(manager.state == .leaderActive)

        // Wait another 150ms — should still be active because timeout was reset
        try? await Task.sleep(nanoseconds: 150_000_000)
        #expect(manager.state == .leaderActive, "Timeout should have been reset by keypress")

        // Wait full timeout from last keypress
        try? await Task.sleep(nanoseconds: 150_000_000)
        #expect(manager.state == .idle, "Should timeout after no keypresses")

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func zeroTimeoutMeansInfinite() async {
        let noTimeoutConfig = TillerConfig(
            margin: 8, padding: 8, accordionOffset: 16,
            leaderTimeout: 0,
            floatingApps: [], logLocation: nil
        )
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let cm = ConfigManager(fileManager: .default, basePath: tempDir.path, notificationService: MockNotificationService())

        let configDir = (tempDir.path as NSString).appendingPathComponent(".config/tiller")
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        let data = try! JSONEncoder().encode(noTimeoutConfig)
        try! data.write(to: URL(fileURLWithPath: (configDir as NSString).appendingPathComponent("config.json")))
        cm.loadConfiguration()

        let manager = LeaderKeyManager(configManager: cm)
        manager.onAction = { _ in }

        let flags = CGEventFlags(rawValue: KeyMapping.optionFlag)
        _ = manager.handleKeyEvent(keyCode: KeyMapping.space, flags: flags, eventType: .keyDown)
        #expect(manager.state == .leaderActive)

        // Wait 500ms — should still be active (no timeout)
        try? await Task.sleep(nanoseconds: 500_000_000)
        #expect(manager.state == .leaderActive, "Zero timeout should mean infinite — no auto-exit")

        manager.exitLeaderMode()
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - onStateChanged Callback

    @Test mutating func onStateChangedFiresOnEnterAndExit() {
        var states: [LeaderState] = []
        sut.onStateChanged = { state in
            states.append(state)
        }

        activateLeader()
        #expect(states == [.leaderActive])

        simulateKeyDown(KeyMapping.escape)
        #expect(states == [.leaderActive, .idle])
    }

    @Test mutating func onStateChangedNotCalledWhenAlreadyIdle() {
        var states: [LeaderState] = []
        sut.onStateChanged = { state in
            states.append(state)
        }

        sut.exitLeaderMode()
        #expect(states.isEmpty)
    }

    // MARK: - KeyMapping Unit Tests

    @Test func keyMappingReturnsNilForUnmappedKeys() {
        #expect(KeyMapping.action(forKeyCode: 6, shift: false) == nil)   // z
        #expect(KeyMapping.action(forKeyCode: 0, shift: false) == nil)   // a
        #expect(KeyMapping.action(forKeyCode: 49, shift: false) == nil)  // space (no option in this context)
    }

    @Test func keyMappingAllMappedKeys() {
        #expect(KeyMapping.action(forKeyCode: KeyMapping.key1, shift: false) == .switchLayout(.monocle))
        #expect(KeyMapping.action(forKeyCode: KeyMapping.key2, shift: false) == .switchLayout(.splitHalves))
        #expect(KeyMapping.action(forKeyCode: KeyMapping.keyH, shift: false) == .moveWindow(.left))
        #expect(KeyMapping.action(forKeyCode: KeyMapping.keyL, shift: false) == .moveWindow(.right))
        #expect(KeyMapping.action(forKeyCode: KeyMapping.keyH, shift: true) == .focusContainer(.left))
        #expect(KeyMapping.action(forKeyCode: KeyMapping.keyL, shift: true) == .focusContainer(.right))
        #expect(KeyMapping.action(forKeyCode: KeyMapping.comma, shift: true) == .cycleWindow(.previous))
        #expect(KeyMapping.action(forKeyCode: KeyMapping.period, shift: true) == .cycleWindow(.next))
        #expect(KeyMapping.action(forKeyCode: KeyMapping.escape, shift: false) == .exitLeader)
    }

    // MARK: - KeyAction.staysInLeader

    @Test func staysInLeaderProperty() {
        #expect(!KeyAction.switchLayout(.monocle).staysInLeader)
        #expect(!KeyAction.switchLayout(.splitHalves).staysInLeader)
        #expect(KeyAction.moveWindow(.left).staysInLeader)
        #expect(KeyAction.moveWindow(.right).staysInLeader)
        #expect(KeyAction.focusContainer(.left).staysInLeader)
        #expect(KeyAction.focusContainer(.right).staysInLeader)
        #expect(KeyAction.cycleWindow(.next).staysInLeader)
        #expect(KeyAction.cycleWindow(.previous).staysInLeader)
        #expect(!KeyAction.exitLeader.staysInLeader)
    }

    // MARK: - Config-Driven Bindings

    @Test mutating func remappedKeysDispatchCorrectly() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        // Create config with h/l swapped
        var kb = KeybindingsConfig.default
        kb.actions["moveWindow.left"] = ActionBinding(keys: ["l"], leaderLayer: true, subLayer: nil, staysInLeader: true)
        kb.actions["moveWindow.right"] = ActionBinding(keys: ["h"], leaderLayer: true, subLayer: nil, staysInLeader: true)

        sut.updateBindings(from: kb)

        activateLeader()

        // h should now be moveWindow.right
        simulateKeyDown(KeyMapping.keyH)
        #expect(actions.last == .moveWindow(.right))

        // l should now be moveWindow.left
        simulateKeyDown(KeyMapping.keyL)
        #expect(actions.last == .moveWindow(.left))
    }

    @Test mutating func updateBindingsMidSession() {
        var actions: [KeyAction] = []
        sut.onAction = { action in
            actions.append(action)
        }

        activateLeader()

        // Default: h = moveWindow.left
        simulateKeyDown(KeyMapping.keyH)
        #expect(actions.last == .moveWindow(.left))

        // Update bindings: swap h/l
        var kb = KeybindingsConfig.default
        kb.actions["moveWindow.left"] = ActionBinding(keys: ["l"], leaderLayer: true, subLayer: nil, staysInLeader: true)
        kb.actions["moveWindow.right"] = ActionBinding(keys: ["h"], leaderLayer: true, subLayer: nil, staysInLeader: true)
        sut.updateBindings(from: kb)

        // h should now be moveWindow.right (after mid-session update)
        simulateKeyDown(KeyMapping.keyH)
        #expect(actions.last == .moveWindow(.right))
    }

    // MARK: - Hyper Key Support

    @Test mutating func hyperKeyActivatesLeader() {
        // Configure hyper key (all 4 modifiers + backspace) as leader trigger
        var kb = KeybindingsConfig.default
        kb.leaderTrigger = ["cmd", "ctrl", "shift", "option", "backspace"]
        sut.updateBindings(from: kb)

        // Simulate keyDown with all 4 modifier flags + backspace key code
        var rawFlags: UInt64 = 0
        rawFlags |= 0x100000  // cmd
        rawFlags |= 0x40000   // ctrl
        rawFlags |= 0x20000   // shift
        rawFlags |= 0x80000   // option
        let flags = CGEventFlags(rawValue: rawFlags)
        let backspaceKeyCode: UInt16 = 51

        let consumed = sut.handleKeyEvent(keyCode: backspaceKeyCode, flags: flags, eventType: .keyDown)

        #expect(consumed, "Hyper key + backspace should be consumed as leader trigger")
        #expect(sut.state == .leaderActive, "Hyper key + backspace should activate leader mode")
    }
}
