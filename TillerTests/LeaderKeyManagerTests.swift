//
//  LeaderKeyManagerTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

@MainActor
final class LeaderKeyManagerTests: XCTestCase {

    private var sut: LeaderKeyManager!
    private var configManager: ConfigManager!
    private var tempDirectory: URL!
    private var receivedActions: [KeyAction]!
    private var receivedStates: [LeaderState]!

    override func setUp() async throws {
        try await super.setUp()

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
        sut.onAction = { [weak self] action in
            self?.receivedActions.append(action)
        }
        receivedStates = []
        sut.onStateChanged = { [weak self] state in
            self?.receivedStates.append(state)
        }
    }

    override func tearDown() async throws {
        sut = nil
        configManager = nil
        receivedActions = nil
        receivedStates = nil

        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil

        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Simulates a keyDown event through the state machine.
    /// Returns true if the event was consumed.
    @discardableResult
    private func simulateKeyDown(_ keyCode: UInt16, option: Bool = false, shift: Bool = false) -> Bool {
        var rawFlags: UInt64 = 0
        if option { rawFlags |= KeyMapping.optionFlag }
        if shift { rawFlags |= UInt64(CGEventFlags.maskShift.rawValue) }
        let flags = CGEventFlags(rawValue: rawFlags)
        return sut.handleKeyEvent(keyCode: keyCode, flags: flags, eventType: .keyDown)
    }

    private func activateLeader() {
        simulateKeyDown(KeyMapping.space, option: true)
    }

    // MARK: - State Machine: Idle → Leader

    func testStartsInIdleState() {
        XCTAssertEqual(sut.state, .idle)
    }

    func testOptionSpaceActivatesLeader() {
        let consumed = simulateKeyDown(KeyMapping.space, option: true)

        XCTAssertTrue(consumed)
        XCTAssertEqual(sut.state, .leaderActive)
    }

    func testSpaceWithoutOptionPassesThrough() {
        let consumed = simulateKeyDown(KeyMapping.space)

        XCTAssertFalse(consumed)
        XCTAssertEqual(sut.state, .idle)
    }

    func testRegularKeysPassThroughInIdle() {
        let consumed = simulateKeyDown(KeyMapping.keyH)

        XCTAssertFalse(consumed)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - State Machine: Leader → Idle

    func testOptionSpaceAgainExitsLeader() {
        activateLeader()
        XCTAssertEqual(sut.state, .leaderActive)

        let consumed = simulateKeyDown(KeyMapping.space, option: true)

        XCTAssertTrue(consumed)
        XCTAssertEqual(sut.state, .idle)
    }

    func testEscapeExitsLeader() {
        activateLeader()

        let consumed = simulateKeyDown(KeyMapping.escape)

        XCTAssertTrue(consumed)
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(receivedActions, [.exitLeader])
    }

    // MARK: - Key Mapping: Layout Switch

    func testKey1SwitchesToMonocle() {
        activateLeader()

        simulateKeyDown(KeyMapping.key1)

        XCTAssertEqual(receivedActions, [.switchLayout(.monocle)])
        XCTAssertEqual(sut.state, .idle, "Layout switch should exit leader")
    }

    func testKey2SwitchesToSplitHalves() {
        activateLeader()

        simulateKeyDown(KeyMapping.key2)

        XCTAssertEqual(receivedActions, [.switchLayout(.splitHalves)])
        XCTAssertEqual(sut.state, .idle, "Layout switch should exit leader")
    }

    // MARK: - Key Mapping: Move Window

    func testHMovesWindowLeft() {
        activateLeader()

        simulateKeyDown(KeyMapping.keyH)

        XCTAssertEqual(receivedActions, [.moveWindow(.left)])
        XCTAssertEqual(sut.state, .leaderActive, "Move should stay in leader")
    }

    func testLMovesWindowRight() {
        activateLeader()

        simulateKeyDown(KeyMapping.keyL)

        XCTAssertEqual(receivedActions, [.moveWindow(.right)])
        XCTAssertEqual(sut.state, .leaderActive, "Move should stay in leader")
    }

    // MARK: - Key Mapping: Focus Container

    func testShiftHFocusesLeft() {
        activateLeader()

        simulateKeyDown(KeyMapping.keyH, shift: true)

        XCTAssertEqual(receivedActions, [.focusContainer(.left)])
        XCTAssertEqual(sut.state, .leaderActive, "Focus should stay in leader")
    }

    func testShiftLFocusesRight() {
        activateLeader()

        simulateKeyDown(KeyMapping.keyL, shift: true)

        XCTAssertEqual(receivedActions, [.focusContainer(.right)])
        XCTAssertEqual(sut.state, .leaderActive, "Focus should stay in leader")
    }

    // MARK: - Key Mapping: Cycle Window

    func testShiftCommaCyclesPrevious() {
        activateLeader()

        simulateKeyDown(KeyMapping.comma, shift: true)

        XCTAssertEqual(receivedActions, [.cycleWindow(.previous)])
        XCTAssertEqual(sut.state, .leaderActive, "Cycle should stay in leader")
    }

    func testShiftPeriodCyclesNext() {
        activateLeader()

        simulateKeyDown(KeyMapping.period, shift: true)

        XCTAssertEqual(receivedActions, [.cycleWindow(.next)])
        XCTAssertEqual(sut.state, .leaderActive, "Cycle should stay in leader")
    }

    // MARK: - Unrecognized Keys

    func testUnrecognizedKeyConsumedButStaysInLeader() {
        activateLeader()

        // 'z' key (keyCode 6) is not mapped
        let consumed = simulateKeyDown(6)

        XCTAssertTrue(consumed, "Should consume unknown key in leader mode")
        XCTAssertEqual(sut.state, .leaderActive, "Should stay in leader")
        XCTAssertTrue(receivedActions.isEmpty, "Should not dispatch any action")
    }

    // MARK: - Multi-Action Sequences

    func testMultipleActionsStayInLeader() {
        activateLeader()

        simulateKeyDown(KeyMapping.keyH)       // moveWindow left
        simulateKeyDown(KeyMapping.keyL)       // moveWindow right
        simulateKeyDown(KeyMapping.keyH, shift: true)  // focusContainer left

        XCTAssertEqual(receivedActions.count, 3)
        XCTAssertEqual(receivedActions[0], .moveWindow(.left))
        XCTAssertEqual(receivedActions[1], .moveWindow(.right))
        XCTAssertEqual(receivedActions[2], .focusContainer(.left))
        XCTAssertEqual(sut.state, .leaderActive)
    }

    func testLayoutSwitchExitsThenKeysPassThrough() {
        activateLeader()

        simulateKeyDown(KeyMapping.key1)  // switchLayout → exits leader
        XCTAssertEqual(sut.state, .idle)

        let consumed = simulateKeyDown(KeyMapping.keyH)  // should pass through
        XCTAssertFalse(consumed)
        XCTAssertEqual(receivedActions.count, 1)  // only the layout switch
    }

    // MARK: - Timeout

    func testTimeoutExitsLeaderMode() async {
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
        var flags = CGEventFlags(rawValue: KeyMapping.optionFlag)
        _ = manager.handleKeyEvent(keyCode: KeyMapping.space, flags: flags, eventType: .keyDown)
        XCTAssertEqual(manager.state, .leaderActive)

        // Wait for timeout
        try? await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertEqual(manager.state, .idle, "Leader should auto-exit after timeout")

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testTimeoutResetsOnKeypress() async {
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
        XCTAssertEqual(manager.state, .leaderActive)

        // Wait 150ms (75% of timeout), then press a key to reset
        try? await Task.sleep(nanoseconds: 150_000_000)
        let noFlags = CGEventFlags(rawValue: 0)
        _ = manager.handleKeyEvent(keyCode: KeyMapping.keyH, flags: noFlags, eventType: .keyDown)
        XCTAssertEqual(manager.state, .leaderActive)

        // Wait another 150ms — should still be active because timeout was reset
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(manager.state, .leaderActive, "Timeout should have been reset by keypress")

        // Wait full timeout from last keypress
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(manager.state, .idle, "Should timeout after no keypresses")

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testZeroTimeoutMeansInfinite() async {
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
        XCTAssertEqual(manager.state, .leaderActive)

        // Wait 500ms — should still be active (no timeout)
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(manager.state, .leaderActive, "Zero timeout should mean infinite — no auto-exit")

        manager.exitLeaderMode()
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - onStateChanged Callback

    func testOnStateChangedFiresOnEnterAndExit() {
        activateLeader()
        XCTAssertEqual(receivedStates, [.leaderActive])

        simulateKeyDown(KeyMapping.escape)
        XCTAssertEqual(receivedStates, [.leaderActive, .idle])
    }

    func testOnStateChangedNotCalledWhenAlreadyIdle() {
        sut.exitLeaderMode()
        XCTAssertTrue(receivedStates.isEmpty)
    }

    // MARK: - KeyMapping Unit Tests

    func testKeyMappingReturnsNilForUnmappedKeys() {
        XCTAssertNil(KeyMapping.action(forKeyCode: 6, shift: false))   // z
        XCTAssertNil(KeyMapping.action(forKeyCode: 0, shift: false))   // a
        XCTAssertNil(KeyMapping.action(forKeyCode: 49, shift: false))  // space (no option in this context)
    }

    func testKeyMappingAllMappedKeys() {
        XCTAssertEqual(KeyMapping.action(forKeyCode: KeyMapping.key1, shift: false), .switchLayout(.monocle))
        XCTAssertEqual(KeyMapping.action(forKeyCode: KeyMapping.key2, shift: false), .switchLayout(.splitHalves))
        XCTAssertEqual(KeyMapping.action(forKeyCode: KeyMapping.keyH, shift: false), .moveWindow(.left))
        XCTAssertEqual(KeyMapping.action(forKeyCode: KeyMapping.keyL, shift: false), .moveWindow(.right))
        XCTAssertEqual(KeyMapping.action(forKeyCode: KeyMapping.keyH, shift: true), .focusContainer(.left))
        XCTAssertEqual(KeyMapping.action(forKeyCode: KeyMapping.keyL, shift: true), .focusContainer(.right))
        XCTAssertEqual(KeyMapping.action(forKeyCode: KeyMapping.comma, shift: true), .cycleWindow(.previous))
        XCTAssertEqual(KeyMapping.action(forKeyCode: KeyMapping.period, shift: true), .cycleWindow(.next))
        XCTAssertEqual(KeyMapping.action(forKeyCode: KeyMapping.escape, shift: false), .exitLeader)
    }

    // MARK: - KeyAction.staysInLeader

    func testStaysInLeaderProperty() {
        XCTAssertFalse(KeyAction.switchLayout(.monocle).staysInLeader)
        XCTAssertFalse(KeyAction.switchLayout(.splitHalves).staysInLeader)
        XCTAssertTrue(KeyAction.moveWindow(.left).staysInLeader)
        XCTAssertTrue(KeyAction.moveWindow(.right).staysInLeader)
        XCTAssertTrue(KeyAction.focusContainer(.left).staysInLeader)
        XCTAssertTrue(KeyAction.focusContainer(.right).staysInLeader)
        XCTAssertTrue(KeyAction.cycleWindow(.next).staysInLeader)
        XCTAssertTrue(KeyAction.cycleWindow(.previous).staysInLeader)
        XCTAssertFalse(KeyAction.exitLeader.staysInLeader)
    }
}
