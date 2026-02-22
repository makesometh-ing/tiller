//
//  MonitorTilingState.swift
//  Tiller
//

import CoreGraphics

struct MonitorTilingState: Equatable, Sendable {
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
