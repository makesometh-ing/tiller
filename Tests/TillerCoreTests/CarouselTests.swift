import CoreGraphics
import Testing
@testable import TillerCore

let c = CGRect(x: 10, y: 20, width: 800, height: 500)
let s: CGFloat = 30

@Test func oneWindowFillsTheContainer() {
    #expect(horizontalCarouselFrames(container: c, count: 1, focused: 0, spacing: s) == [c])
}

@Test(arguments: [0, 1])
func twoWindows(focused: Int) {
    let frames = horizontalCarouselFrames(container: c, count: 2, focused: focused, spacing: s)
    let f = frames[focused], u = frames[1 - focused]
    // F starts at x = 0 of the container, width = container width − S, full height.
    #expect(f == CGRect(x: c.minX, y: c.minY, width: c.width - s, height: c.height))
    // The unfocused window starts at x = S and fills to the container edge.
    #expect(u == CGRect(x: c.minX + s, y: c.minY, width: c.width - s, height: c.height))
    #expect(u.maxX == c.maxX)
}

@Test func threeOrMoreWindowsUseARingBuffer() {
    // Infographic example, 1-indexed: N = 4, F = 1, so F − 1 = 4 and F + 1 = 2.
    let frames = horizontalCarouselFrames(container: c, count: 4, focused: 0, spacing: s)
    let w = c.width - 2 * s
    #expect(frames[0] == CGRect(x: c.minX + s, y: c.minY, width: w, height: c.height))      // F
    #expect(frames[1] == CGRect(x: c.minX + 2 * s, y: c.minY, width: w, height: c.height))  // F + 1
    #expect(frames[3] == CGRect(x: c.minX, y: c.minY, width: w, height: c.height))          // F − 1
    #expect(frames[2] == CGRect(x: c.minX + s, y: c.minY, width: w, height: c.height))      // other
    #expect(frames[1].maxX == c.maxX)
}

@Test func ringWrapsAfterFocusNext() {
    // After focusing next, F = 2, F − 1 = 1 and F + 1 = 3 (1-indexed).
    let frames = horizontalCarouselFrames(container: c, count: 4, focused: 1, spacing: s)
    #expect(frames[0].minX == c.minX)
    #expect(frames[1].minX == c.minX + s)
    #expect(frames[2].minX == c.minX + 2 * s)
    #expect(frames[3].minX == c.minX + s)
}

@Test func otherUnfocusedWindowsDoNotCoverTheVisibleEdges() {
    // Only F must be raised. Other windows must stay inside the strip that F covers.
    for n in 3...7 {
        let frames = horizontalCarouselFrames(container: c, count: n, focused: 0, spacing: s)
        for i in 2..<(n - 1) { #expect(frames[i] == frames[0]) }
    }
}

@Test(arguments: 3...8)
func focusNextChangesFourFramesForAnyCount(n: Int) {
    let before = horizontalCarouselFrames(container: c, count: n, focused: 0, spacing: s)
    let after = horizontalCarouselFrames(container: c, count: n, focused: 1, spacing: s)
    let changed = zip(before, after).filter { $0 != $1 }.count
    #expect(changed == (n == 3 ? 3 : 4))
}

@Test func verticalCarouselUsesTheSameRulesOnTheYAxis() {
    // Infographic, two windows: F height = container height − S. The unfocused window starts at y = S.
    let two = carouselFrames(container: c, count: 2, focused: 0, spacing: s, axis: .vertical)
    #expect(two[0] == CGRect(x: c.minX, y: c.minY, width: c.width, height: c.height - s))
    #expect(two[1] == CGRect(x: c.minX, y: c.minY + s, width: c.width, height: c.height - s))
    #expect(two[1].maxY == c.maxY)
    // Three or more: F at y = S, F + 1 at 2S, F − 1 at 0, height H − 2S, full width.
    let four = carouselFrames(container: c, count: 4, focused: 0, spacing: s, axis: .vertical)
    #expect(four[0].minY == c.minY + s)
    #expect(four[1].minY == c.minY + 2 * s)
    #expect(four[3].minY == c.minY)
    #expect(four[2].minY == c.minY + s)
    #expect(four.allSatisfy { $0.height == c.height - 2 * s && $0.width == c.width })
}
