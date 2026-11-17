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
