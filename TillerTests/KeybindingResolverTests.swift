//
//  KeybindingResolverTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

final class KeybindingResolverTests: XCTestCase {

    // MARK: - Default Config

    func testDefaultConfigResolvesAllBindings() {
        let resolver = KeybindingResolver(config: .default)

        let cases: [(UInt16, Bool, KeyAction, Bool)] = [
            (KeyMapping.key1, false, .switchLayout(.monocle), false),
            (KeyMapping.key2, false, .switchLayout(.splitHalves), false),
            (KeyMapping.keyH, false, .moveWindow(.left), true),
            (KeyMapping.keyL, false, .moveWindow(.right), true),
            (KeyMapping.keyH, true, .focusContainer(.left), true),
            (KeyMapping.keyL, true, .focusContainer(.right), true),
            (KeyMapping.comma, true, .cycleWindow(.previous), true),
            (KeyMapping.period, true, .cycleWindow(.next), true),
            (KeyMapping.escape, false, .exitLeader, false),
        ]

        for (keyCode, shift, expectedAction, expectedStays) in cases {
            let resolved = resolver.resolve(keyCode: keyCode, shift: shift)
            XCTAssertNotNil(resolved, "Expected binding for keyCode \(keyCode), shift=\(shift)")
            XCTAssertEqual(resolved?.action, expectedAction)
            XCTAssertEqual(resolved?.staysInLeader, expectedStays)
        }
    }

    func testUnmappedKeyReturnsNil() {
        let resolver = KeybindingResolver(config: .default)

        XCTAssertNil(resolver.resolve(keyCode: 6, shift: false))  // z
        XCTAssertNil(resolver.resolve(keyCode: 0, shift: false))  // a
    }

    // MARK: - Leader Trigger

    func testDefaultLeaderTrigger() {
        let resolver = KeybindingResolver(config: .default)

        XCTAssertEqual(resolver.leaderKeyCode, KeyMapping.space)

        let optionFlags: UInt64 = KeyMapping.optionFlag
        XCTAssertTrue(resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: optionFlags))
        XCTAssertFalse(resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: 0))
        XCTAssertFalse(resolver.isLeaderTrigger(keyCode: KeyMapping.keyH, flags: optionFlags))
    }

    func testCustomLeaderTrigger() {
        var config = KeybindingsConfig.default
        config.leaderTrigger = ["ctrl", "space"]

        let resolver = KeybindingResolver(config: config)

        let ctrlFlags: UInt64 = 0x40000  // CGEventFlags.maskControl
        XCTAssertTrue(resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: ctrlFlags))
        XCTAssertFalse(resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: KeyMapping.optionFlag))
    }

    // MARK: - Custom Remapped Keys

    func testRemappedKeysResolveCorrectly() {
        var config = KeybindingsConfig.default
        // Swap h and l
        config.actions["moveWindow.left"] = ActionBinding(keys: ["l"], leaderLayer: true, subLayer: nil, staysInLeader: true)
        config.actions["moveWindow.right"] = ActionBinding(keys: ["h"], leaderLayer: true, subLayer: nil, staysInLeader: true)

        let resolver = KeybindingResolver(config: config)

        let leftResolved = resolver.resolve(keyCode: KeyMapping.keyL, shift: false)
        XCTAssertEqual(leftResolved?.action, .moveWindow(.left))

        let rightResolved = resolver.resolve(keyCode: KeyMapping.keyH, shift: false)
        XCTAssertEqual(rightResolved?.action, .moveWindow(.right))
    }

    // MARK: - staysInLeader from config

    func testStaysInLeaderFromConfig() {
        var config = KeybindingsConfig.default
        // Override: make moveWindow.left NOT stay in leader (opposite of default)
        config.actions["moveWindow.left"] = ActionBinding(keys: ["h"], leaderLayer: true, subLayer: nil, staysInLeader: false)

        let resolver = KeybindingResolver(config: config)

        let resolved = resolver.resolve(keyCode: KeyMapping.keyH, shift: false)
        XCTAssertEqual(resolved?.action, .moveWindow(.left))
        XCTAssertFalse(resolved!.staysInLeader)
    }

    // MARK: - Key Code Mapping

    func testKeyCodeMapping() {
        XCTAssertEqual(KeybindingResolver.keyCode(for: "space"), 49)
        XCTAssertEqual(KeybindingResolver.keyCode(for: "escape"), 53)
        XCTAssertEqual(KeybindingResolver.keyCode(for: "h"), 4)
        XCTAssertEqual(KeybindingResolver.keyCode(for: "l"), 37)
        XCTAssertEqual(KeybindingResolver.keyCode(for: "1"), 18)
        XCTAssertEqual(KeybindingResolver.keyCode(for: "2"), 19)
        XCTAssertEqual(KeybindingResolver.keyCode(for: ","), 43)
        XCTAssertEqual(KeybindingResolver.keyCode(for: "."), 47)
        XCTAssertEqual(KeybindingResolver.keyCode(for: "unknown"), UInt16.max)
    }

    // MARK: - Action ID Parsing

    func testParseActionID() {
        XCTAssertEqual(KeybindingResolver.parseActionID("switchLayout.monocle"), .switchLayout(.monocle))
        XCTAssertEqual(KeybindingResolver.parseActionID("switchLayout.splitHalves"), .switchLayout(.splitHalves))
        XCTAssertEqual(KeybindingResolver.parseActionID("moveWindow.left"), .moveWindow(.left))
        XCTAssertEqual(KeybindingResolver.parseActionID("moveWindow.right"), .moveWindow(.right))
        XCTAssertEqual(KeybindingResolver.parseActionID("focusContainer.left"), .focusContainer(.left))
        XCTAssertEqual(KeybindingResolver.parseActionID("focusContainer.right"), .focusContainer(.right))
        XCTAssertEqual(KeybindingResolver.parseActionID("cycleWindow.previous"), .cycleWindow(.previous))
        XCTAssertEqual(KeybindingResolver.parseActionID("cycleWindow.next"), .cycleWindow(.next))
        XCTAssertEqual(KeybindingResolver.parseActionID("exitLeader"), .exitLeader)
        XCTAssertNil(KeybindingResolver.parseActionID("unknownAction"))
    }

    // MARK: - Non-Leader Bindings Excluded

    func testNonLeaderBindingsNotInLeaderDispatch() {
        var config = KeybindingsConfig.default
        config.actions["moveWindow.left"] = ActionBinding(keys: ["h"], leaderLayer: false, subLayer: nil, staysInLeader: false)

        let resolver = KeybindingResolver(config: config)

        // Should not resolve in leader layer
        XCTAssertNil(resolver.resolve(keyCode: KeyMapping.keyH, shift: false))
    }
}
