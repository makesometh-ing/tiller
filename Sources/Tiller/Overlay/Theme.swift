import AppKit
import SwiftUI

/// Colors, materials and fonts of the Tiller UI. All views read their values from `Theme.current`.
/// Each color has a light and a dark value, so the UI follows the system appearance.
struct Theme {
    var accent: Color
    var containerEdge: Color
    var containerEdgeFocused: Color
    var chipFocused: Color
    var chipOther: Color
    var chipText: Color
    var keyBackground: Color
    var keyBorder: Color
    var keyText: Color
    var keyBackgroundOnChip: Color
    var text: Color
    var secondaryText: Color
    var floatingState: Color
    var glass: Material
    var barFont: Font
    var keyFont: Font
    var chipFont: Font
    var pillFont: Font
    /// The second line of a settings row.
    var detailFont: Font
    /// A file path in a settings row.
    var pathFont: Font

    static var current = Theme.standard

    static let standard = Theme(
        accent: dynamic(light: 0x0F9E8E, dark: 0x3FD6C4),
        containerEdge: dynamic(light: 0x0F9E8E, dark: 0x3FD6C4, alpha: 0.45),
        containerEdgeFocused: dynamic(light: 0x0F9E8E, dark: 0x3FD6C4, alpha: 0.95),
        chipFocused: dynamic(light: 0x0F9E8E, dark: 0x2BB8A8),
        chipOther: dynamic(light: 0x8E8E99, dark: 0x5B5B66),
        chipText: .white,
        keyBackground: dynamic(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.1),
        keyBorder: dynamic(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.14, darkAlpha: 0.2),
        keyText: dynamic(light: 0x3A3A40, dark: 0xD8D8DE),
        keyBackgroundOnChip: Color.white.opacity(0.22),
        text: Color.primary,
        secondaryText: Color.secondary,
        floatingState: dynamic(light: 0x0F9E8E, dark: 0x3FD6C4),
        glass: .regularMaterial,
        barFont: .system(size: 11),
        keyFont: .system(size: 10.5, weight: .medium),
        chipFont: .system(size: 11, weight: .semibold),
        pillFont: .system(size: 10),
        detailFont: .system(size: 10.5),
        pathFont: .system(size: 10.5, design: .monospaced))

    private static func dynamic(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        dynamic(light: light, dark: dark, lightAlpha: alpha, darkAlpha: alpha)
    }

    private static func dynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat, darkAlpha: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return rgb(isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }

    private static func rgb(_ hex: UInt32, alpha: CGFloat) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}
