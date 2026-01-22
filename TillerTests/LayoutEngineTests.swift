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
        pid: pid_t = 1
    ) -> WindowInfo {
        WindowInfo(
            id: WindowID(rawValue: id),
            title: title,
            appName: "TestApp",
            bundleID: "com.test.app",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
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
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        XCTAssertEqual(result.placements.count, 2)

        // Find placements by window ID
        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!

        // Focused window (window2) fills container
        XCTAssertEqual(placement2.targetFrame, containerFrame)

        // Left neighbor (window1) peeks from left
        let expectedLeftX = containerFrame.minX - containerFrame.width + CGFloat(defaultAccordionOffset)
        XCTAssertEqual(placement1.targetFrame.origin.x, expectedLeftX)
        XCTAssertEqual(placement1.targetFrame.size, containerFrame.size)
    }

    func testTwoWindowLayoutFocusedFirst() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let input = LayoutInput(
            windows: [window1, window2],
            focusedWindowID: window1.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!

        // Focused window (window1) fills container
        XCTAssertEqual(placement1.targetFrame, containerFrame)

        // Right neighbor (window2) peeks from right
        let expectedRightX = containerFrame.maxX - CGFloat(defaultAccordionOffset)
        XCTAssertEqual(placement2.targetFrame.origin.x, expectedRightX)
    }

    // MARK: - Three Window Tests

    func testThreeWindowLayout() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let window3 = makeWindow(id: 3)
        let input = LayoutInput(
            windows: [window1, window2, window3],
            focusedWindowID: window2.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        XCTAssertEqual(result.placements.count, 3)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement2 = result.placements.first(where: { $0.windowID == window2.id })!
        let placement3 = result.placements.first(where: { $0.windowID == window3.id })!

        // Focused window (window2) fills container
        XCTAssertEqual(placement2.targetFrame, containerFrame)

        // Left neighbor (window1) peeks from left
        let expectedLeftX = containerFrame.minX - containerFrame.width + CGFloat(defaultAccordionOffset)
        XCTAssertEqual(placement1.targetFrame.origin.x, expectedLeftX)

        // Right neighbor (window3) peeks from right
        let expectedRightX = containerFrame.maxX - CGFloat(defaultAccordionOffset)
        XCTAssertEqual(placement3.targetFrame.origin.x, expectedRightX)
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

        // Focused window (window3) fills container
        XCTAssertEqual(placement3.targetFrame, containerFrame)

        // Left neighbor (window2) peeks from left
        let expectedLeftX = containerFrame.minX - containerFrame.width + CGFloat(defaultAccordionOffset)
        XCTAssertEqual(placement2.targetFrame.origin.x, expectedLeftX)

        // Right neighbor (window4) peeks from right
        let expectedRightX = containerFrame.maxX - CGFloat(defaultAccordionOffset)
        XCTAssertEqual(placement4.targetFrame.origin.x, expectedRightX)

        // Window1 (far left) is offscreen left
        XCTAssertLessThan(placement1.targetFrame.maxX, containerFrame.minX)

        // Window5 (far right) is offscreen right
        XCTAssertGreaterThan(placement5.targetFrame.minX, containerFrame.maxX)
    }

    // MARK: - Floating Window Tests

    func testFloatingWindowsExcluded() {
        let normalWindow = makeWindow(id: 1, isFloating: false)
        let floatingWindow = makeWindow(id: 2, isFloating: true)
        let input = LayoutInput(
            windows: [normalWindow, floatingWindow],
            focusedWindowID: normalWindow.id,
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
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        XCTAssertTrue(result.placements.isEmpty)
    }

    // MARK: - Non-Resizable Window Tests

    func testNonResizableWindowsExcluded() {
        let resizableWindow = makeWindow(id: 1, isResizable: true)
        let nonResizableWindow = makeWindow(id: 2, isResizable: false)
        let input = LayoutInput(
            windows: [resizableWindow, nonResizableWindow],
            focusedWindowID: resizableWindow.id,
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        // Only the resizable window should be in placements
        XCTAssertEqual(result.placements.count, 1)
        XCTAssertEqual(result.placements[0].windowID, resizableWindow.id)
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
            containerFrame: containerFrame,
            accordionOffset: customOffset
        )

        let result = sut.calculate(input: input)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        let placement3 = result.placements.first(where: { $0.windowID == window3.id })!

        // Left neighbor peeks by customOffset
        let expectedLeftX = containerFrame.minX - containerFrame.width + CGFloat(customOffset)
        XCTAssertEqual(placement1.targetFrame.origin.x, expectedLeftX)

        // Right neighbor peeks by customOffset
        let expectedRightX = containerFrame.maxX - CGFloat(customOffset)
        XCTAssertEqual(placement3.targetFrame.origin.x, expectedRightX)
    }

    func testZeroAccordionOffset() {
        let window1 = makeWindow(id: 1)
        let window2 = makeWindow(id: 2)
        let input = LayoutInput(
            windows: [window1, window2],
            focusedWindowID: window2.id,
            containerFrame: containerFrame,
            accordionOffset: 0
        )

        let result = sut.calculate(input: input)

        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!

        // With 0 offset, left neighbor should be completely hidden
        let expectedLeftX = containerFrame.minX - containerFrame.width
        XCTAssertEqual(placement1.targetFrame.origin.x, expectedLeftX)
    }

    // MARK: - Container Frame Tests

    func testContainerFrameCalculation() {
        let customContainer = CGRect(x: 50, y: 50, width: 1000, height: 800)
        let window = makeWindow(id: 1)
        let input = LayoutInput(
            windows: [window],
            focusedWindowID: window.id,
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
            containerFrame: containerFrame,
            accordionOffset: defaultAccordionOffset
        )

        let result = sut.calculate(input: input)

        // First window should be treated as focused
        let placement1 = result.placements.first(where: { $0.windowID == window1.id })!
        XCTAssertEqual(placement1.targetFrame, containerFrame)
    }

    func testFocusedFloatingWindowFallsBackToFirstTileable() {
        let floatingWindow = makeWindow(id: 1, isFloating: true)
        let normalWindow = makeWindow(id: 2, isFloating: false)
        let input = LayoutInput(
            windows: [floatingWindow, normalWindow],
            focusedWindowID: floatingWindow.id,
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
