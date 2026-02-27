//
//  KeybindingResolverTests.swift
//  TillerTests
//

import Testing
@testable import Tiller

struct KeybindingResolverTests {

    // MARK: - Default Config

    @Test func defaultConfigResolvesAllBindings() {
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
            #expect(resolved != nil, "Expected binding for keyCode \(keyCode), shift=\(shift)")
            #expect(resolved?.action == expectedAction)
            #expect(resolved?.staysInLeader == expectedStays)
        }
    }

    @Test func unmappedKeyReturnsNil() {
        let resolver = KeybindingResolver(config: .default)

        #expect(resolver.resolve(keyCode: 6, shift: false) == nil)  // z
        #expect(resolver.resolve(keyCode: 0, shift: false) == nil)  // a
    }

    // MARK: - Leader Trigger

    @Test func defaultLeaderTrigger() {
        let resolver = KeybindingResolver(config: .default)

        #expect(resolver.leaderKeyCode == KeyMapping.space)

        let optionFlags: UInt64 = KeyMapping.optionFlag
        #expect(resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: optionFlags))
        #expect(!resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: 0))
        #expect(!resolver.isLeaderTrigger(keyCode: KeyMapping.keyH, flags: optionFlags))
    }

    @Test func customLeaderTrigger() {
        var config = KeybindingsConfig.default
        config.leaderTrigger = ["ctrl", "space"]

        let resolver = KeybindingResolver(config: config)

        let ctrlFlags: UInt64 = 0x40000  // CGEventFlags.maskControl
        #expect(resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: ctrlFlags))
        #expect(!resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: KeyMapping.optionFlag))
    }

    // MARK: - Custom Remapped Keys

    @Test func remappedKeysResolveCorrectly() {
        var config = KeybindingsConfig.default
        // Swap h and l
        config.actions["moveWindow.left"] = ActionBinding(keys: ["l"], leaderLayer: true, subLayer: nil, staysInLeader: true)
        config.actions["moveWindow.right"] = ActionBinding(keys: ["h"], leaderLayer: true, subLayer: nil, staysInLeader: true)

        let resolver = KeybindingResolver(config: config)

        let leftResolved = resolver.resolve(keyCode: KeyMapping.keyL, shift: false)
        #expect(leftResolved?.action == .moveWindow(.left))

        let rightResolved = resolver.resolve(keyCode: KeyMapping.keyH, shift: false)
        #expect(rightResolved?.action == .moveWindow(.right))
    }

    // MARK: - staysInLeader from config

    @Test func staysInLeaderFromConfig() {
        var config = KeybindingsConfig.default
        // Override: make moveWindow.left NOT stay in leader (opposite of default)
        config.actions["moveWindow.left"] = ActionBinding(keys: ["h"], leaderLayer: true, subLayer: nil, staysInLeader: false)

        let resolver = KeybindingResolver(config: config)

        let resolved = resolver.resolve(keyCode: KeyMapping.keyH, shift: false)
        #expect(resolved?.action == .moveWindow(.left))
        #expect(!resolved!.staysInLeader)
    }

    // MARK: - Key Code Mapping

    @Test func keyCodeMapping() {
        #expect(KeybindingResolver.keyCode(for: "space") == 49)
        #expect(KeybindingResolver.keyCode(for: "escape") == 53)
        #expect(KeybindingResolver.keyCode(for: "h") == 4)
        #expect(KeybindingResolver.keyCode(for: "l") == 37)
        #expect(KeybindingResolver.keyCode(for: "1") == 18)
        #expect(KeybindingResolver.keyCode(for: "2") == 19)
        #expect(KeybindingResolver.keyCode(for: ",") == 43)
        #expect(KeybindingResolver.keyCode(for: ".") == 47)
        #expect(KeybindingResolver.keyCode(for: "unknown") == UInt16.max)
    }

    // MARK: - Action ID Parsing

    @Test func parseActionID() {
        #expect(KeybindingResolver.parseActionID("switchLayout.monocle") == .switchLayout(.monocle))
        #expect(KeybindingResolver.parseActionID("switchLayout.splitHalves") == .switchLayout(.splitHalves))
        #expect(KeybindingResolver.parseActionID("moveWindow.left") == .moveWindow(.left))
        #expect(KeybindingResolver.parseActionID("moveWindow.right") == .moveWindow(.right))
        #expect(KeybindingResolver.parseActionID("focusContainer.left") == .focusContainer(.left))
        #expect(KeybindingResolver.parseActionID("focusContainer.right") == .focusContainer(.right))
        #expect(KeybindingResolver.parseActionID("cycleWindow.previous") == .cycleWindow(.previous))
        #expect(KeybindingResolver.parseActionID("cycleWindow.next") == .cycleWindow(.next))
        #expect(KeybindingResolver.parseActionID("exitLeader") == .exitLeader)
        #expect(KeybindingResolver.parseActionID("unknownAction") == nil)
    }

    // MARK: - Non-Leader Bindings Excluded

    @Test func nonLeaderBindingsNotInLeaderDispatch() {
        var config = KeybindingsConfig.default
        config.actions["moveWindow.left"] = ActionBinding(keys: ["h"], leaderLayer: false, subLayer: nil, staysInLeader: false)

        let resolver = KeybindingResolver(config: config)

        // Should not resolve in leader layer
        #expect(resolver.resolve(keyCode: KeyMapping.keyH, shift: false) == nil)
    }

    // MARK: - Hyper Key (All 4 Modifiers)

    @Test func hyperKeyLeaderTrigger() {
        var config = KeybindingsConfig.default
        config.leaderTrigger = ["cmd", "ctrl", "shift", "option", "backspace"]

        let resolver = KeybindingResolver(config: config)

        // All 4 modifiers: cmd(0x100000) + ctrl(0x40000) + shift(0x20000) + option(0x80000)
        let hyperFlags: UInt64 = 0x100000 | 0x40000 | 0x20000 | 0x80000
        let backspaceKeyCode: UInt16 = 51

        #expect(resolver.isLeaderTrigger(keyCode: backspaceKeyCode, flags: hyperFlags))
    }

    @Test func hyperKeyTriggerWithExtraDeviceBits() {
        // HyperKey apps may set device-dependent bits alongside modifier flags
        var config = KeybindingsConfig.default
        config.leaderTrigger = ["cmd", "ctrl", "shift", "option", "space"]

        let resolver = KeybindingResolver(config: config)

        // Hyper flags plus simulated device-dependent bits (lower 16 bits)
        let hyperFlags: UInt64 = 0x100000 | 0x40000 | 0x20000 | 0x80000
        let extraDeviceBits: UInt64 = 0x10F // caps lock + device key masks
        let flagsWithExtras = hyperFlags | extraDeviceBits

        #expect(resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: flagsWithExtras),
                "Hyper key trigger should work even with extra device-dependent flag bits")
    }

    @Test func hyperKeyDoesNotMatchSubset() {
        // Only 3 of 4 modifiers should NOT match hyper key trigger
        var config = KeybindingsConfig.default
        config.leaderTrigger = ["cmd", "ctrl", "shift", "option", "space"]

        let resolver = KeybindingResolver(config: config)

        // Missing option
        let threeModFlags: UInt64 = 0x100000 | 0x40000 | 0x20000
        #expect(!resolver.isLeaderTrigger(keyCode: KeyMapping.space, flags: threeModFlags))
    }

    // MARK: - Forward Delete Key

    @Test func forwardDeleteKeyCode() {
        #expect(KeybindingResolver.keyCode(for: "forward_delete") == 117)
        #expect(KeybindingResolver.keyCode(for: "forwarddelete") == 117)
    }

    @Test func deleteAndBackspaceKeyCode() {
        #expect(KeybindingResolver.keyCode(for: "delete") == 51)
        #expect(KeybindingResolver.keyCode(for: "backspace") == 51)
    }
}
