import AppKit

/// A screen, with frames converted to the Accessibility coordinate space.
struct ScreenInfo {
    /// The display UUID from macOS.
    let uuid: String
    let frame: CGRect
    /// The screen frame minus the menu bar and the Dock.
    let desktop: CGRect

    /// Reads all screens. Call on the main thread.
    static func all() -> [ScreenInfo] {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return [] }
        func flip(_ r: CGRect) -> CGRect {
            CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
        }
        return NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue() else { return nil }
            return ScreenInfo(uuid: CFUUIDCreateString(nil, uuid) as String,
                              frame: flip(screen.frame), desktop: flip(screen.visibleFrame))
        }
    }

    /// The screen under the mouse pointer. Call on the main thread.
    static func underMouse(in screens: [ScreenInfo]) -> ScreenInfo? {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return screens.first }
        let p = NSEvent.mouseLocation
        let point = CGPoint(x: p.x, y: primaryHeight - p.y)
        return screens.first { $0.frame.contains(point) } ?? screens.first
    }
}
