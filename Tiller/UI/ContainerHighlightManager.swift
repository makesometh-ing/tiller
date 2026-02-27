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
        let highlightConfig = configManager.getConfig().containerHighlights
        guard highlightConfig.enabled else { return }
        guard let info = orchestrator.containerInfo(for: monitorID) else { return }

        hide()

        for (id, cgFrame) in info.frames {
            let isFocused = id == info.focusedID
            let window = makeHighlightWindow(frame: cgFrame, focused: isFocused, config: highlightConfig)
            window.orderFrontRegardless()
            windows[id] = window
        }
    }

    func update(on monitorID: MonitorID) {
        let highlightConfig = configManager.getConfig().containerHighlights
        guard highlightConfig.enabled else { return }
        guard let info = orchestrator.containerInfo(for: monitorID) else { return }

        for (id, _) in info.frames {
            guard let window = windows[id] else { continue }
            let isFocused = id == info.focusedID
            updateHighlightAppearance(window: window, focused: isFocused, config: highlightConfig)
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
        // Expand the frame to accommodate the glow so shadow isn't clipped
        let glowPadding = CGFloat(config.activeGlowRadius) * 2 + CGFloat(config.activeBorderWidth)
        let expandedCGFrame = cgFrame.insetBy(dx: -glowPadding, dy: -glowPadding)
        let appKitFrame = convertToAppKit(expandedCGFrame)

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

        let highlightView = ContainerHighlightView(
            frameSize: appKitFrame.size,
            glowPadding: glowPadding
        )
        highlightView.isFocused = focused
        highlightView.applyConfig(config)
        window.contentView = highlightView

        return window
    }

    private func updateHighlightAppearance(window: NSWindow, focused: Bool, config: ContainerHighlightConfig) {
        guard let view = window.contentView as? ContainerHighlightView else { return }
        view.isFocused = focused
        view.applyConfig(config)
        view.updateGlow()
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
    private let borderLayer = CAShapeLayer()

    // Config-driven values
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
        layer?.addSublayer(borderLayer)
        borderLayer.fillColor = nil
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

    override func layout() {
        super.layout()
        updateGlow()
    }

    func updateGlow() {
        let containerRect = bounds.insetBy(dx: glowPadding, dy: glowPadding)
        let cornerRadius: CGFloat = 8
        let path = CGPath(roundedRect: containerRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        borderLayer.frame = bounds
        borderLayer.path = path
        borderLayer.fillColor = nil

        if isFocused {
            borderLayer.strokeColor = activeBorderColor.withAlphaComponent(0.8).cgColor
            borderLayer.lineWidth = activeBorderWidth
            borderLayer.shadowColor = activeBorderColor.cgColor
            borderLayer.shadowRadius = activeGlowRadius
            borderLayer.shadowOpacity = Float(activeGlowOpacity)
            borderLayer.shadowOffset = .zero
            borderLayer.shadowPath = path
        } else {
            borderLayer.strokeColor = inactiveBorderColor.cgColor
            borderLayer.lineWidth = inactiveBorderWidth
            borderLayer.shadowColor = nil
            borderLayer.shadowRadius = 0
            borderLayer.shadowOpacity = 0
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
        case 6: // RGB
            return NSColor(
                red: CGFloat((rgba >> 16) & 0xFF) / 255,
                green: CGFloat((rgba >> 8) & 0xFF) / 255,
                blue: CGFloat(rgba & 0xFF) / 255,
                alpha: 1.0
            )
        case 8: // RGBA
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
