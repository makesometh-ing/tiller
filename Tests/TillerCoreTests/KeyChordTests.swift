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

@Test func focusActionsKeepLeaderKeyModeByDefault() {
    var s = Shortcuts.standard
    #expect(!s.exits(after: .focusNextWindow))
    #expect(!s.exits(after: .focusPreviousContainer))
    #expect(s.exits(after: .layoutFullScreen))
    s.exitAfter[.focusNextWindow] = true
    s.exitAfter[.layoutFullScreen] = false
    s.exitAfter[.turnOff] = false
    #expect(s.exits(after: .focusNextWindow))
    #expect(!s.exits(after: .layoutFullScreen))
    #expect(s.exits(after: .turnOff))
}

@Test func toggleChordAndExitAfterAfterJSON() throws {
    var s = Shortcuts.standard
    #expect(s.toggle == KeyChord(spec: "ctrl+opt+cmd+t"))
    s.exitAfter[.focusNextWindow] = true
    s.toggle = nil
    let read = try JSONDecoder().decode(Shortcuts.self, from: JSONEncoder().encode(s))
    #expect(read == s)
    #expect(read.toggle == nil)
    // Shortcuts saved before `toggle` and `exitAfter` existed.
    var saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Shortcuts.standard)) as! [String: Any]
    saved["toggle"] = nil
    saved["exitAfter"] = nil
    let old = try JSONDecoder().decode(Shortcuts.self, from: JSONSerialization.data(withJSONObject: saved))
    #expect(old.toggle == KeyChord(spec: "ctrl+opt+cmd+t"))
    #expect(old.exitAfter.isEmpty)
}

@Test func globalShortcutsAreEmptyByDefaultAndMatchOnlyTheExactChord() {
    var s = Shortcuts.standard
    #expect(s.global.isEmpty)
    s.global[.focusNextWindow] = KeyChord(spec: "hyper+y")
    #expect(s.globalAction(keyCode: 16, modifiers: .hyper) == .focusNextWindow)
    #expect(s.globalAction(keyCode: 16, modifiers: []) == nil)
    #expect(s.globalAction(keyCode: 16, modifiers: [.control, .option]) == nil)
}

@Test func aGlobalShortcutCantUseTheChordOfAnotherGlobalShortcut() {
    var s = Shortcuts.standard
    s.global[.focusNextWindow] = KeyChord(spec: "hyper+y")
    let leader = s.leader!, toggle = s.toggle!
    #expect(s.conflict(KeyChord(spec: "hyper+y")!, for: .action(.focusPreviousWindow)) == .action(.focusNextWindow))
    #expect(s.conflict(leader, for: .action(.focusPreviousWindow)) == .leader)
    #expect(s.conflict(toggle, for: .action(.focusPreviousWindow)) == .toggle)
    #expect(s.conflict(KeyChord(spec: "hyper+y")!, for: .leader) == .action(.focusNextWindow))
    #expect(s.conflict(KeyChord(spec: "hyper+y")!, for: .action(.focusNextWindow)) == nil)
    #expect(s.conflict(KeyChord(spec: "ctrl+opt+shift+u")!, for: .action(.focusPreviousWindow)) == nil)
    // A global shortcut without a modifier would take each typed key.
    #expect(s.conflict(KeyChord(spec: "u")!, for: .action(.focusPreviousWindow)) == .action(.focusPreviousWindow))
}

@Test func globalShortcutsAreSavedAndReadAgain() throws {
    var s = Shortcuts.standard
    s.global[.layoutFullScreen] = KeyChord(spec: "hyper+1")
    let read = try JSONDecoder().decode(Shortcuts.self, from: JSONEncoder().encode(s))
    #expect(read.global == [.layoutFullScreen: KeyChord(spec: "hyper+1")!])
    // Shortcuts saved before global shortcuts existed don't contain the key.
    let old = try JSONDecoder().decode(Shortcuts.self, from: Data(#"{"actions":[]}"#.utf8))
    #expect(old.global.isEmpty)
}

@Test func moveActionsUseShiftJAndShiftKAndKeepLeaderKeyMode() {
    let s = Shortcuts.standard
    #expect(s.actions[.moveWindowNextContainer] == KeyChord(spec: "shift+j"))
    #expect(s.actions[.moveWindowPreviousContainer] == KeyChord(spec: "shift+k"))
    #expect(!s.exits(after: .moveWindowNextContainer))
    #expect(!s.exits(after: .moveWindowPreviousContainer))
    #expect(s.global[.moveWindowNextContainer] == nil)
}

@Test func shiftJDoesNotRunJAndJDoesNotRunShiftJ() {
    let s = Shortcuts.standard
    #expect(s.action(keyCode: 38, modifiers: .shift) == .moveWindowNextContainer)
    #expect(s.action(keyCode: 40, modifiers: .shift) == .moveWindowPreviousContainer)
    #expect(s.action(keyCode: 38, modifiers: []) == .focusNextContainer)
    #expect(s.action(keyCode: 40, modifiers: []) == .focusPreviousContainer)
    // Hyper is still held after Hyper L. Hyper contains ⇧, but only the key without modifiers matches.
    #expect(s.action(keyCode: 38, modifiers: .hyper) == .focusNextContainer)
}

@Test func savedShortcutsGetShiftJAndShiftKWhenTheyAreNotUsed() throws {
    var old = Shortcuts.standard
    old.actions[.moveWindowNextContainer] = nil
    old.actions[.moveWindowPreviousContainer] = nil
    old.actions[.toggleFloat] = KeyChord(spec: "shift+k")
    let read = try JSONDecoder().decode(Shortcuts.self, from: JSONEncoder().encode(old))
    #expect(read.actions[.moveWindowNextContainer] == KeyChord(spec: "shift+j"))
    #expect(read.actions[.moveWindowPreviousContainer] == nil)
    #expect(read.actions[.toggleFloat] == KeyChord(spec: "shift+k"))
}
