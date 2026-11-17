import AppKit
import SwiftUI

/// A panel that never becomes key, so the focused app keeps keyboard focus.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(frame: NSRect, mouse: Bool) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        ignoresMouseEvents = !mouse
        isReleasedWhenClosed = false
    }
}

/// Shows the leader key overlay: one full-screen panel for each screen, and the draggable key bar.
/// All methods run on the main thread.
final class OverlayController {
    let store: ShortcutStore
    init(store: ShortcutStore) { self.store = store }

    private var screenPanels: [String: (panel: OverlayPanel, state: OverlayState)] = [:]
    private var barPanel: OverlayPanel?
    private var listPanel: OverlayPanel?
    private var mouseMonitor: Any?
    private static let barOriginKey = "barOrigin"

    /// Shows the key bar at once. The container overlay is shown later by `update`.
    func show() {
        if store.showKeyBar {
            let bar = barPanel ?? makeBar()
            barPanel = bar
            // The keys can change in the settings, so the size is read again each time.
            if let host = bar.contentView { bar.setContentSize(host.fittingSize) }
            bar.orderFrontRegardless()
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in self?.updateHover() }
    }

    func update(_ screens: [OverlayScreen]) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for screen in screens {
            // Accessibility coordinates have the origin at the top-left. AppKit has it at the bottom-left.
            let cocoa = NSRect(x: screen.frame.minX, y: primaryHeight - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)
            let entry = screenPanels[screen.uuid] ?? {
                let state = OverlayState()
                let panel = OverlayPanel(frame: cocoa, mouse: false)
                panel.contentView = NSHostingView(rootView: ScreenOverlayView(state: state))
                return (panel, state)
            }()
            screenPanels[screen.uuid] = entry
            entry.panel.setFrame(cocoa, display: false)
            entry.state.screen = screen
            entry.panel.orderFrontRegardless()
        }
        // The key bar stays above the container overlay.
        if store.showKeyBar { barPanel?.orderFrontRegardless() }
        updateHover()
    }

    /// The center of the `v` key of the first container chip, in Accessibility coordinates. The proof runner moves the mouse pointer there.
    func firstKeyCenter() -> CGPoint? {
        for entry in screenPanels.values {
            guard let screen = entry.state.screen, let rect = entry.state.keyRects.sorted(by: { $0.key < $1.key }).first?.value else { continue }
            return CGPoint(x: screen.frame.minX + rect.midX, y: screen.frame.minY + rect.midY)
        }
        return nil
    }

    /// Moves the key bar by the same distance as a drag. The proof runner uses it.
    func moveBar(dx: CGFloat, dy: CGFloat) {
        guard let bar = barPanel else { return }
        bar.setFrameOrigin(NSPoint(x: bar.frame.minX + dx, y: bar.frame.minY + dy))
    }

    /// Opens or closes the full key list above the key bar.
    func toggleKeyList() {
        if let listPanel, listPanel.isVisible { listPanel.orderOut(nil); return }
        let host = NSHostingView(rootView: KeyList(store: store))
        let size = host.fittingSize
        let panel = listPanel ?? OverlayPanel(frame: NSRect(origin: .zero, size: size), mouse: false)
        panel.contentView = host
        panel.setContentSize(size)
        if store.showKeyBar, let bar = barPanel?.frame {
            panel.setFrameOrigin(NSPoint(x: bar.midX - size.width / 2, y: bar.maxY + 8))
        } else if let screen = NSScreen.main {
            // Without the key bar, the list is at the bottom center of the desktop.
            let v = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: v.midX - size.width / 2, y: v.minY + 16))
        }
        listPanel = panel
        panel.orderFrontRegardless()
    }

    func hide() {
        listPanel?.orderOut(nil)
        for entry in screenPanels.values {
            entry.panel.orderOut(nil)
            entry.state.screen = nil
            entry.state.hoveredKeyContainer = nil
        }
        if let barPanel { store.defaults.set(NSStringFromPoint(barPanel.frame.origin), forKey: Self.barOriginKey) }
        barPanel?.orderOut(nil)
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
    }

    private func makeBar() -> OverlayPanel {
        let host = NSHostingView(rootView: KeyBar(store: store))
        let size = host.fittingSize
        let panel = OverlayPanel(frame: NSRect(origin: .zero, size: size), mouse: true)
        panel.isMovableByWindowBackground = true
        panel.contentView = host
        if let saved = store.defaults.string(forKey: Self.barOriginKey) {
            panel.setFrameOrigin(NSPointFromString(saved))
        } else if let screen = NSScreen.main {
            // Bottom center of the desktop, above the Dock.
            let v = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: v.midX - size.width / 2, y: v.minY + 16))
        }
        return panel
    }

    /// A tooltip is shown when the mouse pointer is over the `v` key of a container chip.
    /// The overlay panels don't take mouse events, so clicks still reach the windows below.
    func updateHover() {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let p = NSEvent.mouseLocation
        let point = CGPoint(x: p.x, y: primaryHeight - p.y)
        for entry in screenPanels.values {
            guard let screen = entry.state.screen else { continue }
            let local = CGPoint(x: point.x - screen.frame.minX, y: point.y - screen.frame.minY)
            let hovered = entry.state.keyRects.first { $0.value.insetBy(dx: -3, dy: -3).contains(local) }?.key
            if entry.state.hoveredKeyContainer != hovered { entry.state.hoveredKeyContainer = hovered }
        }
    }
}
