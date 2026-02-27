//
//  ContainerHighlightManager.swift
//  Tiller
//

import AppKit

/// Window level for container highlights — below .floating so the leader overlay renders on top.
private let containerHighlightLevel = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)

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
        let config = configManager.getConfig().containerHighlights
        guard config.enabled else { return }
        guard let info = orchestrator.containerInfo(for: monitorID) else { return }

        hide()

        for (id, cgFrame) in info.frames {
            let isFocused = id == info.focusedID
            let window = makeHighlightWindow(frame: cgFrame, focused: isFocused, config: config)
            window.orderFrontRegardless()
            windows[id] = window
        }
    }

    func update(on monitorID: MonitorID) {
        let config = configManager.getConfig().containerHighlights
        guard config.enabled else { return }
        guard let info = orchestrator.containerInfo(for: monitorID) else { return }

        for (id, _) in info.frames {
            guard let window = windows[id] else { continue }
            let isFocused = id == info.focusedID
            if let view = window.contentView as? ContainerHighlightView {
                view.isFocused = isFocused
                view.applyConfig(config)
                view.needsDisplay = true
            }
        }
    }

    func hide() {
        for (_, window) in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    // MARK: - Private

    private func makeHighlightWindow(frame cgFrame: CGRect, focused: Bool, config: ContainerHighlightConfig) -> NSWindow {
        // Expand frame by glow radius so the outer glow isn't clipped at the window edge
        let pad = CGFloat(config.activeGlowRadius) + CGFloat(config.activeBorderWidth)
        let expandedCG = cgFrame.insetBy(dx: -pad, dy: -pad)
        let appKitFrame = convertToAppKit(expandedCG)

        let window = NSWindow(
            contentRect: appKitFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = containerHighlightLevel
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = ContainerHighlightView(frameSize: appKitFrame.size, glowPadding: pad)
        view.isFocused = focused
        view.applyConfig(config)
        window.contentView = view
        return window
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
    private let glowPadding: CGFloat

    private var activeBorderWidth: CGFloat = 2
    private var activeBorderColor: NSColor = .systemBlue
    private var activeGlowRadius: CGFloat = 8
    private var activeGlowOpacity: CGFloat = 0.6
    private var inactiveBorderWidth: CGFloat = 1
    private var inactiveBorderColor: NSColor = NSColor.white.withAlphaComponent(0.4)

    init(frameSize: NSSize, glowPadding: CGFloat) {
        self.glowPadding = glowPadding
        super.init(frame: NSRect(origin: .zero, size: frameSize))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func applyConfig(_ config: ContainerHighlightConfig) {
        activeBorderWidth = CGFloat(config.activeBorderWidth)
        activeBorderColor = NSColor.fromHex(config.activeBorderColor) ?? .systemBlue
        activeGlowRadius = CGFloat(config.activeGlowRadius)
        activeGlowOpacity = CGFloat(config.activeGlowOpacity)
        inactiveBorderWidth = CGFloat(config.inactiveBorderWidth)
        inactiveBorderColor = NSColor.fromHex(config.inactiveBorderColor) ?? NSColor.white.withAlphaComponent(0.4)
    }

    override func draw(_ dirtyRect: NSRect) {
        let containerRect = bounds.insetBy(dx: glowPadding, dy: glowPadding)
        let cr: CGFloat = 8

        if isFocused {
            // Clip to EXTERIOR only — prevents glow from filling the container interior
            NSGraphicsContext.saveGraphicsState()
            let clipOuter = NSBezierPath(rect: bounds)
            let clipInner = NSBezierPath(roundedRect: containerRect, xRadius: cr, yRadius: cr)
            clipOuter.append(clipInner)
            clipOuter.windingRule = .evenOdd
            clipOuter.addClip()

            // Draw border with NSShadow → shadow only renders outside (clipped)
            let shadow = NSShadow()
            shadow.shadowColor = activeBorderColor.withAlphaComponent(activeGlowOpacity)
            shadow.shadowBlurRadius = activeGlowRadius
            shadow.shadowOffset = .zero
            shadow.set()

            activeBorderColor.withAlphaComponent(0.8).setStroke()
            let path = NSBezierPath(roundedRect: containerRect, xRadius: cr, yRadius: cr)
            path.lineWidth = activeBorderWidth
            path.stroke()
            NSGraphicsContext.restoreGraphicsState()

            // Redraw border without shadow (clean, no clipping)
            activeBorderColor.withAlphaComponent(0.8).setStroke()
            let cleanBorder = NSBezierPath(roundedRect: containerRect, xRadius: cr, yRadius: cr)
            cleanBorder.lineWidth = activeBorderWidth
            cleanBorder.stroke()
        } else {
            inactiveBorderColor.setStroke()
            let path = NSBezierPath(roundedRect: containerRect, xRadius: cr, yRadius: cr)
            path.lineWidth = inactiveBorderWidth
            path.stroke()
        }
    }
}

// MARK: - Hex Color Parsing

extension NSColor {
    static func fromHex(_ hex: String) -> NSColor? {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }

        var rgba: UInt64 = 0
        guard Scanner(string: hexStr).scanHexInt64(&rgba) else { return nil }

        switch hexStr.count {
        case 6:
            return NSColor(
                red: CGFloat((rgba >> 16) & 0xFF) / 255,
                green: CGFloat((rgba >> 8) & 0xFF) / 255,
                blue: CGFloat(rgba & 0xFF) / 255,
                alpha: 1.0
            )
        case 8:
            return NSColor(
                red: CGFloat((rgba >> 24) & 0xFF) / 255,
                green: CGFloat((rgba >> 16) & 0xFF) / 255,
                blue: CGFloat((rgba >> 8) & 0xFF) / 255,
                alpha: CGFloat(rgba & 0xFF) / 255
            )
        default:
            return nil
        }
    }
}
