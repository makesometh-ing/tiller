//
//  MonitorTilingStateTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

final class MonitorTilingStateTests: XCTestCase {

    private let monitorID = MonitorID(rawValue: 1)
    private let defaultFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    private func wid(_ raw: UInt32) -> WindowID {
        WindowID(rawValue: raw)
    }

    private func makeState(
        activeLayout: LayoutID = .monocle,
        containers: [Container] = []
    ) -> MonitorTilingState {
        MonitorTilingState(
            monitorID: monitorID,
            activeLayout: activeLayout,
            containers: containers
        )
    }

    private func makeContainer(
        id: UInt = 0,
        frame: CGRect? = nil,
        windowIDs: [UInt32] = [],
        focusedWindowID: UInt32? = nil
    ) -> Container {
        Container(
            id: ContainerID(rawValue: id),
            frame: frame ?? defaultFrame,
            windowIDs: windowIDs.map { WindowID(rawValue: $0) },
            focusedWindowID: focusedWindowID.map { WindowID(rawValue: $0) }
        )
    }

    // MARK: - Initialization

    func testDefaultInitialization() {
        let state = makeState()
        XCTAssertEqual(state.monitorID, monitorID)
        XCTAssertEqual(state.activeLayout, .monocle)
        XCTAssertTrue(state.containers.isEmpty)
        XCTAssertNil(state.focusedContainerID)
    }

    // MARK: - assignWindow

    func testAssignWindowCreatesContainerIfEmpty() {
        var state = makeState()
        state.assignWindow(wid(1))

        XCTAssertEqual(state.containers.count, 1)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1)])
        XCTAssertEqual(state.containers[0].focusedWindowID, wid(1))
        XCTAssertEqual(state.focusedContainerID, state.containers[0].id)
    }

    func testAssignWindowToFocusedContainer() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = makeState(containers: [container])
        state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        state.assignWindow(wid(2))

        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(2)])
    }

    func testAssignWindowToSpecificContainer() {
        let left = makeContainer(id: 0)
        let right = makeContainer(id: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .splitHalves,
            containers: [left, right],
            focusedContainerID: left.id
        )

        state.assignWindow(wid(1), toContainer: right.id)

        XCTAssertTrue(state.containers[0].windowIDs.isEmpty)
        XCTAssertEqual(state.containers[1].windowIDs, [wid(1)])
    }

    func testAssignWindowFallsBackToFirstContainer() {
        let container = makeContainer(id: 0)
        var state = makeState(containers: [container])
        // focusedContainerID is nil

        state.assignWindow(wid(1))

        XCTAssertEqual(state.containers[0].windowIDs, [wid(1)])
    }

    // MARK: - removeWindow

    func testRemoveWindowFromContainer() {
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        state.removeWindow(wid(1))

        XCTAssertEqual(state.containers[0].windowIDs, [wid(2)])
    }

    func testRemoveWindowNotFoundIsNoOp() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = makeState(containers: [container])
        state.removeWindow(wid(99))

        XCTAssertEqual(state.containers[0].windowIDs, [wid(1)])
    }

    func testRemoveLastWindowLeavesEmptyContainer() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = makeState(containers: [container])
        state.removeWindow(wid(1))

        XCTAssertEqual(state.containers.count, 1)
        XCTAssertTrue(state.containers[0].windowIDs.isEmpty)
    }

    // MARK: - containerForWindow

    func testContainerForWindowFound() {
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        let state = makeState(containers: [container])
        let found = state.containerForWindow(wid(2))
        XCTAssertEqual(found?.id, container.id)
    }

    func testContainerForWindowNotFound() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let state = makeState(containers: [container])
        XCTAssertNil(state.containerForWindow(wid(99)))
    }

    func testContainerForWindowMultipleContainers() {
        let left = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [2, 3], focusedWindowID: 2)
        let state = makeState(containers: [left, right])

        XCTAssertEqual(state.containerForWindow(wid(1))?.id, left.id)
        XCTAssertEqual(state.containerForWindow(wid(3))?.id, right.id)
    }

    // MARK: - redistributeWindows

    func testRedistributeIntoSingleContainer() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3], focusedWindowID: 1)
        var state = makeState(containers: [container])
        let newFrame = CGRect(x: 8, y: 8, width: 1904, height: 1064)

        state.redistributeWindows(into: [newFrame])

        XCTAssertEqual(state.containers.count, 1)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(2), wid(3)])
        XCTAssertEqual(state.containers[0].frame, newFrame)
    }

    func testRedistributeIntoMultipleContainersRoundRobin() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        var state = makeState(containers: [container])
        let leftFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let rightFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)

        state.redistributeWindows(into: [leftFrame, rightFrame])

        XCTAssertEqual(state.containers.count, 2)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(3)])
        XCTAssertEqual(state.containers[1].windowIDs, [wid(2), wid(4)])
    }

    func testRedistributePreservesWindowOrder() {
        let left = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [3, 4], focusedWindowID: 3)
        var state = makeState(containers: [left, right])

        state.redistributeWindows(into: [defaultFrame])

        // Windows collected in container order: left first, then right
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(2), wid(3), wid(4)])
    }

    func testRedistributeEmptyStateCreatesEmptyContainers() {
        var state = makeState()
        let frame1 = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let frame2 = CGRect(x: 960, y: 0, width: 960, height: 1080)

        state.redistributeWindows(into: [frame1, frame2])

        XCTAssertEqual(state.containers.count, 2)
        XCTAssertTrue(state.containers[0].windowIDs.isEmpty)
        XCTAssertTrue(state.containers[1].windowIDs.isEmpty)
    }

    func testRedistributeGeneratesNewContainerIDs() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = makeState(containers: [container])

        state.redistributeWindows(into: [defaultFrame, defaultFrame])

        // New IDs should be generated (not reuse old id 0)
        let ids = state.containers.map(\.id)
        XCTAssertEqual(ids.count, 2)
        XCTAssertNotEqual(ids[0], ids[1])
    }

    func testRedistributeSetsFocusedContainerToFirst() {
        var state = makeState()
        state.redistributeWindows(into: [defaultFrame, defaultFrame])
        XCTAssertEqual(state.focusedContainerID, state.containers.first?.id)
    }

    // MARK: - ContainerID Auto-Increment

    func testContainerIDsAreUniqueAcrossAssignments() {
        var state = makeState()
        // First assignWindow creates a container
        state.assignWindow(wid(1))
        let firstID = state.containers[0].id

        // Redistribute creates new containers
        state.redistributeWindows(into: [defaultFrame, defaultFrame])
        let secondIDs = state.containers.map(\.id)

        XCTAssertFalse(secondIDs.contains(firstID))
        XCTAssertNotEqual(secondIDs[0], secondIDs[1])
    }

    func testContainerIDsIncrementSequentially() {
        var state = makeState()
        state.redistributeWindows(into: [defaultFrame, defaultFrame, defaultFrame])

        let rawIDs = state.containers.map(\.id.rawValue)
        XCTAssertEqual(rawIDs[1], rawIDs[0] + 1)
        XCTAssertEqual(rawIDs[2], rawIDs[1] + 1)
    }

    // MARK: - switchLayout Tests

    func testSwitchLayoutMonocleToSplit_centerCoordinate() {
        // Given: monocle layout with windows on left and right halves of screen
        let monocleFrame = CGRect(x: 8, y: 8, width: 1904, height: 1064)
        let container = makeContainer(id: 0, frame: monocleFrame, windowIDs: [1, 2, 3], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        // Window 1 center at (400, 540) → left container
        // Window 2 center at (1200, 540) → right container
        // Window 3 center at (300, 540) → left container
        let windowFrames: [WindowID: CGRect] = [
            wid(1): CGRect(x: 100, y: 240, width: 600, height: 600),
            wid(2): CGRect(x: 900, y: 240, width: 600, height: 600),
            wid(3): CGRect(x: 0, y: 240, width: 600, height: 600),
        ]

        // When
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame], windowFrames: windowFrames)

        // Then
        XCTAssertEqual(state.activeLayout, .splitHalves)
        XCTAssertEqual(state.containers.count, 2)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(3)]) // left
        XCTAssertEqual(state.containers[1].windowIDs, [wid(2)])          // right
    }

    func testSwitchLayoutSplitToMonocle_mergeOrder() {
        // Given: split halves with windows in left and right containers
        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)
        let left = Container(
            id: ContainerID(rawValue: 0), frame: leftFrame,
            windowIDs: [wid(1), wid(2)], focusedWindowID: wid(1)
        )
        let right = Container(
            id: ContainerID(rawValue: 1), frame: rightFrame,
            windowIDs: [wid(3), wid(4)], focusedWindowID: wid(3)
        )
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .splitHalves,
            containers: [left, right],
            focusedContainerID: left.id
        )

        let monocleFrame = CGRect(x: 8, y: 8, width: 1904, height: 1064)
        // All windows have frames within the monocle container
        let windowFrames: [WindowID: CGRect] = [
            wid(1): CGRect(x: 100, y: 100, width: 600, height: 600),
            wid(2): CGRect(x: 200, y: 200, width: 600, height: 600),
            wid(3): CGRect(x: 1000, y: 100, width: 600, height: 600),
            wid(4): CGRect(x: 1100, y: 200, width: 600, height: 600),
        ]

        // When
        state.switchLayout(to: .monocle, containerFrames: [monocleFrame], windowFrames: windowFrames)

        // Then: all windows merged, left container order first then right
        XCTAssertEqual(state.activeLayout, .monocle)
        XCTAssertEqual(state.containers.count, 1)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(2), wid(3), wid(4)])
    }

    func testSwitchLayoutSameLayout_noOp() {
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let originalContainerIDs = state.containers.map(\.id)

        state.switchLayout(
            to: .monocle,
            containerFrames: [defaultFrame],
            windowFrames: [wid(1): defaultFrame, wid(2): defaultFrame]
        )

        // Containers should be unchanged (same objects)
        XCTAssertEqual(state.containers.map(\.id), originalContainerIDs)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(2)])
    }

    func testSwitchLayout_emptyContainersAcceptable() {
        // Given: monocle with windows all on the left side
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        // Both windows are on the left side
        let windowFrames: [WindowID: CGRect] = [
            wid(1): CGRect(x: 100, y: 100, width: 600, height: 600),
            wid(2): CGRect(x: 200, y: 200, width: 600, height: 600),
        ]

        // When
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame], windowFrames: windowFrames)

        // Then: right container is empty, which is acceptable per PRD
        XCTAssertEqual(state.containers.count, 2)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(2)])
        XCTAssertTrue(state.containers[1].windowIDs.isEmpty)
    }

    func testSwitchLayout_unmatchedWindowFallsToNearest() {
        // Given: monocle with a window whose center is outside all new containers
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        // Window center at (5000, 540) — outside both containers, but closer to right
        let windowFrames: [WindowID: CGRect] = [
            wid(1): CGRect(x: 4700, y: 240, width: 600, height: 600),
        ]

        // When
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame], windowFrames: windowFrames)

        // Then: window assigned to nearest container (right, center ~1438 vs left center ~482)
        XCTAssertTrue(state.containers[0].windowIDs.isEmpty)
        XCTAssertEqual(state.containers[1].windowIDs, [wid(1)])
    }

    func testSwitchLayout_focusedContainerFollowsFocusedWindow() {
        // Given: monocle with focused window 2
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 2)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        // Window 1 → left, window 2 (focused) → right
        let windowFrames: [WindowID: CGRect] = [
            wid(1): CGRect(x: 100, y: 100, width: 600, height: 600),
            wid(2): CGRect(x: 1000, y: 100, width: 600, height: 600),
        ]

        // When
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame], windowFrames: windowFrames)

        // Then: focused container is the right container (holding window 2)
        XCTAssertEqual(state.focusedContainerID, state.containers[1].id)
    }
}
