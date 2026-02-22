//
//  LayoutDefinitionsTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

final class LayoutDefinitionsTests: XCTestCase {

    // Standard 1080p monitor at origin
    let standardFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let defaultMargin: CGFloat = 8
    let defaultPadding: CGFloat = 8

    // MARK: - Monocle Tests

    func testMonocleReturnsSingleFrame() {
        let frames = LayoutDefinitions.containerFrames(
            for: .monocle, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        XCTAssertEqual(frames.count, 1)
    }

    func testMonocleMatchesInsetByMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .monocle, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        let expected = standardFrame.insetBy(dx: defaultMargin, dy: defaultMargin)
        XCTAssertEqual(frames[0], expected)
    }

    func testMonocleZeroMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .monocle, in: standardFrame,
            margin: 0, padding: 0
        )
        XCTAssertEqual(frames[0], standardFrame)
    }

    func testMonocleVariousMonitorSizes() {
        let sizes: [CGRect] = [
            CGRect(x: 0, y: 0, width: 2560, height: 1440),  // QHD
            CGRect(x: 0, y: 0, width: 3840, height: 2160),  // 4K
            CGRect(x: 0, y: 0, width: 1440, height: 900),   // MacBook Air
        ]

        for monitor in sizes {
            let frames = LayoutDefinitions.containerFrames(
                for: .monocle, in: monitor,
                margin: defaultMargin, padding: defaultPadding
            )
            XCTAssertEqual(frames[0], monitor.insetBy(dx: defaultMargin, dy: defaultMargin))
        }
    }

    func testMonocleWithNonZeroOrigin() {
        let monitor = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let frames = LayoutDefinitions.containerFrames(
            for: .monocle, in: monitor,
            margin: defaultMargin, padding: defaultPadding
        )
        XCTAssertEqual(frames[0], monitor.insetBy(dx: defaultMargin, dy: defaultMargin))
    }

    // MARK: - Split Halves Tests

    func testSplitHalvesReturnsTwoFrames() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        XCTAssertEqual(frames.count, 2)
    }

    func testSplitHalvesLeftStartsAtMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        XCTAssertEqual(frames[0].minX, defaultMargin, accuracy: 0.001)
    }

    func testSplitHalvesRightEndsAtMonitorWidthMinusMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        XCTAssertEqual(frames[1].maxX, standardFrame.width - defaultMargin, accuracy: 0.001)
    }

    func testSplitHalvesPaddingBetweenContainers() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        let gap = frames[1].minX - frames[0].maxX
        XCTAssertEqual(gap, defaultPadding, accuracy: 0.001)
    }

    func testSplitHalvesEqualWidths() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        XCTAssertEqual(frames[0].width, frames[1].width, accuracy: 0.001)
    }

    func testSplitHalvesEqualHeight() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        let expectedHeight = standardFrame.height - 2 * defaultMargin
        XCTAssertEqual(frames[0].height, expectedHeight, accuracy: 0.001)
        XCTAssertEqual(frames[1].height, expectedHeight, accuracy: 0.001)
    }

    func testSplitHalvesZeroPadding() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: 0
        )
        // Containers should be flush
        XCTAssertEqual(frames[0].maxX, frames[1].minX, accuracy: 0.001)
    }

    func testSplitHalvesZeroMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: 0, padding: defaultPadding
        )
        XCTAssertEqual(frames[0].minX, 0, accuracy: 0.001)
        XCTAssertEqual(frames[1].maxX, standardFrame.width, accuracy: 0.001)
        XCTAssertEqual(frames[0].height, standardFrame.height, accuracy: 0.001)
    }

    func testSplitHalvesZeroMarginAndPadding() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: 0, padding: 0
        )
        XCTAssertEqual(frames[0].minX, 0, accuracy: 0.001)
        XCTAssertEqual(frames[0].width, standardFrame.width / 2, accuracy: 0.001)
        XCTAssertEqual(frames[1].minX, standardFrame.width / 2, accuracy: 0.001)
        XCTAssertEqual(frames[1].maxX, standardFrame.width, accuracy: 0.001)
    }

    func testSplitHalvesWithNonZeroOrigin() {
        let monitor = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: monitor,
            margin: defaultMargin, padding: defaultPadding
        )
        XCTAssertEqual(frames[0].minX, monitor.minX + defaultMargin, accuracy: 0.001)
        XCTAssertEqual(frames[1].maxX, monitor.maxX - defaultMargin, accuracy: 0.001)
    }

    // MARK: - Edge Cases

    func testSplitHalvesVeryNarrowMonitor() {
        // Monitor narrower than 2*margin + padding — widths will be negative,
        // but the function should not crash
        let narrow = CGRect(x: 0, y: 0, width: 20, height: 1080)
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: narrow,
            margin: defaultMargin, padding: defaultPadding
        )
        XCTAssertEqual(frames.count, 2)
        // Widths will be negative — caller is responsible for clamping
    }
}
