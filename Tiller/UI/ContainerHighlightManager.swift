//
//  ContainerHighlightManager.swift
//  Tiller
//

import AppKit

@MainActor
final class ContainerHighlightManager {

    private var windows: [ContainerID: NSWindow] = [:]
    private let orchestrator: AutoTilingOrchestrator
    private let configManager: ConfigManager

    init(orchestrator: AutoTilingOrchestrator, configManager: ConfigManager) {
        self.orchestrator = orchestrator
        self.configManager = configManager
    }

    // MARK: - Show / Hide

    func show(on monitorID: MonitorID) {
        guard configManager.getConfig().containerHighlightsEnabled else { return }
        guard let info = orchestrator.containerInfo(for: monitorID) else { return }

        hide()

        for (id, cgFrame) in info.frames {
            let isFocused = id == info.focusedID
            let window = makeHighlightWindow(frame: cgFrame, focused: isFocused)
            window.orderFrontRegardless()
            windows[id] = window
        }
    }

    func update(on monitorID: MonitorID) {
        guard configManager.getConfig().containerHighlightsEnabled else { return }
        guard let info = orchestrator.containerInfo(for: monitorID) else { return }

        // Update focused state in-place
        for (id, _) in info.frames {
            guard let window = windows[id] else { continue }
            let isFocused = id == info.focusedID
            updateHighlightAppearance(window: window, focused: isFocused)
        }
    }

    func hide() {
        for (_, window) in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    // MARK: - Private

    private func makeHighlightWindow(frame cgFrame: CGRect, focused: Bool) -> NSWindow {
        // Convert from CG coordinates (top-left origin) to AppKit (bottom-left origin)
        let appKitFrame = convertToAppKit(cgFrame)

        let window = NSWindow(
            contentRect: appKitFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let highlightView = ContainerHighlightView(frame: appKitFrame.size)
        highlightView.isFocused = focused
        window.contentView = highlightView

        return window
    }

    private func updateHighlightAppearance(window: NSWindow, focused: Bool) {
        guard let view = window.contentView as? ContainerHighlightView else { return }
        view.isFocused = focused
        view.needsDisplay = true
    }

    private func convertToAppKit(_ cgRect: CGRect) -> NSRect {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else {
            return NSRect(origin: .zero, size: cgRect.size)
        }
        return NSRect(
            x: cgRect.origin.x,
            y: primaryHeight - cgRect.origin.y - cgRect.height,
            width: cgRect.width,
            height: cgRect.height
        )
    }
}

// MARK: - Highlight View

private class ContainerHighlightView: NSView {

    var isFocused: Bool = false

    init(frame size: NSSize) {
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)

        if isFocused {
            // Glow effect: colored border with shadow
            NSColor.systemBlue.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 3
            path.stroke()

            // Inner glow
            let glowPath = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7)
            NSColor.systemBlue.withAlphaComponent(0.15).setFill()
            glowPath.fill()
        } else {
            // Subtle border
            NSColor.white.withAlphaComponent(0.15).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }
}
