//
//  LayoutEngineTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

final class LayoutEngineTests: XCTestCase {

    var sut: FullscreenLayoutEngine!
    let containerFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let defaultAccordionOffset = 50

    override func setUp() {
        super.setUp()
        sut = FullscreenLayoutEngine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
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

    func testEmptyWindowsReturnsEmpty() {
        let input = LayoutInput(
            windows: [],
            focusedWindowID: nil,
            actualFocusedWindowID: nil,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        XCTAssertTrue(result.placements.isEmpty)
    }

    // MARK: - Single Window Tests

    func testSingleWindowLayout() {
        let window = makeWindow(id: 1)
        let input = LayoutInput(
            windows: [window],
            focusedWindowID: window.id,
            actualFocusedWindowID: window.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        XCTAssertEqual(result.placements.count, 1)
        XCTAssertEqual(result.placements[0].windowID, window.id)
        XCTAssertEqual(result.placements[0].targetFrame, containerFrame)
    }

    func testSingleWindowWithNoFocusDefaultsToFirst() {
        let window = makeWindow(id: 1)
        let input = LayoutInput(
            windows: [window],
            focusedWindowID: nil,
            actualFocusedWindowID: nil,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        XCTAssertEqual(result.placements.count, 1)
        XCTAssertEqual(result.placements[0].targetFrame, containerFrame)
    }

    // MARK: - Two Window Tests

    func testTwoWindowLayout() {
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

        XCTAssertEqual(result.placements.count, 2)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!

        // Both windows have width = container - offset
        let expectedWidth = containerFrame.width - CGFloat(defaultAccordionOffset)
        XCTAssertEqual(placement1.targetFrame.width, expectedWidth)
        XCTAssertEqual(placement2.targetFrame.width, expectedWidth)

        // Focused window (window2) is left-aligned at container origin
        XCTAssertEqual(placement2.targetFrame.origin.x, containerFrame.minX)

        // Other window (window1) is offset right, showing strip on right of focused
        XCTAssertEqual(placement1.targetFrame.origin.x, containerFrame.minX + CGFloat(defaultAccordionOffset))

        // All windows stay on screen
        XCTAssertGreaterThanOrEqual(placement1.targetFrame.minX, containerFrame.minX)
        XCTAssertGreaterThanOrEqual(placement2.targetFrame.minX, containerFrame.minX)
    }

    func testTwoWindowLayoutFocusedFirst() {
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
        XCTAssertEqual(placement1.targetFrame.origin.x, containerFrame.minX)
        XCTAssertEqual(placement1.targetFrame.width, expectedWidth)

        // Other window (window2) offset right
        XCTAssertEqual(placement2.targetFrame.origin.x, containerFrame.minX + CGFloat(defaultAccordionOffset))
        XCTAssertEqual(placement2.targetFrame.width, expectedWidth)
    }

    // MARK: - Three Window Tests

    func testThreeWindowLayout() {
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

        XCTAssertEqual(result.placements.count, 3)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!
        let placement3 = result.placements.first(where: { $0.windowID == window3.id })!

        let offset = CGFloat(defaultAccordionOffset)
        // 3+ windows: width = container - 2*offset
        let expectedWidth = containerFrame.width - (2 * offset)

        // All windows have same width
        XCTAssertEqual(placement1.targetFrame.width, expectedWidth)
        XCTAssertEqual(placement2.targetFrame.width, expectedWidth)
        XCTAssertEqual(placement3.targetFrame.width, expectedWidth)

        // Previous (window1) at minX
        XCTAssertEqual(placement1.targetFrame.origin.x, containerFrame.minX)

        // Focused (window2) at minX + offset
        XCTAssertEqual(placement2.targetFrame.origin.x, containerFrame.minX + offset)

        // Next (window3) at minX + 2*offset
        XCTAssertEqual(placement3.targetFrame.origin.x, containerFrame.minX + (2 * offset))

        // All windows stay on screen
        XCTAssertGreaterThanOrEqual(placement1.targetFrame.minX, containerFrame.minX)
        XCTAssertGreaterThanOrEqual(placement2.targetFrame.minX, containerFrame.minX)
        XCTAssertGreaterThanOrEqual(placement3.targetFrame.minX, containerFrame.minX)
    }

    // MARK: - Four+ Window Tests

    func testFourPlusWindowLayout() {
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

        XCTAssertEqual(result.placements.count, 5)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!
        let placement3 = result.placements.first(where: { $0.windowID == window3.id })!
        let placement4 = result.placements.first(where: { $0.windowID == window4.id })!
        let placement5 = result.placements.first(where: { $0.windowID == window5.id })!

        let offset = CGFloat(defaultAccordionOffset)
        let expectedWidth = containerFrame.width - (2 * offset)

        // All windows have same width
        XCTAssertEqual(placement1.targetFrame.width, expectedWidth)
        XCTAssertEqual(placement2.targetFrame.width, expectedWidth)
        XCTAssertEqual(placement3.targetFrame.width, expectedWidth)
        XCTAssertEqual(placement4.targetFrame.width, expectedWidth)
        XCTAssertEqual(placement5.targetFrame.width, expectedWidth)

        // Previous (window2) at minX
        XCTAssertEqual(placement2.targetFrame.origin.x, containerFrame.minX)

        // Focused (window3) at minX + offset
        XCTAssertEqual(placement3.targetFrame.origin.x, containerFrame.minX + offset)

        // Next (window4) at minX + 2*offset
        XCTAssertEqual(placement4.targetFrame.origin.x, containerFrame.minX + (2 * offset))

        // Others (window1, window5) positioned same as focused (hidden behind)
        XCTAssertEqual(placement1.targetFrame.origin.x, containerFrame.minX + offset)
        XCTAssertEqual(placement5.targetFrame.origin.x, containerFrame.minX + offset)

        // CRITICAL: All windows stay ON screen
        for placement in result.placements {
            XCTAssertGreaterThanOrEqual(placement.targetFrame.minX, containerFrame.minX,
                "Window must not be positioned off-screen left")
            XCTAssertLessThanOrEqual(placement.targetFrame.maxX, containerFrame.maxX,
                "Window must not be positioned off-screen right")
        }
    }

    // MARK: - Floating Window Tests

    func testFloatingWindowsExcluded() {
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
        XCTAssertEqual(result.placements.count, 1)
        XCTAssertEqual(result.placements[0].windowID, normalWindow.id)
    }

    func testAllFloatingWindowsReturnsEmpty() {
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

        XCTAssertTrue(result.placements.isEmpty)
    }

    // MARK: - Non-Resizable Window Tests

    func testNonResizableWindowCenteredWhenFocused() {
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

        XCTAssertEqual(result.placements.count, 1)
        let placement = result.placements[0]
        XCTAssertEqual(placement.windowID, nonResizableWindow.id)

        // Should be centered: (1920 - 400) / 2 = 760, (1080 - 300) / 2 = 390
        XCTAssertEqual(placement.targetFrame.origin.x, 760)
        XCTAssertEqual(placement.targetFrame.origin.y, 390)
    }

    func testNonResizableWindowPreservesSize() {
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

        XCTAssertEqual(result.placements.count, 1)
        let placement = result.placements[0]
        XCTAssertEqual(placement.targetFrame.width, originalSize.width)
        XCTAssertEqual(placement.targetFrame.height, originalSize.height)
    }

    func testNonResizableWindowTooLargeIsSkipped() {
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
        XCTAssertTrue(result.placements.isEmpty)
    }

    func testMixedWindowTypes() {
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
        XCTAssertEqual(result.placements.count, 2)

        let tiledPlacement = result.placements.first(where: { $0.windowID == resizableWindow.id })!
        let nonResPlacement = result.placements.first(where: { $0.windowID == nonResizableWindow.id })!

        let offset = CGFloat(defaultAccordionOffset)
        let expectedWidth = containerFrame.width - offset

        // Resizable at focused position (left-aligned for 2-window accordion)
        XCTAssertEqual(tiledPlacement.targetFrame.origin.x, containerFrame.minX)
        XCTAssertEqual(tiledPlacement.targetFrame.width, expectedWidth)

        // Non-resizable at "next" ring position with natural size, centered vertically
        XCTAssertEqual(nonResPlacement.targetFrame.origin.x, containerFrame.minX + offset)
        XCTAssertEqual(nonResPlacement.targetFrame.width, 400)
        XCTAssertEqual(nonResPlacement.targetFrame.height, 300)
        XCTAssertEqual(nonResPlacement.targetFrame.origin.y, (1080 - 300) / 2)

        // Floating window has no placement
        XCTAssertNil(result.placements.first(where: { $0.windowID == floatingWindow.id }))
    }

    // MARK: - Non-Resizable Ring Buffer Tests

    func testNonResizableAtPrevPosition() {
        // Ring: [nonRes(prev), resizable(focused), resizable2(next)]
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
        XCTAssertEqual(result.placements.count, 3)

        let nonResPlacement = result.placements.first(where: { $0.windowID == nonRes.id })!
        let offset = CGFloat(defaultAccordionOffset)

        // Non-resizable at prev position (minX), natural size, centered vertically
        XCTAssertEqual(nonResPlacement.targetFrame.origin.x, containerFrame.minX)
        XCTAssertEqual(nonResPlacement.targetFrame.width, 400)
        XCTAssertEqual(nonResPlacement.targetFrame.height, 300)
        XCTAssertEqual(nonResPlacement.targetFrame.origin.y, (1080 - 300) / 2)

        // Resizable windows at their accordion positions with full accordion dimensions
        let focusedPlacement = result.placements.first(where: { $0.windowID == resizable.id })!
        let nextPlacement = result.placements.first(where: { $0.windowID == resizable2.id })!
        XCTAssertEqual(focusedPlacement.targetFrame.origin.x, containerFrame.minX + offset)
        XCTAssertEqual(nextPlacement.targetFrame.origin.x, containerFrame.minX + 2 * offset)
        XCTAssertEqual(focusedPlacement.targetFrame.width, containerFrame.width - 2 * offset)
    }

    func testNonResizableAtNextPosition() {
        // Ring: [resizable2(prev), resizable(focused), nonRes(next)]
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
        XCTAssertEqual(result.placements.count, 3)

        let nonResPlacement = result.placements.first(where: { $0.windowID == nonRes.id })!
        let offset = CGFloat(defaultAccordionOffset)

        // Non-resizable at next position (minX + 2*offset), natural size, centered vertically
        XCTAssertEqual(nonResPlacement.targetFrame.origin.x, containerFrame.minX + 2 * offset)
        XCTAssertEqual(nonResPlacement.targetFrame.width, 400)
        XCTAssertEqual(nonResPlacement.targetFrame.height, 300)
        XCTAssertEqual(nonResPlacement.targetFrame.origin.y, (1080 - 300) / 2)
    }

    func testFocusedNonResizableCenteredWithFrozenAccordion() {
        // Non-resizable is actual focus, accordion frozen on resizable
        let resizable = makeWindow(id: 1)
        let nonRes = makeWindow(id: 2, isResizable: false, frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let input = LayoutInput(
            windows: [resizable, nonRes],
            focusedWindowID: resizable.id,        // accordion frozen on resizable
            actualFocusedWindowID: nonRes.id,      // user is actually focused on nonRes
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)
        XCTAssertEqual(result.placements.count, 2)

        let nonResPlacement = result.placements.first(where: { $0.windowID == nonRes.id })!
        let resPlacement = result.placements.first(where: { $0.windowID == resizable.id })!

        // Non-resizable: centered in container (overlay behavior)
        XCTAssertEqual(nonResPlacement.targetFrame.origin.x, (1920 - 400) / 2)
        XCTAssertEqual(nonResPlacement.targetFrame.origin.y, (1080 - 300) / 2)
        XCTAssertEqual(nonResPlacement.targetFrame.width, 400)
        XCTAssertEqual(nonResPlacement.targetFrame.height, 300)

        // Resizable: at focused accordion position (left-aligned for 2-window)
        XCTAssertEqual(resPlacement.targetFrame.origin.x, containerFrame.minX)
    }

    func testMultipleNonResizableWindowsInRing() {
        // Ring: [nonRes1(prev), resizable(focused), nonRes2(next)]
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
        XCTAssertEqual(result.placements.count, 3)

        let offset = CGFloat(defaultAccordionOffset)
        let p1 = result.placements.first(where: { $0.windowID == nonRes1.id })!
        let p2 = result.placements.first(where: { $0.windowID == resizable.id })!
        let p3 = result.placements.first(where: { $0.windowID == nonRes2.id })!

        // nonRes1 at prev (minX), natural size
        XCTAssertEqual(p1.targetFrame.origin.x, containerFrame.minX)
        XCTAssertEqual(p1.targetFrame.width, 400)
        XCTAssertEqual(p1.targetFrame.height, 300)

        // resizable at focused (minX + offset), accordion dimensions
        XCTAssertEqual(p2.targetFrame.origin.x, containerFrame.minX + offset)
        XCTAssertEqual(p2.targetFrame.width, containerFrame.width - 2 * offset)

        // nonRes2 at next (minX + 2*offset), natural size
        XCTAssertEqual(p3.targetFrame.origin.x, containerFrame.minX + 2 * offset)
        XCTAssertEqual(p3.targetFrame.width, 500)
        XCTAssertEqual(p3.targetFrame.height, 350)
    }

    func testNonResizableAtOtherPositionHiddenBehindFocused() {
        // 4 windows: nonRes at "other" position (not prev/focused/next)
        let resizable1 = makeWindow(id: 1)
        let resizable2 = makeWindow(id: 2)
        let resizable3 = makeWindow(id: 3)
        let nonRes = makeWindow(id: 4, isResizable: false, frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        // Ring: [res1(prev), res2(focused), res3(next), nonRes(other)]
        let input = LayoutInput(
            windows: [resizable1, resizable2, resizable3, nonRes],
            focusedWindowID: resizable2.id,
            actualFocusedWindowID: resizable2.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)
        XCTAssertEqual(result.placements.count, 4)

        let offset = CGFloat(defaultAccordionOffset)
        let nonResPlacement = result.placements.first(where: { $0.windowID == nonRes.id })!

        // "Other" position: same X as focused (hidden behind)
        XCTAssertEqual(nonResPlacement.targetFrame.origin.x, containerFrame.minX + offset)
        XCTAssertEqual(nonResPlacement.targetFrame.width, 400)
        XCTAssertEqual(nonResPlacement.targetFrame.height, 300)
    }

    // MARK: - Accordion Offset Tests

    func testAccordionOffsetApplication() {
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

        // Previous at minX
        XCTAssertEqual(placement1.targetFrame.origin.x, containerFrame.minX)

        // Focused at minX + offset
        XCTAssertEqual(placement2.targetFrame.origin.x, containerFrame.minX + offset)

        // Next at minX + 2*offset
        XCTAssertEqual(placement3.targetFrame.origin.x, containerFrame.minX + (2 * offset))

        // Width = container - 2*offset
        let expectedWidth = containerFrame.width - (2 * offset)
        XCTAssertEqual(placement1.targetFrame.width, expectedWidth)
        XCTAssertEqual(placement2.targetFrame.width, expectedWidth)
        XCTAssertEqual(placement3.targetFrame.width, expectedWidth)
    }

    func testZeroAccordionOffset() {
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

        // With 0 offset, both windows at same position, full container width
        XCTAssertEqual(placement1.targetFrame.origin.x, containerFrame.minX)
        XCTAssertEqual(placement2.targetFrame.origin.x, containerFrame.minX)
        XCTAssertEqual(placement1.targetFrame.width, containerFrame.width)
        XCTAssertEqual(placement2.targetFrame.width, containerFrame.width)
    }

    // MARK: - Container Frame Tests

    func testContainerFrameCalculation() {
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

        XCTAssertEqual(result.placements[0].targetFrame, customContainer)
    }

    func testContainerFrameWithMargins() {
        // Simulate a container with margins applied
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

        // Window should fill the margin-adjusted container
        XCTAssertEqual(result.placements[0].targetFrame, containerWithMargins)
        XCTAssertEqual(result.placements[0].targetFrame.origin.x, margin)
        XCTAssertEqual(result.placements[0].targetFrame.origin.y, margin)
        XCTAssertEqual(result.placements[0].targetFrame.width, screenFrame.width - margin * 2)
        XCTAssertEqual(result.placements[0].targetFrame.height, screenFrame.height - margin * 2)
    }

    // MARK: - PID Passthrough Tests

    func testWindowPlacementIncludesPID() {
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

        XCTAssertEqual(result.placements[0].pid, pid)
    }

    // MARK: - Focus Edge Cases

    func testFocusedWindowNotInListDefaultsToFirst() {
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

        // First window (window1) should be treated as focused (left-aligned)
        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!

        XCTAssertEqual(placement1.targetFrame.origin.x, containerFrame.minX)
        XCTAssertEqual(placement2.targetFrame.origin.x, containerFrame.minX + CGFloat(defaultAccordionOffset))
    }

    func testFocusedFloatingWindowFallsBackToFirstTileable() {
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

        // Normal window should be placed since floating is excluded
        XCTAssertEqual(result.placements.count, 1)
        XCTAssertEqual(result.placements[0].windowID, normalWindow.id)
        XCTAssertEqual(result.placements[0].targetFrame, containerFrame)
    }
}
