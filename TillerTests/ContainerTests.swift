//
//  ContainerTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

final class ContainerTests: XCTestCase {

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

    func testContainerIDEquality() {
        XCTAssertEqual(ContainerID(rawValue: 1), ContainerID(rawValue: 1))
        XCTAssertNotEqual(ContainerID(rawValue: 1), ContainerID(rawValue: 2))
    }

    func testContainerIDHashable() {
        var dict: [ContainerID: String] = [:]
        dict[ContainerID(rawValue: 0)] = "first"
        dict[ContainerID(rawValue: 1)] = "second"
        XCTAssertEqual(dict[ContainerID(rawValue: 0)], "first")
        XCTAssertEqual(dict[ContainerID(rawValue: 1)], "second")
    }

    // MARK: - LayoutID Tests

    func testLayoutIDEquality() {
        XCTAssertEqual(LayoutID.monocle, LayoutID.monocle)
        XCTAssertNotEqual(LayoutID.monocle, LayoutID.splitHalves)
    }

    func testLayoutIDCodableRoundTrip() throws {
        let original = LayoutID.splitHalves
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LayoutID.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testLayoutIDCaseIterable() {
        XCTAssertEqual(LayoutID.allCases, [.monocle, .splitHalves])
    }

    // MARK: - Container Initialization

    func testEmptyContainerInit() {
        let container = makeContainer()
        XCTAssertTrue(container.windowIDs.isEmpty)
        XCTAssertNil(container.focusedWindowID)
    }

    func testContainerInitWithWindows() {
        let container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        XCTAssertEqual(container.windowIDs, [wid(1), wid(2), wid(3)])
        XCTAssertEqual(container.focusedWindowID, wid(2))
    }

    // MARK: - addWindow

    func testAddWindowToEmptyContainerSetsFocus() {
        var container = makeContainer()
        container.addWindow(wid(1))
        XCTAssertEqual(container.windowIDs, [wid(1)])
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }

    func testAddWindowToNonEmptyDoesNotChangeFocus() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        container.addWindow(wid(2))
        XCTAssertEqual(container.windowIDs, [wid(1), wid(2)])
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }

    func testAddDuplicateWindowIsNoOp() {
        var container = makeContainer(windowIDs: [1, 2], focusedWindowID: 1)
        container.addWindow(wid(1))
        XCTAssertEqual(container.windowIDs, [wid(1), wid(2)])
    }

    // MARK: - removeWindow

    func testRemoveOnlyWindowClearsFocus() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        container.removeWindow(wid(1))
        XCTAssertTrue(container.windowIDs.isEmpty)
        XCTAssertNil(container.focusedWindowID)
    }

    func testRemoveFocusedWindowAdvancesFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 1)
        container.removeWindow(wid(1))
        XCTAssertEqual(container.windowIDs, [wid(2), wid(3)])
        XCTAssertEqual(container.focusedWindowID, wid(2))
    }

    func testRemoveFocusedLastWindowWrapsToFirst() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 3)
        container.removeWindow(wid(3))
        XCTAssertEqual(container.windowIDs, [wid(1), wid(2)])
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }

    func testRemoveNonFocusedWindowPreservesFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        container.removeWindow(wid(1))
        XCTAssertEqual(container.windowIDs, [wid(2), wid(3)])
        XCTAssertEqual(container.focusedWindowID, wid(2))
    }

    func testRemoveNonExistentWindowIsNoOp() {
        var container = makeContainer(windowIDs: [1, 2], focusedWindowID: 1)
        container.removeWindow(wid(99))
        XCTAssertEqual(container.windowIDs, [wid(1), wid(2)])
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }

    func testRemoveWindowFromMiddlePreservesOrder() {
        var container = makeContainer(windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        container.removeWindow(wid(3))
        XCTAssertEqual(container.windowIDs, [wid(1), wid(2), wid(4)])
    }

    // MARK: - cycleNext

    func testCycleNextAdvancesFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 1)
        container.cycleNext()
        XCTAssertEqual(container.focusedWindowID, wid(2))
    }

    func testCycleNextWrapsAround() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 3)
        container.cycleNext()
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }

    func testCycleNextSingleWindowNoOp() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        container.cycleNext()
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }

    func testCycleNextEmptyContainerNoOp() {
        var container = makeContainer()
        container.cycleNext()
        XCTAssertNil(container.focusedWindowID)
    }

    // MARK: - cyclePrevious

    func testCyclePreviousDecrementsFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        container.cyclePrevious()
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }

    func testCyclePreviousWrapsAround() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 1)
        container.cyclePrevious()
        XCTAssertEqual(container.focusedWindowID, wid(3))
    }

    func testCyclePreviousSingleWindowNoOp() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        container.cyclePrevious()
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }

    func testCyclePreviousEmptyContainerNoOp() {
        var container = makeContainer()
        container.cyclePrevious()
        XCTAssertNil(container.focusedWindowID)
    }

    // MARK: - moveFocusedWindow

    func testMoveFocusedWindowReturnsWindowID() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        let moved = container.moveFocusedWindow()
        XCTAssertEqual(moved, wid(2))
    }

    func testMoveFocusedWindowRemovesFromRing() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        _ = container.moveFocusedWindow()
        XCTAssertEqual(container.windowIDs, [wid(1), wid(3)])
    }

    func testMoveFocusedWindowAdvancesFocus() {
        var container = makeContainer(windowIDs: [1, 2, 3], focusedWindowID: 2)
        _ = container.moveFocusedWindow()
        XCTAssertEqual(container.focusedWindowID, wid(3))
    }

    func testMoveFocusedWindowFromEmptyReturnsNil() {
        var container = makeContainer()
        let moved = container.moveFocusedWindow()
        XCTAssertNil(moved)
    }

    func testMoveFocusedWindowSingleWindowEmptiesContainer() {
        var container = makeContainer(windowIDs: [1], focusedWindowID: 1)
        let moved = container.moveFocusedWindow()
        XCTAssertEqual(moved, wid(1))
        XCTAssertTrue(container.windowIDs.isEmpty)
        XCTAssertNil(container.focusedWindowID)
    }

    // MARK: - Full Cycle Tests

    func testFullCycleForwardReturnsToStart() {
        var container = makeContainer(windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        for _ in 0..<4 {
            container.cycleNext()
        }
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }

    func testFullCycleBackwardReturnsToStart() {
        var container = makeContainer(windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        for _ in 0..<4 {
            container.cyclePrevious()
        }
        XCTAssertEqual(container.focusedWindowID, wid(1))
    }
}
