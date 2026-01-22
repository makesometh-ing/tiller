//
//  MonitorManager.swift
//  Tiller
//

import AppKit
import Foundation

protocol MonitorServiceProtocol {
    func getConnectedMonitors() -> [MonitorInfo]
    func getMonitor(containingPoint point: CGPoint) -> MonitorInfo?
    func getMainMonitor() -> MonitorInfo?
    func getMonitor(byID id: MonitorID) -> MonitorInfo?
}

final class SystemMonitorService: MonitorServiceProtocol {
    func getConnectedMonitors() -> [MonitorInfo] {
        // Get the primary screen height for coordinate conversion
        // NSScreen uses bottom-left origin, CGWindow uses top-left origin
        guard let mainScreen = NSScreen.main else {
            return []
        }
        let primaryScreenHeight = mainScreen.frame.height

        return NSScreen.screens.compactMap { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else {
                return nil
            }

            // Convert from AppKit (bottom-left origin) to CG (top-left origin) coordinates
            let cgFrame = convertToCGCoordinates(screen.frame, primaryScreenHeight: primaryScreenHeight)
            let cgVisibleFrame = convertToCGCoordinates(screen.visibleFrame, primaryScreenHeight: primaryScreenHeight)

            return MonitorInfo(
                id: MonitorID(rawValue: screenNumber),
                name: screen.localizedName,
                frame: cgFrame,
                visibleFrame: cgVisibleFrame,
                isMain: screen == NSScreen.main,
                scaleFactor: screen.backingScaleFactor
            )
        }
    }

    private func convertToCGCoordinates(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        // In AppKit: origin is at bottom-left, Y increases upward
        // In CG: origin is at top-left, Y increases downward
        // CG_Y = primaryScreenHeight - AppKit_Y - rect.height
        let cgY = primaryScreenHeight - rect.origin.y - rect.height
        return CGRect(x: rect.origin.x, y: cgY, width: rect.width, height: rect.height)
    }

    func getMonitor(containingPoint point: CGPoint) -> MonitorInfo? {
        let monitors = getConnectedMonitors()
        return monitors.first { $0.frame.contains(point) }
    }

    func getMainMonitor() -> MonitorInfo? {
        let monitors = getConnectedMonitors()
        return monitors.first { $0.isMain }
    }

    func getMonitor(byID id: MonitorID) -> MonitorInfo? {
        let monitors = getConnectedMonitors()
        return monitors.first { $0.id == id }
    }
}

final class MockMonitorService: MonitorServiceProtocol {
    var monitors: [MonitorInfo] = []

    func getConnectedMonitors() -> [MonitorInfo] {
        return monitors
    }

    func getMonitor(containingPoint point: CGPoint) -> MonitorInfo? {
        return monitors.first { $0.frame.contains(point) }
    }

    func getMainMonitor() -> MonitorInfo? {
        return monitors.first { $0.isMain }
    }

    func getMonitor(byID id: MonitorID) -> MonitorInfo? {
        return monitors.first { $0.id == id }
    }

    func simulateMonitorConnect(_ monitor: MonitorInfo) {
        monitors.append(monitor)
    }

    func simulateMonitorDisconnect(_ id: MonitorID) {
        monitors.removeAll { $0.id == id }
    }

    static func createTestMonitor(
        id: UInt32 = 1,
        name: String = "Test Monitor",
        frame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect? = nil,
        isMain: Bool = true,
        scaleFactor: CGFloat = 2.0
    ) -> MonitorInfo {
        return MonitorInfo(
            id: MonitorID(rawValue: id),
            name: name,
            frame: frame,
            visibleFrame: visibleFrame ?? CGRect(x: 0, y: 0, width: 1920, height: 1055),
            isMain: isMain,
            scaleFactor: scaleFactor
        )
    }
}

@MainActor
final class MonitorManager {
    static let shared = MonitorManager()

    private let monitorService: MonitorServiceProtocol
    private var notificationObserver: NSObjectProtocol?
    private var _activeMonitor: MonitorInfo?

    var onMonitorChange: ((MonitorChangeEvent) -> Void)?
    var onActiveMonitorChanged: ((MonitorInfo?) -> Void)?

    private init() {
        self.monitorService = SystemMonitorService()
    }

    init(monitorService: MonitorServiceProtocol) {
        self.monitorService = monitorService
    }

    var connectedMonitors: [MonitorInfo] {
        return monitorService.getConnectedMonitors()
    }

    var activeMonitor: MonitorInfo? {
        return _activeMonitor
    }

    func startMonitoring() {
        print("[MonitorManager] Starting monitor detection")

        let monitors = monitorService.getConnectedMonitors()
        print("[MonitorManager] Found \(monitors.count) connected monitor(s):")
        for monitor in monitors {
            print("[MonitorManager]   - \(monitor.name) (ID: \(monitor.id.rawValue), main: \(monitor.isMain))")
        }

        if _activeMonitor == nil {
            _activeMonitor = monitorService.getMainMonitor()
            if let active = _activeMonitor {
                print("[MonitorManager] Set initial active monitor: \(active.name)")
            }
        }

        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenConfigurationChange()
            }
        }
    }

    func stopMonitoring() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        print("[MonitorManager] Stopped monitor detection")
    }

    func updateActiveMonitor(forWindowAtPoint point: CGPoint) {
        guard let newActiveMonitor = monitorService.getMonitor(containingPoint: point) else {
            return
        }

        if _activeMonitor?.id != newActiveMonitor.id {
            _activeMonitor = newActiveMonitor
            onActiveMonitorChanged?(newActiveMonitor)
        }
    }

    func getMonitor(byID id: MonitorID) -> MonitorInfo? {
        return monitorService.getMonitor(byID: id)
    }

    func getMainMonitor() -> MonitorInfo? {
        return monitorService.getMainMonitor()
    }

    func handleScreenConfigurationChange() {
        print("[MonitorManager] Screen configuration changed")

        let currentMonitors = monitorService.getConnectedMonitors()
        print("[MonitorManager] Now \(currentMonitors.count) connected monitor(s)")

        onMonitorChange?(.configurationChanged)

        if let activeID = _activeMonitor?.id {
            if !currentMonitors.contains(where: { $0.id == activeID }) {
                print("[MonitorManager] Active monitor disconnected, falling back to main")
                _activeMonitor = monitorService.getMainMonitor()
                onActiveMonitorChanged?(_activeMonitor)
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
