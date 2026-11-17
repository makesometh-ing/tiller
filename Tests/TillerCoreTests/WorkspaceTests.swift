import CoreGraphics
import Testing
@testable import TillerCore

func makeWorkspace() -> Workspace {
    Workspace(displayID: "screen-a", desktop: CGRect(x: 0, y: 0, width: 1200, height: 800))
}

@Test func focusedWindowGoesIntoTheFirstContainer() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4, 5], focused: 3)
    #expect(ws.containers[0].windows == [3, 2, 5])
    #expect(ws.containers[1].windows == [1, 4])
    #expect(ws.focusedWindow == 3)
}

@Test func fullScreenPutsAllWindowsInOneContainer() {
    var ws = makeWorkspace()
    ws.apply(.fullScreen, windows: [1, 2, 3], focused: 2)
    #expect(ws.containers.count == 1)
    #expect(ws.containers[0].windows == [2, 1, 3])
}

@Test func everyWindowGetsAFrameInsideTheWorkspace() {
    for layout in LayoutKind.allCases {
        var ws = makeWorkspace()
        ws.apply(layout, windows: [1, 2, 3, 4, 5, 6], focused: 1)
        let frames = ws.windowFrames()
        #expect(frames.count == 6)
        for frame in frames.values { #expect(ws.frame.contains(frame)) }
    }
}

@Test func focusWindowWrapsInsideTheContainer() {
    var ws = makeWorkspace()
    ws.apply(.fullScreen, windows: [1, 2, 3], focused: 1)
    ws.focusWindow(offset: -1)
    #expect(ws.focusedWindow == 3)
    ws.focusWindow(offset: 1)
    ws.focusWindow(offset: 1)
    #expect(ws.focusedWindow == 2)
}

@Test func focusContainerWrapsAndSkipsEmptyContainers() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2], focused: 1)
    ws.focusContainer(offset: 1)
    #expect(ws.focusedWindow == 2)
    ws.focusContainer(offset: 1)
    #expect(ws.focusedWindow == 1)

    ws.apply(.verticalSplit, windows: [1], focused: 1)
    ws.focusContainer(offset: 1)
    #expect(ws.focusedContainerIndex == 0)
}

@Test func workspacesOfTwoScreensAreIndependent() {
    var screens = [
        "screen-a": makeWorkspace(),
        "screen-b": Workspace(displayID: "screen-b", desktop: CGRect(x: 1200, y: 0, width: 1920, height: 1080)),
    ]
    screens["screen-a"]!.apply(.leftTwoThirds, windows: [1, 2], focused: 1)
    #expect(screens["screen-b"]!.layout == .fullScreen)
    #expect(screens["screen-b"]!.windowFrames().isEmpty)
}

@Test func removeKeepsFocusOnAValidWindow() {
    var ws = makeWorkspace()
    ws.apply(.fullScreen, windows: [1, 2, 3], focused: 1)
    ws.focusWindow(offset: 2)
    ws.remove(3)
    #expect(ws.focusedWindow == 2)
}

@Test func focusOnAWindowSelectsItsContainerAndRingIndex() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4], focused: 1)
    let found = ws.focus(window: 4)
    #expect(found)
    #expect(ws.focusedContainerIndex == 1)
    #expect(ws.focusedWindow == 4)
    let missing = ws.focus(window: 99)
    #expect(!missing)
}

@Test func insertPutsTheWindowAfterTheFocusedWindowAndFocusesIt() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4], focused: 1)
    ws.focusContainer(offset: 1)
    ws.insert(9)
    #expect(ws.containers[1].windows == [2, 9, 4])
    #expect(ws.focusedWindow == 9)
    ws.insert(9)
    #expect(ws.containers[1].windows == [2, 9, 4])
}

@Test func removeAndInsertKeepTheOtherContainers() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4], focused: 1)
    ws.remove(1)
    #expect(ws.containers[0].windows == [3])
    #expect(!ws.contains(1))
    ws.insert(1)
    #expect(ws.containers[0].windows == [3, 1])
}

@Test func removeSavingPositionsArrangesTheOtherWindowsOfTheCarousel() {
    var ws = makeWorkspace()
    ws.apply(.fullScreen, windows: [1, 2, 3], focused: 1)
    let before = ws.windowFrames()
    ws.removeSavingPositions([2])
    #expect(ws.containers[0].windows == [1, 3])
    #expect(ws.windowFrames()[1] != before[1])
    #expect(ws.windowFrames()[2] == nil)
    #expect(ws.savedPositions[2] == RingPosition(layout: .fullScreen, container: 0, index: 1))
}

@Test func restorePutsTheWindowBackAtItsRingIndexAsTheFocusedWindowOfItsContainer() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4, 5], focused: 1)
    // Container 1: [1, 3, 5]. Container 2: [2, 4].
    ws.removeSavingPositions([3])
    ws.focusContainer(offset: 1)
    #expect(ws.restore([3]) == [3])
    #expect(ws.containers[0].windows == [1, 3, 5])
    #expect(ws.containers[0].focusedWindow == 3)
    // The focused container doesn't change.
    #expect(ws.focusedContainerIndex == 1)
    #expect(ws.savedPositions.isEmpty)
    #expect(ws.restore([3]).isEmpty)
}

@Test func windowsRemovedTogetherAreRestoredInTheirRingOrder() {
    var ws = makeWorkspace()
    ws.apply(.fullScreen, windows: [1, 2, 3, 4], focused: 1)
    // A hidden app: all windows are removed at once.
    ws.removeSavingPositions([4, 2, 1, 3])
    #expect(ws.containers[0].windows.isEmpty)
    ws.restore([3, 1, 4, 2])
    #expect(ws.containers[0].windows == [1, 2, 3, 4])
    // The front window of the app is the first window, and becomes the focused window.
    #expect(ws.focusedWindow == 3)
}

@Test func restoreClampsTheRingIndexWhenOtherWindowsClosed() {
    var ws = makeWorkspace()
    ws.apply(.fullScreen, windows: [1, 2, 3], focused: 1)
    ws.removeSavingPositions([3])
    ws.remove(2)
    ws.restore([3])
    #expect(ws.containers[0].windows == [1, 3])
    #expect(ws.focusedWindow == 3)
}

@Test func restoreInsertsIntoTheFocusedContainerWhenTheContainerDoesNotExist() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3], focused: 1)
    ws.removeSavingPositions([2])
    #expect(ws.savedPositions[2]?.container == 1)
    let saved = ws.savedPositions
    ws.apply(.fullScreen, windows: [1, 3], focused: 3)
    ws.savedPositions = saved
    ws.restore([2])
    #expect(ws.containers[0].windows == [3, 2, 1])
    #expect(ws.focusedWindow == 2)
}

@Test func toggleAxisChangesOnlyTheFocusedContainer() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4], focused: 1)
    ws.toggleAxis()
    #expect(ws.containers[0].axis == .vertical)
    #expect(ws.containers[1].axis == .horizontal)
    let frames = ws.windowFrames()
    #expect(frames[1]!.width == ws.containers[0].frame.width)
}

@Test func aLayoutAppliedAgainGetsItsSavedCarouselModes() {
    var ws = makeWorkspace()
    ws.apply(.fullScreen, windows: [1, 2, 3], focused: 1)
    ws.toggleAxis()
    ws.apply(.verticalSplit, windows: [1, 2, 3], focused: 1)
    #expect(ws.containers.map(\.axis) == [.horizontal, .horizontal])
    ws.apply(.fullScreen, windows: [1, 2, 3], focused: 1)
    #expect(ws.containers.map(\.axis) == [.vertical])
}

@Test func carouselModesAreSavedForEachContainer() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3], focused: 1)
    ws.focusContainer(offset: 1)
    ws.toggleAxis()
    ws.apply(.fullScreen, windows: [1, 2, 3], focused: 1)
    #expect(ws.containers.map(\.axis) == [.horizontal])
    ws.apply(.verticalSplit, windows: [1, 2, 3], focused: 1)
    #expect(ws.containers.map(\.axis) == [.horizontal, .vertical])
    #expect(ws.windowFrames()[ws.containers[1].windows[0]]?.width == ws.containers[1].frame.width)
}

@Test func carouselModesOfOneScreenDontChangeAnotherScreen() {
    var a = makeWorkspace()
    var b = Workspace(displayID: "screen-b", desktop: CGRect(x: 1200, y: 0, width: 1920, height: 1080))
    a.apply(.fullScreen, windows: [1, 2], focused: 1)
    b.apply(.fullScreen, windows: [3, 4], focused: 3)
    a.toggleAxis()
    a.apply(.fullScreen, windows: [1, 2], focused: 1)
    b.apply(.fullScreen, windows: [3, 4], focused: 3)
    #expect(a.containers[0].axis == .vertical)
    #expect(b.containers[0].axis == .horizontal)
}

@Test func theNewFocusedWindowOfTheFocusedContainerGetsFocusAfterTheFocusedWindowIsRemoved() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4, 5, 6], focused: 1)
    // Container 1: [1, 3, 5]. Container 2: [2, 4, 6].
    ws.focusContainer(offset: 1)
    ws.focusWindow(offset: 1)
    let before = ws
    ws.remove(4)
    #expect(ws.newFrontWindows(since: before) == (6, []))
    #expect(ws.focusedWindow == 6)
}

@Test func theNewFocusedWindowOfAnotherContainerIsRaisedAfterItsFocusedWindowIsRemoved() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4, 5, 6], focused: 1)
    let before = ws
    ws.removeSavingPositions([2])
    let fronts = ws.newFrontWindows(since: before)
    #expect(fronts.focus == nil)
    #expect(fronts.raise == [4])
}

@Test func removingAWindowBehindTheFocusedWindowDoesNotChangeTheFrontWindows() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4, 5, 6], focused: 1)
    let before = ws
    ws.remove(5)
    ws.remove(6)
    let fronts = ws.newFrontWindows(since: before)
    #expect(fronts.focus == nil)
    #expect(fronts.raise.isEmpty)
}

@Test func anEmptyContainerHasNoNewFocusedWindow() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2], focused: 1)
    let before = ws
    ws.remove(1)
    ws.remove(2)
    let fronts = ws.newFrontWindows(since: before)
    #expect(fronts.focus == nil)
    #expect(fronts.raise.isEmpty)
}

@Test func moveFocusedWindowPutsItInFrontOfTheNextCarouselAndKeepsFocusInTheOldContainer() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3, 4, 5], focused: 3)
    // Container 1: [3, 2, 5], container 2: [1, 4].
    let move = ws.moveFocusedWindow(offset: 1)
    #expect(move?.from == 0 && move?.to == 1)
    #expect(ws.containers[0].windows == [2, 5])
    #expect(ws.focusedContainerIndex == 0)
    #expect(ws.focusedWindow == 2)
    #expect(ws.containers[1].windows == [1, 3, 4])
    #expect(ws.containers[1].focusedWindow == 3)
}

@Test func moveFocusedWindowWrapsAroundAndFocusesTheNextWindowOfTheRing() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1, 2, 3], focused: 1)
    // Container 1: [1, 3], container 2: [2]. The last window of the ring is focused, so the first window is next.
    ws.focus(window: 3)
    #expect(ws.moveFocusedWindow(offset: -1)?.to == 1)
    #expect(ws.focusedWindow == 1)
    #expect(ws.containers[1].windows == [2, 3])
    // From container 2, the next container is container 1.
    ws.focus(window: 3)
    #expect(ws.moveFocusedWindow(offset: 1)?.to == 0)
    #expect(ws.containers[0].windows == [1, 3])
    #expect(ws.containers[0].focusedWindow == 3)
    #expect(ws.focusedWindow == 2)
}

@Test func moveIntoAnEmptyContainerAndOutOfTheLastWindowOfAContainer() {
    var ws = makeWorkspace()
    ws.apply(.verticalSplit, windows: [1], focused: 1)
    ws.focusContainer(offset: 1)
    #expect(ws.containers[1].windows.isEmpty)
    #expect(ws.moveFocusedWindow(offset: 1)?.to == 1)
    #expect(ws.containers[1].windows == [1])
    // The old container is empty, so the new container becomes the focused container.
    #expect(ws.focusedContainerIndex == 1)
    #expect(ws.focusedWindow == 1)
    for (id, frame) in ws.windowFrames() { #expect(id == 1 && frame == ws.containers[1].frame) }
}

@Test func moveDoesNothingWithOneContainerOrWithoutAFocusedWindow() {
    var ws = makeWorkspace()
    ws.apply(.fullScreen, windows: [1, 2], focused: 1)
    let before = ws
    #expect(ws.moveFocusedWindow(offset: 1) == nil)
    #expect(ws == before)
    ws.apply(.verticalSplit, windows: [], focused: nil)
    #expect(ws.moveFocusedWindow(offset: -1) == nil)
}
