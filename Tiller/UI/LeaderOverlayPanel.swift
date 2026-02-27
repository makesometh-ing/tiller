//
//  LeaderOverlayPanel.swift
//  Tiller
//

import AppKit
import SwiftUI

@MainActor
final class LeaderOverlayPanel {

    private var panel: NSPanel?
    private let menuState: TillerMenuState
    private let slideOffset: CGFloat = 12

    init(menuState: TillerMenuState) {
        self.menuState = menuState
    }

    // MARK: - Show / Hide

    func show(on monitor: MonitorInfo) {
        let contentView = LeaderOverlayView(menuState: menuState)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 60)
        hostingView.autoresizingMask = [.width, .height]

        let panel = makePanel()
        panel.contentView = hostingView
        self.panel = panel

        // Measure intrinsic content size then position
        hostingView.layoutSubtreeIfNeeded()
        let intrinsic = hostingView.fittingSize
        let panelSize = NSSize(width: max(intrinsic.width + 32, 300), height: intrinsic.height + 16)

        let screenFrame = screenFrame(for: monitor)
        let x = screenFrame.midX - panelSize.width / 2
        let finalY = screenFrame.minY + 8
        let startY = finalY - slideOffset

        panel.setFrame(NSRect(x: x, y: startY, width: panelSize.width, height: panelSize.height), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        let finalFrame = NSRect(x: x, y: finalY, width: panelSize.width, height: panelSize.height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }
    }

    func hide() {
        guard let panel else { return }

        var targetFrame = panel.frame
        targetFrame.origin.y -= slideOffset

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(targetFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
        })
    }

    var isVisible: Bool {
        panel != nil
    }

    // MARK: - Private

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    /// Converts CG-coordinate visibleFrame (top-left origin) to AppKit screen coords (bottom-left origin).
    private func screenFrame(for monitor: MonitorInfo) -> NSRect {
        guard let screen = NSScreen.screens.first(where: {
            guard let id = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return MonitorID(rawValue: id) == monitor.id
        }) else {
            return NSScreen.main?.visibleFrame ?? .zero
        }
        return screen.visibleFrame
    }
}
