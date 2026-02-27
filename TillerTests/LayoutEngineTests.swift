//
//  LayoutEngineTests.swift
//  TillerTests
//

import CoreGraphics
import Testing
@testable import Tiller

struct LayoutEngineTests {

    var sut: FullscreenLayoutEngine
    let containerFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let defaultAccordionOffset = 50

    init() {
        sut = FullscreenLayoutEngine()
    }

    // MARK: - Helper Methods

    private func makeWindow(
        id: UInt32,
        title: String = "Window",
        isFloating: Bool = false,
        isResizable: Bool = true,
        frame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
        pid: pid_t = 1
    ) -> WindowInfo {
        WindowInfo(
            id: WindowID(rawValue: id),
            title: title,
            appName: "TestApp",
            bundleID: "com.test.app",
            frame: frame,
            isResizable: isResizable,
            isFloating: isFloating,
            ownerPID: pid
        )
    }

    // MARK: - Empty Input Tests

    @Test func emptyWindowsReturnsEmpty() {
        let input = LayoutInput(
            windows: [],
            focusedWindowID: nil,
            actualFocusedWindowID: nil,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.isEmpty)
    }

    // MARK: - Single Window Tests

    @Test func singleWindowLayout() {
        let window = makeWindow(id: 1)
        let input = LayoutInput(
            windows: [window],
            focusedWindowID: window.id,
            actualFocusedWindowID: window.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.count == 1)
        #expect(result.placements[0].windowID == window.id)
        #expect(result.placements[0].targetFrame == containerFrame)
    }

    @Test func singleWindowWithNoFocusDefaultsToFirst() {
        let window = makeWindow(id: 1)
        let input = LayoutInput(
            windows: [window],
            focusedWindowID: nil,
            actualFocusedWindowID: nil,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.count == 1)
        #expect(result.placements[0].targetFrame == containerFrame)
    }

    // MARK: - Two Window Tests

    @Test func twoWindowLayout() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let input = LayoutInput(
            windows: [window1, window2],
            focusedWindowID: window2.id,
            actualFocusedWindowID: window2.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.count == 2)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!

        // Both windows have width = container - offset
        let expectedWidth = containerFrame.width - CGFloat(defaultAccordionOffset)
        #expect(placement1.targetFrame.width == expectedWidth)
        #expect(placement2.targetFrame.width == expectedWidth)

        // Focused window (window2) is left-aligned at container origin
        #expect(placement2.targetFrame.origin.x == containerFrame.minX)

        // Other window (window1) is offset right, showing strip on right of focused
        #expect(placement1.targetFrame.origin.x == containerFrame.minX + CGFloat(defaultAccordionOffset))

        // All windows stay on screen
        #expect(placement1.targetFrame.minX >= containerFrame.minX)
        #expect(placement2.targetFrame.minX >= containerFrame.minX)
    }

    @Test func twoWindowLayoutFocusedFirst() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let input = LayoutInput(
            windows: [window1, window2],
            focusedWindowID: window1.id,
            actualFocusedWindowID: window1.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!

        let expectedWidth = containerFrame.width - CGFloat(defaultAccordionOffset)

        // Focused window (window1) left-aligned
        #expect(placement1.targetFrame.origin.x == containerFrame.minX)
        #expect(placement1.targetFrame.width == expectedWidth)

        // Other window (window2) offset right
        #expect(placement2.targetFrame.origin.x == containerFrame.minX + CGFloat(defaultAccordionOffset))
        #expect(placement2.targetFrame.width == expectedWidth)
    }

    // MARK: - Three Window Tests

    @Test func threeWindowLayout() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let window3 = makeWindow(id: 3)
        let input = LayoutInput(
            windows: [window1, window2, window3],
            focusedWindowID: window2.id,
            actualFocusedWindowID: window2.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.count == 3)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!
        let placement3 = result.placements.first(where: { $0.windowID == window3.id })!

        let offset = CGFloat(defaultAccordionOffset)
        // 3+ windows: width = container - 2*offset
        let expectedWidth = containerFrame.width - (2 * offset)

        // All windows have same width
        #expect(placement1.targetFrame.width == expectedWidth)
        #expect(placement2.targetFrame.width == expectedWidth)
        #expect(placement3.targetFrame.width == expectedWidth)

        // Previous (window1) at minX
        #expect(placement1.targetFrame.origin.x == containerFrame.minX)

        // Focused (window2) at minX + offset
        #expect(placement2.targetFrame.origin.x == containerFrame.minX + offset)

        // Next (window3) at minX + 2*offset
        #expect(placement3.targetFrame.origin.x == containerFrame.minX + (2 * offset))

        // All windows stay on screen
        #expect(placement1.targetFrame.minX >= containerFrame.minX)
        #expect(placement2.targetFrame.minX >= containerFrame.minX)
        #expect(placement3.targetFrame.minX >= containerFrame.minX)
    }

    // MARK: - Four+ Window Tests

    @Test func fourPlusWindowLayout() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let window3 = makeWindow(id: 3)
        let window4 = makeWindow(id: 4)
        let window5 = makeWindow(id: 5)
        let input = LayoutInput(
            windows: [window1, window2, window3, window4, window5],
            focusedWindowID: window3.id,
            actualFocusedWindowID: window3.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.count == 5)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!
        let placement3 = result.placements.first(where: { $0.windowID == window3.id })!
        let placement4 = result.placements.first(where: { $0.windowID == window4.id })!
        let placement5 = result.placements.first(where: { $0.windowID == window5.id })!

        let offset = CGFloat(defaultAccordionOffset)
        let expectedWidth = containerFrame.width - (2 * offset)

        // All windows have same width
        #expect(placement1.targetFrame.width == expectedWidth)
        #expect(placement2.targetFrame.width == expectedWidth)
        #expect(placement3.targetFrame.width == expectedWidth)
        #expect(placement4.targetFrame.width == expectedWidth)
        #expect(placement5.targetFrame.width == expectedWidth)

        // Previous (window2) at minX
        #expect(placement2.targetFrame.origin.x == containerFrame.minX)

        // Focused (window3) at minX + offset
        #expect(placement3.targetFrame.origin.x == containerFrame.minX + offset)

        // Next (window4) at minX + 2*offset
        #expect(placement4.targetFrame.origin.x == containerFrame.minX + (2 * offset))

        // Others (window1, window5) positioned same as focused (hidden behind)
        #expect(placement1.targetFrame.origin.x == containerFrame.minX + offset)
        #expect(placement5.targetFrame.origin.x == containerFrame.minX + offset)

        // CRITICAL: All windows stay ON screen
        for placement in result.placements {
            #expect(placement.targetFrame.minX >= containerFrame.minX,
                "Window must not be positioned off-screen left")
            #expect(placement.targetFrame.maxX <= containerFrame.maxX,
                "Window must not be positioned off-screen right")
        }
    }

    // MARK: - Floating Window Tests

    @Test func floatingWindowsExcluded() {
        let normalWindow = makeWindow(id: 1, isFloating: false)
        let floatingWindow = makeWindow(id: 2, isFloating: true)
        let input = LayoutInput(
            windows: [normalWindow, floatingWindow],
            focusedWindowID: normalWindow.id,
            actualFocusedWindowID: normalWindow.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        // Only the non-floating window should be in placements
        #expect(result.placements.count == 1)
        #expect(result.placements[0].windowID == normalWindow.id)
    }

    @Test func allFloatingWindowsReturnsEmpty() {
        let floating1 = makeWindow(id: 1, isFloating: true)
        let floating2 = makeWindow(id: 2, isFloating: true)
        let input = LayoutInput(
            windows: [floating1, floating2],
            focusedWindowID: floating1.id,
            actualFocusedWindowID: floating1.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.isEmpty)
    }

    // MARK: - Non-Resizable Window Tests

    @Test func nonResizableWindowCenteredWhenFocused() {
        let nonResizableWindow = makeWindow(
            id: 1,
            isResizable: false,
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        let input = LayoutInput(
            windows: [nonResizableWindow],
            focusedWindowID: nonResizableWindow.id,
            actualFocusedWindowID: nonResizableWindow.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.count == 1)
        let placement = result.placements[0]
        #expect(placement.windowID == nonResizableWindow.id)

        // Should be centered: CGFloat(1920 - 400) / 2 = 760, CGFloat(1080 - 300) / 2 = 390
        #expect(placement.targetFrame.origin.x == 760)
        #expect(placement.targetFrame.origin.y == 390)
    }

    @Test func nonResizableWindowPreservesSize() {
        let originalSize = CGSize(width: 500, height: 350)
        let nonResizableWindow = makeWindow(
            id: 1,
            isResizable: false,
            frame: CGRect(origin: .zero, size: originalSize)
        )
        let input = LayoutInput(
            windows: [nonResizableWindow],
            focusedWindowID: nonResizableWindow.id,
            actualFocusedWindowID: nonResizableWindow.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.count == 1)
        let placement = result.placements[0]
        #expect(placement.targetFrame.width == originalSize.width)
        #expect(placement.targetFrame.height == originalSize.height)
    }

    @Test func nonResizableWindowTooLargeIsSkipped() {
        let oversizedWindow = makeWindow(
            id: 1,
            isResizable: false,
            frame: CGRect(x: 0, y: 0, width: 3000, height: 2000)
        )
        let input = LayoutInput(
            windows: [oversizedWindow],
            focusedWindowID: oversizedWindow.id,
            actualFocusedWindowID: oversizedWindow.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        // Too large for container — no placement (auto-float)
        #expect(result.placements.isEmpty)
    }

    @Test func mixedWindowTypes() {
        let resizableWindow = makeWindow(id: 1, isResizable: true)
        let nonResizableWindow = makeWindow(
            id: 2,
            isResizable: false,
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        let floatingWindow = makeWindow(id: 3, isFloating: true)

        let input = LayoutInput(
            windows: [resizableWindow, nonResizableWindow, floatingWindow],
            focusedWindowID: resizableWindow.id,
            actualFocusedWindowID: resizableWindow.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        // 2 placements: resizable (tiled) + non-resizable (at ring position). Floating excluded.
        #expect(result.placements.count == 2)

        let tiledPlacement = result.placements.first(where: { $0.windowID == resizableWindow.id })!
        let nonResPlacement = result.placements.first(where: { $0.windowID == nonResizableWindow.id })!

        let offset = CGFloat(defaultAccordionOffset)
        let expectedWidth = containerFrame.width - offset

        // Resizable at focused position (left-aligned for 2-window accordion)
        #expect(tiledPlacement.targetFrame.origin.x == containerFrame.minX)
        #expect(tiledPlacement.targetFrame.width == expectedWidth)

        // Non-resizable at "next" ring position with natural size, centered vertically
        #expect(nonResPlacement.targetFrame.origin.x == containerFrame.minX + offset)
        #expect(nonResPlacement.targetFrame.width == 400)
        #expect(nonResPlacement.targetFrame.height == 300)
        #expect(nonResPlacement.targetFrame.origin.y == CGFloat(1080 - 300) / 2)

        // Floating window has no placement
        #expect(result.placements.first(where: { $0.windowID == floatingWindow.id }) == nil)
    }

    // MARK: - Non-Resizable Ring Buffer Tests

    @Test func nonResizableAtPrevPosition() {
        let nonRes = makeWindow(id: 1, isResizable: false, frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let resizable = makeWindow(id: 2)
        let resizable2 = makeWindow(id: 3)

        let input = LayoutInput(
            windows: [nonRes, resizable, resizable2],
            focusedWindowID: resizable.id,
            actualFocusedWindowID: resizable.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)
        #expect(result.placements.count == 3)

        let nonResPlacement = result.placements.first(where: { $0.windowID == nonRes.id })!
        let offset = CGFloat(defaultAccordionOffset)

        #expect(nonResPlacement.targetFrame.origin.x == containerFrame.minX)
        #expect(nonResPlacement.targetFrame.width == 400)
        #expect(nonResPlacement.targetFrame.height == 300)
        #expect(nonResPlacement.targetFrame.origin.y == CGFloat(1080 - 300) / 2)

        let focusedPlacement = result.placements.first(where: { $0.windowID == resizable.id })!
        let nextPlacement = result.placements.first(where: { $0.windowID == resizable2.id })!
        #expect(focusedPlacement.targetFrame.origin.x == containerFrame.minX + offset)
        #expect(nextPlacement.targetFrame.origin.x == containerFrame.minX + 2 * offset)
        #expect(focusedPlacement.targetFrame.width == containerFrame.width - 2 * offset)
    }

    @Test func nonResizableAtNextPosition() {
        let resizable2 = makeWindow(id: 1)
        let resizable = makeWindow(id: 2)
        let nonRes = makeWindow(id: 3, isResizable: false, frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let input = LayoutInput(
            windows: [resizable2, resizable, nonRes],
            focusedWindowID: resizable.id,
            actualFocusedWindowID: resizable.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)
        #expect(result.placements.count == 3)

        let nonResPlacement = result.placements.first(where: { $0.windowID == nonRes.id })!
        let offset = CGFloat(defaultAccordionOffset)

        #expect(nonResPlacement.targetFrame.origin.x == containerFrame.minX + 2 * offset)
        #expect(nonResPlacement.targetFrame.width == 400)
        #expect(nonResPlacement.targetFrame.height == 300)
        #expect(nonResPlacement.targetFrame.origin.y == CGFloat(1080 - 300) / 2)
    }

    @Test func focusedNonResizableCenteredWithFrozenAccordion() {
        let resizable = makeWindow(id: 1)
        let nonRes = makeWindow(id: 2, isResizable: false, frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let input = LayoutInput(
            windows: [resizable, nonRes],
            focusedWindowID: resizable.id,
            actualFocusedWindowID: nonRes.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)
        #expect(result.placements.count == 2)

        let nonResPlacement = result.placements.first(where: { $0.windowID == nonRes.id })!
        let resPlacement = result.placements.first(where: { $0.windowID == resizable.id })!

        #expect(nonResPlacement.targetFrame.origin.x == CGFloat(1920 - 400) / 2)
        #expect(nonResPlacement.targetFrame.origin.y == CGFloat(1080 - 300) / 2)
        #expect(nonResPlacement.targetFrame.width == 400)
        #expect(nonResPlacement.targetFrame.height == 300)

        #expect(resPlacement.targetFrame.origin.x == containerFrame.minX)
    }

    @Test func multipleNonResizableWindowsInRing() {
        let nonRes1 = makeWindow(id: 1, isResizable: false, frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let resizable = makeWindow(id: 2)
        let nonRes2 = makeWindow(id: 3, isResizable: false, frame: CGRect(x: 0, y: 0, width: 500, height: 350))

        let input = LayoutInput(
            windows: [nonRes1, resizable, nonRes2],
            focusedWindowID: resizable.id,
            actualFocusedWindowID: resizable.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)
        #expect(result.placements.count == 3)

        let offset = CGFloat(defaultAccordionOffset)
        let p1 = result.placements.first(where: { $0.windowID == nonRes1.id })!
        let p2 = result.placements.first(where: { $0.windowID == resizable.id })!
        let p3 = result.placements.first(where: { $0.windowID == nonRes2.id })!

        #expect(p1.targetFrame.origin.x == containerFrame.minX)
        #expect(p1.targetFrame.width == 400)
        #expect(p1.targetFrame.height == 300)

        #expect(p2.targetFrame.origin.x == containerFrame.minX + offset)
        #expect(p2.targetFrame.width == containerFrame.width - 2 * offset)

        #expect(p3.targetFrame.origin.x == containerFrame.minX + 2 * offset)
        #expect(p3.targetFrame.width == 500)
        #expect(p3.targetFrame.height == 350)
    }

    @Test func nonResizableAtOtherPositionHiddenBehindFocused() {
        let resizable1 = makeWindow(id: 1)
        let resizable2 = makeWindow(id: 2)
        let resizable3 = makeWindow(id: 3)
        let nonRes = makeWindow(id: 4, isResizable: false, frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let input = LayoutInput(
            windows: [resizable1, resizable2, resizable3, nonRes],
            focusedWindowID: resizable2.id,
            actualFocusedWindowID: resizable2.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)
        #expect(result.placements.count == 4)

        let offset = CGFloat(defaultAccordionOffset)
        let nonResPlacement = result.placements.first(where: { $0.windowID == nonRes.id })!

        #expect(nonResPlacement.targetFrame.origin.x == containerFrame.minX + offset)
        #expect(nonResPlacement.targetFrame.width == 400)
        #expect(nonResPlacement.targetFrame.height == 300)
    }

    // MARK: - Accordion Offset Tests

    @Test func accordionOffsetApplication() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let window3 = makeWindow(id: 3)
        let customOffset = 100

        let input = LayoutInput(
            windows: [window1, window2, window3],
            focusedWindowID: window2.id,
            actualFocusedWindowID: window2.id,
            containerFrame: containerFrame,
            accordionOffset: customOffset
        )

        let result = sut.calculate(input: input)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!
        let placement3 = result.placements.first(where: { $0.windowID == window3.id })!

        let offset = CGFloat(customOffset)

        #expect(placement1.targetFrame.origin.x == containerFrame.minX)
        #expect(placement2.targetFrame.origin.x == containerFrame.minX + offset)
        #expect(placement3.targetFrame.origin.x == containerFrame.minX + (2 * offset))

        let expectedWidth = containerFrame.width - (2 * offset)
        #expect(placement1.targetFrame.width == expectedWidth)
        #expect(placement2.targetFrame.width == expectedWidth)
        #expect(placement3.targetFrame.width == expectedWidth)
    }

    @Test func zeroAccordionOffset() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let input = LayoutInput(
            windows: [window1, window2],
            focusedWindowID: window2.id,
            actualFocusedWindowID: window2.id,
            containerFrame: containerFrame,
            accordionOffset: 0
        )

        let result = sut.calculate(input: input)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!

        #expect(placement1.targetFrame.origin.x == containerFrame.minX)
        #expect(placement2.targetFrame.origin.x == containerFrame.minX)
        #expect(placement1.targetFrame.width == containerFrame.width)
        #expect(placement2.targetFrame.width == containerFrame.width)
    }

    // MARK: - Container Frame Tests

    @Test func containerFrameCalculation() {
        let customContainer = CGRect(x: 50, y: 50, width: 1000, height: 800)
        let window = makeWindow(id: 1)
        let input = LayoutInput(
            windows: [window],
            focusedWindowID: window.id,
            actualFocusedWindowID: window.id,
            containerFrame: customContainer,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements[0].targetFrame == customContainer)
    }

    @Test func containerFrameWithMargins() {
        let margin: CGFloat = 20
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let containerWithMargins = screenFrame.insetBy(dx: margin, dy: margin)

        let window = makeWindow(id: 1)
        let input = LayoutInput(
            windows: [window],
            focusedWindowID: window.id,
            actualFocusedWindowID: window.id,
            containerFrame: containerWithMargins,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements[0].targetFrame == containerWithMargins)
        #expect(result.placements[0].targetFrame.origin.x == margin)
        #expect(result.placements[0].targetFrame.origin.y == margin)
        #expect(result.placements[0].targetFrame.width == screenFrame.width - margin * 2)
        #expect(result.placements[0].targetFrame.height == screenFrame.height - margin * 2)
    }

    // MARK: - PID Passthrough Tests

    @Test func windowPlacementIncludesPID() {
        let pid: pid_t = 12345
        let window = makeWindow(id: 1, pid: pid)
        let input = LayoutInput(
            windows: [window],
            focusedWindowID: window.id,
            actualFocusedWindowID: window.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements[0].pid == pid)
    }

    // MARK: - Focus Edge Cases

    @Test func focusedWindowNotInListDefaultsToFirst() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let nonExistentFocusID = WindowID(rawValue: 999)
        let input = LayoutInput(
            windows: [window1, window2],
            focusedWindowID: nonExistentFocusID,
            actualFocusedWindowID: nonExistentFocusID,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!

        #expect(placement1.targetFrame.origin.x == containerFrame.minX)
        #expect(placement2.targetFrame.origin.x == containerFrame.minX + CGFloat(defaultAccordionOffset))
    }

    @Test func focusedFloatingWindowFallsBackToFirstTileable() {
        let floatingWindow = makeWindow(id: 1, isFloating: true)
        let normalWindow = makeWindow(id: 2, isFloating: false)
        let input = LayoutInput(
            windows: [floatingWindow, normalWindow],
            focusedWindowID: floatingWindow.id,
            actualFocusedWindowID: floatingWindow.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        #expect(result.placements.count == 1)
        #expect(result.placements[0].windowID == normalWindow.id)
        #expect(result.placements[0].targetFrame == containerFrame)
    }
}
