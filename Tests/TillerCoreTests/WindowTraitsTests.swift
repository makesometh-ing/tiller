import CoreGraphics
import Testing
@testable import TillerCore

// Each case is a window from the dumps in docs/research/.
@Test(arguments: [
    ("WeChat main window", WindowTraits(subrole: "AXStandardWindow", sizeSettable: true), WindowKind.tiled),
    ("WeChat browser window", WindowTraits(subrole: "AXStandardWindow", sizeSettable: true), WindowKind.tiled),
    ("WeChat update window", WindowTraits(subrole: "AXStandardWindow", sizeSettable: false), WindowKind.floating),
    ("Xcode welcome window", WindowTraits(subrole: "AXStandardWindow", sizeSettable: false), WindowKind.floating),
    ("ChatGPT panel", WindowTraits(subrole: "AXDialog", sizeSettable: false, layer: 3), WindowKind.ignored),
    ("Window not on screen", WindowTraits(subrole: "AXStandardWindow", sizeSettable: true, onScreen: false), WindowKind.ignored),
    ("Finder desktop", WindowTraits(subrole: nil, sizeSettable: false, onScreen: false), WindowKind.ignored),
    ("Minimized window", WindowTraits(subrole: "AXStandardWindow", minimized: true, sizeSettable: true), WindowKind.ignored),
    ("Dialog", WindowTraits(subrole: "AXDialog", sizeSettable: true), WindowKind.floating),
    ("Modal window", WindowTraits(subrole: "AXStandardWindow", sizeSettable: true, modal: true), WindowKind.floating),
    ("Child window", WindowTraits(subrole: "AXStandardWindow", sizeSettable: true, parentIsApp: false), WindowKind.floating),
])
func windowKind(name: String, traits: WindowTraits, expected: WindowKind) {
    #expect(traits.kind == expected, "\(name)")
}

@Test func aPointIsCoveredOnlyByWindowsInFront() {
    let order: [(id: WindowID, frame: CGRect)] = [
        (id: 1, frame: CGRect(x: 0, y: 0, width: 500, height: 500)),     // tiled window in front
        (id: 2, frame: CGRect(x: 100, y: 100, width: 200, height: 200)), // floating window behind it
        (id: 3, frame: CGRect(x: 0, y: 0, width: 1000, height: 1000)),
    ]
    #expect(isCovered(CGPoint(x: 290, y: 290), window: 2, frontToBack: order))
    #expect(!isCovered(CGPoint(x: 490, y: 490), window: 1, frontToBack: order))
    #expect(!isCovered(CGPoint(x: 900, y: 900), window: 3, frontToBack: [order[2]]))
}
