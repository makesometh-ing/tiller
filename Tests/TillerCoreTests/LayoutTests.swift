import CoreGraphics
import Testing
@testable import TillerCore

let area = CGRect(x: 100, y: 50, width: 1000, height: 600)

@Test func fullScreenIsOneContainerThatFillsTheWorkspace() {
    #expect(LayoutKind.fullScreen.containerFrames(in: area, gap: 10) == [area])
}

@Test(arguments: [
    (LayoutKind.verticalSplit, CGFloat(495)),
    (LayoutKind.leftTwoThirds, CGFloat(660)),
    (LayoutKind.rightTwoThirds, CGFloat(330)),
])
func twoColumnLayouts(layout: LayoutKind, leftWidth: CGFloat) {
    let frames = layout.containerFrames(in: area, gap: 10)
    #expect(frames.count == 2)
    let (left, right) = (frames[0], frames[1])
    #expect(left.width == leftWidth)
    // Container edges on the workspace edge don't get a margin.
    #expect(left.minX == area.minX && right.maxX == area.maxX)
    #expect(left.minY == area.minY && left.height == area.height)
    #expect(right.minY == area.minY && right.height == area.height)
    // The container margin is the gap between the containers.
    #expect(right.minX - left.maxX == 10)
}

@Test func twoThirdsLayoutsAreMirrored() {
    let left = LayoutKind.leftTwoThirds.containerFrames(in: area, gap: 10)
    let right = LayoutKind.rightTwoThirds.containerFrames(in: area, gap: 10)
    #expect(left[0].width == right[1].width && left[1].width == right[0].width)
}

@Test func workspaceIsTheDesktopInsetByTheWorkspaceMargin() {
    let ws = Workspace(displayID: "d", desktop: CGRect(x: 0, y: 30, width: 1512, height: 900),
                       spacing: Spacing(workspaceMargin: 12, containerMargin: 8, carouselSpacing: 30))
    #expect(ws.frame == CGRect(x: 12, y: 42, width: 1488, height: 876))
}
