//
//  LayoutDefinitionsTests.swift
//  TillerTests
//

import CoreGraphics
import Testing
@testable import Tiller

struct LayoutDefinitionsTests {

    // Standard 1080p monitor at origin
    let standardFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let defaultMargin: CGFloat = 8
    let defaultPadding: CGFloat = 8

    // MARK: - Monocle Tests

    @Test func monocleReturnsSingleFrame() {
        let frames = LayoutDefinitions.containerFrames(
            for: .monocle, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        #expect(frames.count == 1)
    }

    @Test func monocleMatchesInsetByMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .monocle, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        let expected = standardFrame.insetBy(dx: defaultMargin, dy: defaultMargin)
        #expect(frames[0] == expected)
    }

    @Test func monocleZeroMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .monocle, in: standardFrame,
            margin: 0, padding: 0
        )
        #expect(frames[0] == standardFrame)
    }

    @Test func monocleVariousMonitorSizes() {
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
            #expect(frames[0] == monitor.insetBy(dx: defaultMargin, dy: defaultMargin))
        }
    }

    @Test func monocleWithNonZeroOrigin() {
        let monitor = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let frames = LayoutDefinitions.containerFrames(
            for: .monocle, in: monitor,
            margin: defaultMargin, padding: defaultPadding
        )
        #expect(frames[0] == monitor.insetBy(dx: defaultMargin, dy: defaultMargin))
    }

    // MARK: - Split Halves Tests

    @Test func splitHalvesReturnsTwoFrames() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        #expect(frames.count == 2)
    }

    @Test func splitHalvesLeftStartsAtMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        #expect(abs(frames[0].minX - defaultMargin) <= 0.001)
    }

    @Test func splitHalvesRightEndsAtMonitorWidthMinusMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        #expect(abs(frames[1].maxX - (standardFrame.width - defaultMargin)) <= 0.001)
    }

    @Test func splitHalvesPaddingBetweenContainers() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        let gap = frames[1].minX - frames[0].maxX
        #expect(abs(gap - defaultPadding) <= 0.001)
    }

    @Test func splitHalvesEqualWidths() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        #expect(abs(frames[0].width - frames[1].width) <= 0.001)
    }

    @Test func splitHalvesEqualHeight() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: defaultPadding
        )
        let expectedHeight = standardFrame.height - 2 * defaultMargin
        #expect(abs(frames[0].height - expectedHeight) <= 0.001)
        #expect(abs(frames[1].height - expectedHeight) <= 0.001)
    }

    @Test func splitHalvesZeroPadding() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: defaultMargin, padding: 0
        )
        // Containers should be flush
        #expect(abs(frames[0].maxX - frames[1].minX) <= 0.001)
    }

    @Test func splitHalvesZeroMargin() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: 0, padding: defaultPadding
        )
        #expect(abs(frames[0].minX - 0) <= 0.001)
        #expect(abs(frames[1].maxX - standardFrame.width) <= 0.001)
        #expect(abs(frames[0].height - standardFrame.height) <= 0.001)
    }

    @Test func splitHalvesZeroMarginAndPadding() {
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: standardFrame,
            margin: 0, padding: 0
        )
        #expect(abs(frames[0].minX - 0) <= 0.001)
        #expect(abs(frames[0].width - standardFrame.width / 2) <= 0.001)
        #expect(abs(frames[1].minX - standardFrame.width / 2) <= 0.001)
        #expect(abs(frames[1].maxX - standardFrame.width) <= 0.001)
    }

    @Test func splitHalvesWithNonZeroOrigin() {
        let monitor = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: monitor,
            margin: defaultMargin, padding: defaultPadding
        )
        #expect(abs(frames[0].minX - (monitor.minX + defaultMargin)) <= 0.001)
        #expect(abs(frames[1].maxX - (monitor.maxX - defaultMargin)) <= 0.001)
    }

    // MARK: - Edge Cases

    @Test func splitHalvesVeryNarrowMonitor() {
        // Monitor narrower than 2*margin + padding — widths will be negative,
        // but the function should not crash
        let narrow = CGRect(x: 0, y: 0, width: 20, height: 1080)
        let frames = LayoutDefinitions.containerFrames(
            for: .splitHalves, in: narrow,
            margin: defaultMargin, padding: defaultPadding
        )
        #expect(frames.count == 2)
        // Widths will be negative — caller is responsible for clamping
    }
}
