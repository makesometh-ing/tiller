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

    func testSwitchLayoutMonocleToSplit_roundRobin() {
        // Given: monocle layout with 3 windows
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        // When
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        // Then: round-robin distribution: W1→C0, W2→C1, W3→C0
        XCTAssertEqual(state.activeLayout, .splitHalves)
        XCTAssertEqual(state.containers.count, 2)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(3)])
        XCTAssertEqual(state.containers[1].windowIDs, [wid(2)])
    }

    func testSwitchLayoutFourWindows_roundRobin() {
        // Given: monocle with 4 windows
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        // When
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        // Then: W1→C0, W2→C1, W3→C0, W4→C1
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(3)])
        XCTAssertEqual(state.containers[1].windowIDs, [wid(2), wid(4)])
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

        // When
        state.switchLayout(to: .monocle, containerFrames: [monocleFrame])

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

        state.switchLayout(to: .monocle, containerFrames: [defaultFrame])

        // Containers should be unchanged (same objects)
        XCTAssertEqual(state.containers.map(\.id), originalContainerIDs)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(2)])
    }

    func testSwitchLayout_singleWindowToMultipleContainers() {
        // Given: monocle with 1 window
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        // When
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        // Then: W1→C0, C1 empty (acceptable per PRD)
        XCTAssertEqual(state.containers.count, 2)
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1)])
        XCTAssertTrue(state.containers[1].windowIDs.isEmpty)
    }

    func testSwitchLayout_zeroWindows() {
        // Given: monocle with no windows
        let container = makeContainer(id: 0)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        // When
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        // Then: both containers empty, no crash
        XCTAssertEqual(state.containers.count, 2)
        XCTAssertTrue(state.containers[0].windowIDs.isEmpty)
        XCTAssertTrue(state.containers[1].windowIDs.isEmpty)
    }

    // MARK: - cycleWindow Tests

    func testCycleWindowNext() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        state.cycleWindow(direction: .next, windowID: wid(1))

        XCTAssertEqual(state.containers[0].focusedWindowID, wid(2))
    }

    func testCycleWindowPrevious() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        state.cycleWindow(direction: .previous, windowID: wid(1))

        // Wraps to last: 3
        XCTAssertEqual(state.containers[0].focusedWindowID, wid(3))
    }

    func testCycleWindowSingleWindow() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        state.cycleWindow(direction: .next, windowID: wid(1))

        // No-op with 1 window
        XCTAssertEqual(state.containers[0].focusedWindowID, wid(1))
    }

    // MARK: - moveWindow Tests

    func testMoveWindowRight() {
        let leftFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let rightFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
        let left = Container(
            id: ContainerID(rawValue: 0), frame: leftFrame,
            windowIDs: [wid(1), wid(2)], focusedWindowID: wid(1)
        )
        let right = Container(
            id: ContainerID(rawValue: 1), frame: rightFrame,
            windowIDs: [wid(3)], focusedWindowID: wid(3)
        )
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: left.id
        )

        state.moveWindow(from: wid(1), direction: .right)

        XCTAssertEqual(state.containers[0].windowIDs, [wid(2)])
        XCTAssertEqual(state.containers[1].windowIDs, [wid(3), wid(1)])
        // Focus stays on source container
        XCTAssertEqual(state.focusedContainerID, left.id)
    }

    func testMoveWindowLeft() {
        let leftFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let rightFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
        let left = Container(
            id: ContainerID(rawValue: 0), frame: leftFrame,
            windowIDs: [wid(1)], focusedWindowID: wid(1)
        )
        let right = Container(
            id: ContainerID(rawValue: 1), frame: rightFrame,
            windowIDs: [wid(2), wid(3)], focusedWindowID: wid(2)
        )
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: right.id
        )

        state.moveWindow(from: wid(2), direction: .left)

        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(2)])
        XCTAssertEqual(state.containers[1].windowIDs, [wid(3)])
        // Focus stays on source container
        XCTAssertEqual(state.focusedContainerID, right.id)
    }

    func testMoveWindowAtBoundary() {
        let leftFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let rightFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
        let left = Container(
            id: ContainerID(rawValue: 0), frame: leftFrame,
            windowIDs: [wid(1)], focusedWindowID: wid(1)
        )
        let right = Container(
            id: ContainerID(rawValue: 1), frame: rightFrame,
            windowIDs: [wid(2)], focusedWindowID: wid(2)
        )
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: left.id
        )

        // Move left from leftmost container — no-op
        state.moveWindow(from: wid(1), direction: .left)

        XCTAssertEqual(state.containers[0].windowIDs, [wid(1)])
        XCTAssertEqual(state.containers[1].windowIDs, [wid(2)])
    }

    func testMoveWindowMonocle() {
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        // Single container — no destination
        state.moveWindow(from: wid(1), direction: .right)

        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(2)])
    }

    func testMoveWindowLastFromContainer() {
        let leftFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let rightFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
        let left = Container(
            id: ContainerID(rawValue: 0), frame: leftFrame,
            windowIDs: [wid(1)], focusedWindowID: wid(1)
        )
        let right = Container(
            id: ContainerID(rawValue: 1), frame: rightFrame,
            windowIDs: [wid(2)], focusedWindowID: wid(2)
        )
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: left.id
        )

        state.moveWindow(from: wid(1), direction: .right)

        // Left container becomes empty, focus stays on source
        XCTAssertTrue(state.containers[0].windowIDs.isEmpty)
        XCTAssertEqual(state.containers[1].windowIDs, [wid(2), wid(1)])
        XCTAssertEqual(state.focusedContainerID, left.id)
    }

    func testMoveWindowMovesSpecificWindowNotContainerFocus() {
        // Regression test: moveWindow should move the specific windowID passed in,
        // not the container's internal focusedWindowID (which may differ from OS focus).
        let leftFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let rightFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
        let left = Container(
            id: ContainerID(rawValue: 0), frame: leftFrame,
            windowIDs: [wid(1), wid(2), wid(3)], focusedWindowID: wid(1)
        )
        let right = Container(
            id: ContainerID(rawValue: 1), frame: rightFrame,
            windowIDs: [], focusedWindowID: nil
        )
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: left.id
        )

        // Move wid(2) — NOT the container's focusedWindowID (wid(1))
        state.moveWindow(from: wid(2), direction: .right)

        // wid(2) should be in the right container, wid(1) and wid(3) remain in left
        XCTAssertEqual(state.containers[0].windowIDs, [wid(1), wid(3)])
        XCTAssertEqual(state.containers[1].windowIDs, [wid(2)])
        // Container's internal focus should still be wid(1) (unchanged)
        XCTAssertEqual(state.containers[0].focusedWindowID, wid(1))
        // Focused container stays on source
        XCTAssertEqual(state.focusedContainerID, left.id)
    }

    // MARK: - setFocusedContainer Tests

    func testSetFocusedContainerRight() {
        let left = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [2], focusedWindowID: 2)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: left.id
        )

        state.setFocusedContainer(direction: .right)

        XCTAssertEqual(state.focusedContainerID, right.id)
    }

    func testSetFocusedContainerLeft() {
        let left = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [2], focusedWindowID: 2)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: right.id
        )

        state.setFocusedContainer(direction: .left)

        XCTAssertEqual(state.focusedContainerID, left.id)
    }

    func testSetFocusedContainerAtBoundary() {
        let left = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [2], focusedWindowID: 2)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: left.id
        )

        // Move left from leftmost — no-op
        state.setFocusedContainer(direction: .left)

        XCTAssertEqual(state.focusedContainerID, left.id)
    }

    func testSetFocusedContainerMonocle() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        // Single container — no-op
        state.setFocusedContainer(direction: .right)

        XCTAssertEqual(state.focusedContainerID, container.id)
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

        // When: round-robin puts W1→C0, W2→C1
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        // Then: focused container is C1 (holding focused window 2)
        XCTAssertEqual(state.focusedContainerID, state.containers[1].id)
    }
}
