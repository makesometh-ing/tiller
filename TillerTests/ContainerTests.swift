//
//  ContainerTests.swift
//  TillerTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Tiller

struct ContainerTests {

    private let defaultFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    private func makeContainer(
        id: UInt = 0,
        windowIDs: [UInt32] = [],
        focusedWindowID: UInt32? = nil
    ) -> Container {
        Container(
            id: ContainerID(rawValue: id),
            frame: defaultFrame,
            windowIDs: windowIDs.map { WindowID(rawValue: $0) },
            focusedWindowID: focusedWindowID.map { WindowID(rawValue: $0) }
        )
    }

    private func wid(_ raw: UInt32) -> WindowID {
        WindowID(rawValue: raw)
    }

    // MARK: - ContainerID Tests

    @Test func containerIDEquality() {
        #expect(ContainerID(rawValue: 1) == ContainerID(rawValue: 1))
        #expect(ContainerID(rawValue: 1) != ContainerID(rawValue: 2))
    }

    @Test func containerIDHashable() {
        var dict: [ContainerID: String] = [:]
        dict[ContainerID(rawValue: 0)] = "first"
        dict[ContainerID(rawValue: 1)] = "second"
        #expect(dict[ContainerID(rawValue: 0)] == "first")
        #expect(dict[ContainerID(rawValue: 1)] == "second")
    }

    // MARK: - LayoutID Tests

    @Test func layoutIDEquality() {
        #expect(LayoutID.monocle == LayoutID.monocle)
        #expect(LayoutID.monocle != LayoutID.splitHalves)
    }

    @Test func layoutIDCodableRoundTrip() throws {
        let original = LayoutID.splitHalves
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LayoutID.self, from: data)
        #expect(original == decoded)
    }

    @Test func layoutIDCaseIterable() {
        #expect(LayoutID.allCases == [.monocle, .splitHalves])
    }

    // MARK: - Container Initialization

    @Test func emptyContainerInit() {
        let container = makeContainer()
        #expect(container.windowIDs.isEmpty)
        #expect(container.focusedWindowID == nil)
    }

    @Test func containerInitWithWindows() {
        let container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        #expect(container.windowIDs == [wid(1), wid(2), wid(3)])
        #expect(container.focusedWindowID == wid(2))
    }

    // MARK: - addWindow

    @Test func addWindowToEmptyContainerSetsFocus() {
        var container = makeContainer()
        container.addWindow(wid(1))
        #expect(container.windowIDs == [wid(1)])
        #expect(container.focusedWindowID == wid(1))
    }

    @Test func addWindowToNonEmptyDoesNotChangeFocus() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        container.addWindow(wid(2))
        #expect(container.windowIDs == [wid(1), wid(2)])
        #expect(container.focusedWindowID == wid(1))
    }

    @Test func addDuplicateWindowIsNoOp() {
        var container = makeContainer(windowIDs: [1, 2], focusedWindowID: 1)
        container.addWindow(wid(1))
        #expect(container.windowIDs == [wid(1), wid(2)])
    }

    // MARK: - removeWindow

    @Test func removeOnlyWindowClearsFocus() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        container.removeWindow(wid(1))
        #expect(container.windowIDs.isEmpty)
        #expect(container.focusedWindowID == nil)
    }

    @Test func removeFocusedWindowAdvancesFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 1)
        container.removeWindow(wid(1))
        #expect(container.windowIDs == [wid(2), wid(3)])
        #expect(container.focusedWindowID == wid(2))
    }

    @Test func removeFocusedLastWindowWrapsToFirst() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 3)
        container.removeWindow(wid(3))
        #expect(container.windowIDs == [wid(1), wid(2)])
        #expect(container.focusedWindowID == wid(1))
    }

    @Test func removeNonFocusedWindowPreservesFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        container.removeWindow(wid(1))
        #expect(container.windowIDs == [wid(2), wid(3)])
        #expect(container.focusedWindowID == wid(2))
    }

    @Test func removeNonExistentWindowIsNoOp() {
        var container = makeContainer(windowIDs: [1, 2], focusedWindowID: 1)
        container.removeWindow(wid(99))
        #expect(container.windowIDs == [wid(1), wid(2)])
        #expect(container.focusedWindowID == wid(1))
    }

    @Test func removeWindowFromMiddlePreservesOrder() {
        var container = makeContainer(windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        container.removeWindow(wid(3))
        #expect(container.windowIDs == [wid(1), wid(2), wid(4)])
    }

    // MARK: - cycleNext

    @Test func cycleNextAdvancesFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 1)
        container.cycleNext()
        #expect(container.focusedWindowID == wid(2))
    }

    @Test func cycleNextWrapsAround() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 3)
        container.cycleNext()
        #expect(container.focusedWindowID == wid(1))
    }

    @Test func cycleNextSingleWindowNoOp() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        container.cycleNext()
        #expect(container.focusedWindowID == wid(1))
    }

    @Test func cycleNextEmptyContainerNoOp() {
        var container = makeContainer()
        container.cycleNext()
        #expect(container.focusedWindowID == nil)
    }

    // MARK: - cyclePrevious

    @Test func cyclePreviousDecrementsFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        container.cyclePrevious()
        #expect(container.focusedWindowID == wid(1))
    }

    @Test func cyclePreviousWrapsAround() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 1)
        container.cyclePrevious()
        #expect(container.focusedWindowID == wid(3))
    }

    @Test func cyclePreviousSingleWindowNoOp() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        container.cyclePrevious()
        #expect(container.focusedWindowID == wid(1))
    }

    @Test func cyclePreviousEmptyContainerNoOp() {
        var container = makeContainer()
        container.cyclePrevious()
        #expect(container.focusedWindowID == nil)
    }

    // MARK: - moveFocusedWindow

    @Test func moveFocusedWindowReturnsWindowID() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        let moved = container.moveFocusedWindow()
        #expect(moved == wid(2))
    }

    @Test func moveFocusedWindowRemovesFromRing() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        _ = container.moveFocusedWindow()
        #expect(container.windowIDs == [wid(1), wid(3)])
    }

    @Test func moveFocusedWindowAdvancesFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        _ = container.moveFocusedWindow()
        #expect(container.focusedWindowID == wid(3))
    }

    @Test func moveFocusedWindowFromEmptyReturnsNil() {
        var container = makeContainer()
        let moved = container.moveFocusedWindow()
        #expect(moved == nil)
    }

    @Test func moveFocusedWindowSingleWindowEmptiesContainer() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        let moved = container.moveFocusedWindow()
        #expect(moved == wid(1))
        #expect(container.windowIDs.isEmpty)
        #expect(container.focusedWindowID == nil)
    }

    // MARK: - Full Cycle Tests

    @Test func fullCycleForwardReturnsToStart() {
        var container = makeContainer(windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        for _ in 0..<4 {
            container.cycleNext()
        }
        #expect(container.focusedWindowID == wid(1))
    }

    @Test func fullCycleBackwardReturnsToStart() {
        var container = makeContainer(windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        for _ in 0..<4 {
            container.cyclePrevious()
        }
        #expect(container.focusedWindowID == wid(1))
    }
}
