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

@Test func aPillIsCoveredOnlyByWindowsInFront() {
    let order: [(id: WindowID, frame: CGRect)] = [
        (id: 1, frame: CGRect(x: 0, y: 0, width: 500, height: 500)),     // tiled window in front
        (id: 2, frame: CGRect(x: 100, y: 100, width: 200, height: 200)), // floating window behind it
        (id: 3, frame: CGRect(x: 0, y: 0, width: 1000, height: 1000)),
    ]
    #expect(isCovered(CGRect(x: 200, y: 270, width: 90, height: 22), window: 2, frontToBack: order))
    #expect(!isCovered(CGRect(x: 400, y: 470, width: 90, height: 22), window: 1, frontToBack: order))
    // Only the left part of the pill of window 3 is behind window 1.
    #expect(isCovered(CGRect(x: 480, y: 300, width: 150, height: 22), window: 3, frontToBack: order))
    #expect(!isCovered(CGRect(x: 600, y: 600, width: 150, height: 22), window: 3, frontToBack: order))
}
