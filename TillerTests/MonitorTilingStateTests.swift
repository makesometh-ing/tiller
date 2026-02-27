//
//  MonitorTilingStateTests.swift
//  TillerTests
//

import CoreGraphics
import Testing
@testable import Tiller

struct MonitorTilingStateTests {

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

    @Test func defaultInitialization() {
        let state = makeState()
        #expect(state.monitorID == monitorID)
        #expect(state.activeLayout == .monocle)
        #expect(state.containers.isEmpty)
        #expect(state.focusedContainerID == nil)
    }

    // MARK: - assignWindow

    @Test func assignWindowCreatesContainerIfEmpty() {
        var state = makeState()
        state.assignWindow(wid(1))

        #expect(state.containers.count == 1)
        #expect(state.containers[0].windowIDs == [wid(1)])
        #expect(state.containers[0].focusedWindowID == wid(1))
        #expect(state.focusedContainerID == state.containers[0].id)
    }

    @Test func assignWindowToFocusedContainer() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        state.assignWindow(wid(2))

        #expect(state.containers[0].windowIDs == [wid(1), wid(2)])
    }

    @Test func assignWindowToSpecificContainer() {
        let left = makeContainer(id: 0)
        let right = makeContainer(id: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .splitHalves,
            containers: [left, right],
            focusedContainerID: left.id
        )

        state.assignWindow(wid(1), toContainer: right.id)

        #expect(state.containers[0].windowIDs.isEmpty)
        #expect(state.containers[1].windowIDs == [wid(1)])
    }

    @Test func assignWindowFallsBackToFirstContainer() {
        let container = makeContainer(id: 0)
        var state = makeState(containers: [container])
        // focusedContainerID is nil

        state.assignWindow(wid(1))

        #expect(state.containers[0].windowIDs == [wid(1)])
    }

    // MARK: - removeWindow

    @Test func removeWindowFromContainer() {
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        state.removeWindow(wid(1))

        #expect(state.containers[0].windowIDs == [wid(2)])
    }

    @Test func removeWindowNotFoundIsNoOp() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = makeState(containers: [container])
        state.removeWindow(wid(99))

        #expect(state.containers[0].windowIDs == [wid(1)])
    }

    @Test func removeLastWindowLeavesEmptyContainer() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = makeState(containers: [container])
        state.removeWindow(wid(1))

        #expect(state.containers.count == 1)
        #expect(state.containers[0].windowIDs.isEmpty)
    }

    // MARK: - containerForWindow

    @Test func containerForWindowFound() {
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        let state = makeState(containers: [container])
        let found = state.containerForWindow(wid(2))
        #expect(found?.id == container.id)
    }

    @Test func containerForWindowNotFound() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let state = makeState(containers: [container])
        #expect(state.containerForWindow(wid(99)) == nil)
    }

    @Test func containerForWindowMultipleContainers() {
        let left = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [2, 3], focusedWindowID: 2)
        let state = makeState(containers: [left, right])

        #expect(state.containerForWindow(wid(1))?.id == left.id)
        #expect(state.containerForWindow(wid(3))?.id == right.id)
    }

    // MARK: - redistributeWindows

    @Test func redistributeIntoSingleContainer() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3], focusedWindowID: 1)
        var state = makeState(containers: [container])
        let newFrame = CGRect(x: 8, y: 8, width: 1904, height: 1064)

        state.redistributeWindows(into: [newFrame])

        #expect(state.containers.count == 1)
        #expect(state.containers[0].windowIDs == [wid(1), wid(2), wid(3)])
        #expect(state.containers[0].frame == newFrame)
    }

    @Test func redistributeIntoMultipleContainersRoundRobin() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        var state = makeState(containers: [container])
        let leftFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let rightFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)

        state.redistributeWindows(into: [leftFrame, rightFrame])

        #expect(state.containers.count == 2)
        #expect(state.containers[0].windowIDs == [wid(1), wid(3)])
        #expect(state.containers[1].windowIDs == [wid(2), wid(4)])
    }

    @Test func redistributePreservesWindowOrder() {
        let left = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [3, 4], focusedWindowID: 3)
        var state = makeState(containers: [left, right])

        state.redistributeWindows(into: [defaultFrame])

        // Windows collected in container order: left first, then right
        #expect(state.containers[0].windowIDs == [wid(1), wid(2), wid(3), wid(4)])
    }

    @Test func redistributeEmptyStateCreatesEmptyContainers() {
        var state = makeState()
        let frame1 = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let frame2 = CGRect(x: 960, y: 0, width: 960, height: 1080)

        state.redistributeWindows(into: [frame1, frame2])

        #expect(state.containers.count == 2)
        #expect(state.containers[0].windowIDs.isEmpty)
        #expect(state.containers[1].windowIDs.isEmpty)
    }

    @Test func redistributeGeneratesNewContainerIDs() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = makeState(containers: [container])

        state.redistributeWindows(into: [defaultFrame, defaultFrame])

        // New IDs should be generated (not reuse old id 0)
        let ids = state.containers.map(\.id)
        #expect(ids.count == 2)
        #expect(ids[0] != ids[1])
    }

    @Test func redistributeSetsFocusedContainerToFirst() {
        var state = makeState()
        state.redistributeWindows(into: [defaultFrame, defaultFrame])
        #expect(state.focusedContainerID == state.containers.first?.id)
    }

    // MARK: - ContainerID Auto-Increment

    @Test func containerIDsAreUniqueAcrossAssignments() {
        var state = makeState()
        // First assignWindow creates a container
        state.assignWindow(wid(1))
        let firstID = state.containers[0].id

        // Redistribute creates new containers
        state.redistributeWindows(into: [defaultFrame, defaultFrame])
        let secondIDs = state.containers.map(\.id)

        #expect(!secondIDs.contains(firstID))
        #expect(secondIDs[0] != secondIDs[1])
    }

    @Test func containerIDsIncrementSequentially() {
        var state = makeState()
        state.redistributeWindows(into: [defaultFrame, defaultFrame, defaultFrame])

        let rawIDs = state.containers.map(\.id.rawValue)
        #expect(rawIDs[1] == rawIDs[0] + 1)
        #expect(rawIDs[2] == rawIDs[1] + 1)
    }

    // MARK: - switchLayout Tests

    @Test func switchLayoutMonocleToSplit_roundRobin() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        #expect(state.activeLayout == .splitHalves)
        #expect(state.containers.count == 2)
        #expect(state.containers[0].windowIDs == [wid(1), wid(3)])
        #expect(state.containers[1].windowIDs == [wid(2)])
    }

    @Test func switchLayoutFourWindows_roundRobin() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3, 4], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        #expect(state.containers[0].windowIDs == [wid(1), wid(3)])
        #expect(state.containers[1].windowIDs == [wid(2), wid(4)])
    }

    @Test func switchLayoutSplitToMonocle_mergeOrder() {
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

        state.switchLayout(to: .monocle, containerFrames: [monocleFrame])

        #expect(state.activeLayout == .monocle)
        #expect(state.containers.count == 1)
        #expect(state.containers[0].windowIDs == [wid(1), wid(2), wid(3), wid(4)])
    }

    @Test func switchLayoutSameLayout_noOp() {
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let originalContainerIDs = state.containers.map(\.id)

        state.switchLayout(to: .monocle, containerFrames: [defaultFrame])

        #expect(state.containers.map(\.id) == originalContainerIDs)
        #expect(state.containers[0].windowIDs == [wid(1), wid(2)])
    }

    @Test func switchLayout_singleWindowToMultipleContainers() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        #expect(state.containers.count == 2)
        #expect(state.containers[0].windowIDs == [wid(1)])
        #expect(state.containers[1].windowIDs.isEmpty)
    }

    @Test func switchLayout_zeroWindows() {
        let container = makeContainer(id: 0)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        #expect(state.containers.count == 2)
        #expect(state.containers[0].windowIDs.isEmpty)
        #expect(state.containers[1].windowIDs.isEmpty)
    }

    // MARK: - cycleWindow Tests

    @Test func cycleWindowNext() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        state.cycleWindow(direction: .next, windowID: wid(1))

        #expect(state.containers[0].focusedWindowID == wid(2))
    }

    @Test func cycleWindowPrevious() {
        let container = makeContainer(id: 0, windowIDs: [1, 2, 3], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        state.cycleWindow(direction: .previous, windowID: wid(1))

        // Wraps to last: 3
        #expect(state.containers[0].focusedWindowID == wid(3))
    }

    @Test func cycleWindowSingleWindow() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        state.cycleWindow(direction: .next, windowID: wid(1))

        // No-op with 1 window
        #expect(state.containers[0].focusedWindowID == wid(1))
    }

    // MARK: - moveWindow Tests

    @Test func moveWindowRight() {
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

        #expect(state.containers[0].windowIDs == [wid(2)])
        #expect(state.containers[1].windowIDs == [wid(3), wid(1)])
        // Focus stays on source container
        #expect(state.focusedContainerID == left.id)
    }

    @Test func moveWindowLeft() {
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

        #expect(state.containers[0].windowIDs == [wid(1), wid(2)])
        #expect(state.containers[1].windowIDs == [wid(3)])
        // Focus stays on source container
        #expect(state.focusedContainerID == right.id)
    }

    @Test func moveWindowAtBoundary() {
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

        #expect(state.containers[0].windowIDs == [wid(1)])
        #expect(state.containers[1].windowIDs == [wid(2)])
    }

    @Test func moveWindowMonocle() {
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        // Single container — no destination
        state.moveWindow(from: wid(1), direction: .right)

        #expect(state.containers[0].windowIDs == [wid(1), wid(2)])
    }

    @Test func moveWindowLastFromContainer() {
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

        // Left container becomes empty, focus follows to destination
        #expect(state.containers[0].windowIDs.isEmpty)
        #expect(state.containers[1].windowIDs == [wid(2), wid(1)])
        #expect(state.focusedContainerID == right.id)
    }

    @Test func moveWindowMovesSpecificWindowNotContainerFocus() {
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

        #expect(state.containers[0].windowIDs == [wid(1), wid(3)])
        #expect(state.containers[1].windowIDs == [wid(2)])
        #expect(state.containers[0].focusedWindowID == wid(1))
        #expect(state.focusedContainerID == left.id)
    }

    // MARK: - updateFocusedContainer Tests

    @Test func updateFocusedContainerForWindow() {
        let left = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [3, 4], focusedWindowID: 3)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: left.id
        )

        state.updateFocusedContainer(forWindow: wid(4))
        #expect(state.focusedContainerID == right.id)

        state.updateFocusedContainer(forWindow: wid(2))
        #expect(state.focusedContainerID == left.id)
    }

    @Test func updateFocusedContainerNoOpForUnknownWindow() {
        let left = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [left], focusedContainerID: left.id
        )

        state.updateFocusedContainer(forWindow: wid(99))
        #expect(state.focusedContainerID == left.id)
    }

    // MARK: - setFocusedContainer Tests

    @Test func setFocusedContainerRight() {
        let left = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [2], focusedWindowID: 2)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: left.id
        )

        state.setFocusedContainer(direction: .right)

        #expect(state.focusedContainerID == right.id)
    }

    @Test func setFocusedContainerLeft() {
        let left = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [2], focusedWindowID: 2)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: right.id
        )

        state.setFocusedContainer(direction: .left)

        #expect(state.focusedContainerID == left.id)
    }

    @Test func setFocusedContainerAtBoundary() {
        let left = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        let right = makeContainer(id: 1, windowIDs: [2], focusedWindowID: 2)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .splitHalves,
            containers: [left, right], focusedContainerID: left.id
        )

        // Move left from leftmost — no-op
        state.setFocusedContainer(direction: .left)

        #expect(state.focusedContainerID == left.id)
    }

    @Test func setFocusedContainerMonocle() {
        let container = makeContainer(id: 0, windowIDs: [1], focusedWindowID: 1)
        var state = MonitorTilingState(
            monitorID: monitorID, activeLayout: .monocle,
            containers: [container], focusedContainerID: container.id
        )

        // Single container — no-op
        state.setFocusedContainer(direction: .right)

        #expect(state.focusedContainerID == container.id)
    }

    @Test func switchLayout_focusedContainerFollowsFocusedWindow() {
        let container = makeContainer(id: 0, windowIDs: [1, 2], focusedWindowID: 2)
        var state = MonitorTilingState(
            monitorID: monitorID,
            activeLayout: .monocle,
            containers: [container],
            focusedContainerID: container.id
        )

        let leftFrame = CGRect(x: 8, y: 8, width: 948, height: 1064)
        let rightFrame = CGRect(x: 964, y: 8, width: 948, height: 1064)

        // When: round-robin puts W1->C0, W2->C1
        state.switchLayout(to: .splitHalves, containerFrames: [leftFrame, rightFrame])

        // Then: focused container is C1 (holding focused window 2)
        #expect(state.focusedContainerID == state.containers[1].id)
    }
}
