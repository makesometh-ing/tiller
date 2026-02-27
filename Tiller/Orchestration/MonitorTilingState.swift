//
//  MonitorTilingState.swift
//  Tiller
//

import CoreGraphics

nonisolated struct MonitorTilingState: Equatable, Sendable {
    let monitorID: MonitorID
    private(set) var activeLayout: LayoutID
    private(set) var containers: [Container]
    private(set) var focusedContainerID: ContainerID?
    private var nextContainerRawID: UInt = 0

    init(
        monitorID: MonitorID,
        activeLayout: LayoutID = .monocle,
        containers: [Container] = [],
        focusedContainerID: ContainerID? = nil
    ) {
        self.monitorID = monitorID
        self.activeLayout = activeLayout
        self.containers = containers
        self.focusedContainerID = focusedContainerID

        // Ensure nextContainerRawID is higher than any existing container ID
        if let maxID = containers.map(\.id.rawValue).max() {
            self.nextContainerRawID = maxID + 1
        }
    }

    // MARK: - Container ID Generation

    private mutating func generateContainerID() -> ContainerID {
        let id = ContainerID(rawValue: nextContainerRawID)
        nextContainerRawID += 1
        return id
    }

    // MARK: - Window Assignment

    /// Assigns a window to the specified container. If the container is not found,
    /// falls back to the focused container, then the first container.
    mutating func assignWindow(_ windowID: WindowID, toContainer containerID: ContainerID? = nil) {
        if containers.isEmpty {
            let id = generateContainerID()
            var container = Container(id: id, frame: .zero)
            container.addWindow(windowID)
            containers.append(container)
            focusedContainerID = id
            return
        }

        let targetIndex: Int
        if let containerID,
           let found = containers.firstIndex(where: { $0.id == containerID }) {
            targetIndex = found
        } else if let focusedID = focusedContainerID,
                  let found = containers.firstIndex(where: { $0.id == focusedID }) {
            targetIndex = found
        } else {
            targetIndex = 0
        }

        guard targetIndex < containers.count else { return }
        containers[targetIndex].addWindow(windowID)
    }

    /// Removes a window from whichever container holds it. Empty containers remain.
    mutating func removeWindow(_ windowID: WindowID) {
        guard let index = containers.firstIndex(where: { $0.windowIDs.contains(windowID) }) else { return }
        containers[index].removeWindow(windowID)
    }

    // MARK: - Queries

    /// Returns the container holding the given window, or nil if not found.
    func containerForWindow(_ windowID: WindowID) -> Container? {
        containers.first(where: { $0.windowIDs.contains(windowID) })
    }

    // MARK: - Frame Updates

    /// Updates container frames in place, preserving container identity and window assignments.
    /// If the container count matches, frames are updated positionally.
    /// If the count differs (layout change), falls through to redistributeWindows.
    mutating func updateContainerFrames(_ containerFrames: [CGRect]) {
        guard containers.count == containerFrames.count else {
            redistributeWindows(into: containerFrames)
            return
        }
        for i in containers.indices {
            containers[i].updateFrame(containerFrames[i])
        }
    }

    // MARK: - Layout Switching

    /// Switches to a new layout, redistributing windows round-robin across the new containers.
    /// Windows are collected from existing containers left-to-right, each container's ring buffer order.
    mutating func switchLayout(to layout: LayoutID, containerFrames: [CGRect]) {
        guard activeLayout != layout else { return }

        let previousFocusedWindowID = focusedContainerID.flatMap { cid in
            containers.first(where: { $0.id == cid })?.focusedWindowID
        }

        let allWindows = containers.flatMap(\.windowIDs)
        activeLayout = layout

        containers = containerFrames.map { frame in
            Container(id: generateContainerID(), frame: frame)
        }

        for (offset, windowID) in allWindows.enumerated() {
            guard !containers.isEmpty else { break }
            containers[offset % containers.count].addWindow(windowID)
        }

        // Focused container follows the previously focused window
        if let prevFocused = previousFocusedWindowID,
           let container = containers.first(where: { $0.windowIDs.contains(prevFocused) }) {
            focusedContainerID = container.id
        } else if let firstNonEmpty = containers.first(where: { !$0.windowIDs.isEmpty }) {
            focusedContainerID = firstNonEmpty.id
        } else {
            focusedContainerID = containers.first?.id
        }
    }

    // MARK: - Window/Container Operations

    /// Cycles focus within the container holding `windowID`.
    mutating func cycleWindow(direction: CycleDirection, windowID: WindowID) {
        guard let idx = containers.firstIndex(where: { $0.windowIDs.contains(windowID) }) else { return }
        switch direction {
        case .next: containers[idx].cycleNext()
        case .previous: containers[idx].cyclePrevious()
        }
    }

    /// Moves a specific window to the adjacent container in `direction`.
    /// Focus stays on the source container so the user can keep sending windows.
    /// If the source container empties, focus follows to the destination.
    /// No-op at boundaries or with a single container.
    mutating func moveWindow(from windowID: WindowID, direction: MoveDirection) {
        guard let srcIdx = containers.firstIndex(where: { $0.windowIDs.contains(windowID) }) else { return }
        let dstIdx: Int
        switch direction {
        case .left: dstIdx = srcIdx - 1
        case .right: dstIdx = srcIdx + 1
        case .up, .down: return
        }
        guard containers.indices.contains(dstIdx) else { return }
        containers[srcIdx].removeWindow(windowID)
        containers[dstIdx].addWindow(windowID)
        if containers[srcIdx].windowIDs.isEmpty {
            focusedContainerID = containers[dstIdx].id
        }
    }

    /// Updates focusedContainerID to match whichever container holds `windowID`.
    /// No-op if the window isn't found in any container.
    mutating func updateFocusedContainer(forWindow windowID: WindowID) {
        guard let container = containers.first(where: { $0.windowIDs.contains(windowID) }) else { return }
        focusedContainerID = container.id
    }

    /// Changes the focused container without moving any window.
    /// No-op at boundaries or with a single container.
    mutating func setFocusedContainer(direction: MoveDirection) {
        guard let currentIdx = focusedContainerID.flatMap({ id in
            containers.firstIndex(where: { $0.id == id })
        }) else { return }
        let targetIdx: Int
        switch direction {
        case .left: targetIdx = currentIdx - 1
        case .right: targetIdx = currentIdx + 1
        case .up, .down: return
        }
        guard containers.indices.contains(targetIdx) else { return }
        focusedContainerID = containers[targetIdx].id
    }

    // MARK: - Redistribution

    /// Redistributes all windows from existing containers into new containers
    /// defined by the given frames. Windows are distributed round-robin.
    mutating func redistributeWindows(into containerFrames: [CGRect]) {
        let allWindows = containers.flatMap(\.windowIDs)

        containers = containerFrames.map { frame in
            Container(id: generateContainerID(), frame: frame)
        }

        for (offset, windowID) in allWindows.enumerated() {
            guard !containers.isEmpty else { break }
            let containerIndex = offset % containers.count
            containers[containerIndex].addWindow(windowID)
        }

        focusedContainerID = containers.first?.id
    }
}
