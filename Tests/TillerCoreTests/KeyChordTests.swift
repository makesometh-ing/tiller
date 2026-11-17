import Foundation
import Testing
@testable import TillerCore

@Test func hyperSpecIsAllFourModifiers() {
    let chord = KeyChord(spec: "hyper+l")!
    #expect(chord.keyCode == 37)
    #expect(chord.modifiers == [.control, .option, .shift, .command])
    #expect(chord == KeyChord(spec: "ctrl+opt+shift+cmd+l"))
    #expect(chord.labels == ["⌃⌥⇧⌘", "L"])
    #expect(chord.spec == "hyper+l")
}

@Test func specRoundTrip() {
    for spec in ["ctrl+opt+space", "shift+cmd+4", "1", "esc", "opt+k"] {
        #expect(KeyChord(spec: spec)!.spec == spec)
    }
    #expect(KeyChord(spec: "ctrl+opt+space")!.labels == ["⌃⌥", "Space"])
    #expect(KeyChord(spec: "?") == KeyChord(keyCode: 44, modifiers: .shift))
    #expect(KeyChord(spec: "meta+l") == nil)
    #expect(KeyChord(spec: "hyper+nope") == nil)
}

@Test func hyperLeaderMatchesOnlyWithAllFourModifiers() {
    var s = Shortcuts.standard
    s.leader = KeyChord(spec: "hyper+l")
    #expect(s.isLeader(keyCode: 37, modifiers: .hyper))
    #expect(!s.isLeader(keyCode: 37, modifiers: [.control, .option, .command]))
    #expect(!s.isLeader(keyCode: 37, modifiers: []))
    // The standard leader doesn't start leader key mode after the leader is changed.
    #expect(!s.isLeader(keyCode: 49, modifiers: [.control, .option]))
}

@Test func actionKeysMatchWhileModifiersAreHeld() {
    let s = Shortcuts.standard
    #expect(s.action(keyCode: 18, modifiers: []) == .layoutFullScreen)
    // Hyper is still held after Hyper L.
    #expect(s.action(keyCode: 18, modifiers: .hyper) == .layoutFullScreen)
    #expect(s.action(keyCode: 45, modifiers: []) == nil)
}

@Test func hyperActionKeyMatchesExactly() {
    var s = Shortcuts.standard
    s.set(KeyChord(spec: "hyper+n"), for: .focusNextWindow)
    #expect(s.action(keyCode: 45, modifiers: .hyper) == .focusNextWindow)
    #expect(s.action(keyCode: 45, modifiers: []) == nil)
    #expect(s.action(keyCode: 37, modifiers: []) == nil)  // `l` isn't the key of focusNextWindow any more.
}

@Test func oneChordHasOneAction() {
    var s = Shortcuts.standard
    s.set(KeyChord(spec: "h"), for: .focusNextWindow)
    #expect(s.actions[.focusNextWindow] == KeyChord(spec: "h"))
    #expect(s.actions[.focusPreviousWindow] == nil)
    s.set(nil, for: .toggleFloat)
    #expect(s.actions[.toggleFloat] == nil)
}

@Test func shortcutsSurviveJSON() throws {
    var s = Shortcuts.standard
    s.leader = KeyChord(spec: "hyper+l")
    let data = try JSONEncoder().encode(s)
    #expect(try JSONDecoder().decode(Shortcuts.self, from: data) == s)
}

@Test func savedShortcutsGetTheStandardChordOfANewAction() throws {
    var old = Shortcuts.standard
    old.actions[.turnOff] = nil
    var saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
    saved["cleared"] = nil  // Shortcuts saved before `cleared` existed.
    let read = try JSONDecoder().decode(Shortcuts.self, from: JSONSerialization.data(withJSONObject: saved))
    #expect(read.actions[.turnOff] == KeyChord(spec: "q"))
}

@Test func clearedActionStaysClearedAfterJSON() throws {
    var s = Shortcuts.standard
    s.set(nil, for: .turnOff)
    s.set(KeyChord(spec: "r"), for: .toggleFloat)  // `r` is taken from raiseFloating.
    let read = try JSONDecoder().decode(Shortcuts.self, from: JSONEncoder().encode(s))
    #expect(read.actions[.turnOff] == nil)
    #expect(read.actions[.raiseFloating] == nil)
    #expect(read == s)
}

@Test func newActionDoesNotTakeAChordInUse() throws {
    var old = Shortcuts.standard
    old.actions[.turnOff] = nil
    old.actions[.toggleFloat] = KeyChord(spec: "q")
    let read = try JSONDecoder().decode(Shortcuts.self, from: JSONEncoder().encode(old))
    #expect(read.actions[.turnOff] == nil)
    #expect(read.actions[.toggleFloat] == KeyChord(spec: "q"))
}
