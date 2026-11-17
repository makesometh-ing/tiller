import AppKit
import TillerCore

/// Runs actions on the workspace of each screen. All state is read and written on `queue`.
final class Controller {
    private let ax: AXWindows
    private let queue = DispatchQueue(label: "tiller.windows", qos: .userInteractive)
    /// One workspace for each screen, with the display UUID as the key.
    private var workspaces: [String: Workspace] = [:]
    /// Windows that the window rule tiles, floated with the `f` key.
    private var floated = Set<WindowID>()
    /// The frame of each window before Tiller tiled it the first time. A floated window goes back to this frame.
    private var untiledFrames: [WindowID: CGRect] = [:]
    /// Called on `queue` after each action when set.
    var onReport: ((ActionReport) -> Void)?

    init(ax: AXWindows) { self.ax = ax }

    /// Call on the main thread. `completion` runs on the main thread after the windows are moved and focused. An action that doesn't change a workspace doesn't call it.
    func perform(_ action: Action, received: DispatchTime, completion: (() -> Void)? = nil) {
        let screens = ScreenInfo.all()
        let mouseScreen = ScreenInfo.underMouse(in: screens)
        queue.async {
            self.run(action, received: received, screens: screens, mouseScreen: mouseScreen, completion: completion)
        }
    }

    /// Call on the main thread. `expectedFocused` is the system focused window when nil.
    func reportCurrentState(action: String, latencyMs: Double = 0, expectedFocused: WindowID? = nil) {
        guard onReport != nil else { return }
        let screens = ScreenInfo.all()
        let mouseScreen = ScreenInfo.underMouse(in: screens)
        queue.async {
            let refs = Dictionary(self.ax.windows().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let focused = self.ax.focusedWindowID()
            guard let screen = Self.screen(of: focused, refs: refs, screens: screens) ?? mouseScreen,
                  let ws = self.workspaces[screen.uuid] else { return }
            self.onReport?(self.report(action, ws, refs: refs, latencyMs: latencyMs, moved: 0, expectedFocused: expectedFocused ?? focused))
        }
    }

    /// The proof runner `click:` step. Returns a window and a visible point of it, in Accessibility coordinates.
    /// `next` and `previous` are the windows after and before the focused window in the focused carousel.
    /// `container<n>` is the focused window of container n. `floating` is the front floating window.
    /// Call on the main thread. `completion` runs on the main thread.
    func clickTarget(_ name: String, completion: @escaping ((id: WindowID, point: CGPoint)?) -> Void) {
        queue.async {
            let windows = self.ax.windows()
            let focused = self.ax.focusedWindowID()
            var id: WindowID?
            if name == "floating" {
                id = windows.first { !self.isTiled($0) }?.id
            } else if let ws = self.workspaces.values.first(where: { focused.map($0.contains) ?? false }) ?? self.workspaces.values.first {
                let c = ws.containers[ws.focusedContainerIndex]
                let n = c.windows.count
                if name == "next", n > 1 { id = c.windows[(c.focusedIndex + 1) % n] }
                if name == "previous", n > 1 { id = c.windows[(c.focusedIndex - 1 + n) % n] }
                if name.hasPrefix("container"), let i = Int(name.dropFirst("container".count)), ws.containers.indices.contains(i - 1) {
                    id = ws.containers[i - 1].focusedWindow
                }
            }
            let order = AXWindows.frontToBackFrames()
            var target: (id: WindowID, point: CGPoint)?
            if let id, let frame = order.first(where: { $0.id == id })?.frame {
                // The visible point nearest to the center of the window.
                var best = CGFloat.infinity
                for x in stride(from: frame.minX + 3, to: frame.maxX - 3, by: 6) {
                    for y in stride(from: frame.minY + 3, to: frame.maxY - 3, by: 6) {
                        let d = hypot(x - frame.midX, y - frame.midY)
                        if d < best, !isCovered(CGRect(x: x, y: y, width: 1, height: 1), window: id, frontToBack: order) {
                            best = d
                            target = (id, CGPoint(x: x, y: y))
                        }
                    }
                }
            }
            DispatchQueue.main.async { completion(target) }
        }
    }

    private let overlayQueue = DispatchQueue(label: "tiller.overlay", qos: .userInteractive)

    /// Reads what the leader key overlay shows. The Accessibility calls run on `overlayQueue`, so they don't delay an action.
    /// Call on the main thread. `completion` runs on the main thread.
    /// After an action, `syncFocus` is false: the other app can apply the focus change after the overlay reads the focused window.
    func overlayScreens(syncFocus: Bool = true, completion: @escaping ([OverlayScreen]) -> Void) {
        let screens = ScreenInfo.all()
        overlayQueue.async {
            let (workspaces, floated) = self.queue.sync { (self.workspaces, self.floated) }
            let windows = self.ax.windows()
            let refs = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let focused = self.ax.focusedWindowID()
            let isTiled = { (ref: WindowRef) in ref.kind == .tiled && !floated.contains(ref.id) }
            func appName(_ pid: pid_t) -> String { NSRunningApplication(processIdentifier: pid)?.localizedName ?? "" }
            let order = AXWindows.frontToBackFrames()
            var hidden = 0
            var result: [OverlayScreen] = []
            for screen in screens {
                var item = OverlayScreen(uuid: screen.uuid, frame: screen.frame, spacing: Spacing.standard.carouselSpacing)
                if var ws = workspaces[screen.uuid] {
                    Self.removeClosed(&ws, refs: refs)
                    if syncFocus, let focused { ws.focus(window: focused) }
                    for (i, c) in ws.containers.enumerated() {
                        item.containers.append(.init(id: i, frame: c.frame, axis: c.axis, windowCount: c.windows.count,
                                                     focused: i == ws.focusedContainerIndex))
                        let n = c.windows.count
                        for (j, id) in c.windows.enumerated() {
                            guard let ref = refs[id] else { continue }
                            let place: OverlayScreen.Place
                            if j == c.focusedIndex { place = .front }
                            else if n == 2 || j == (c.focusedIndex + 1) % n { place = .endEdge }
                            else if j == (c.focusedIndex - 1 + n) % n { place = .startEdge }
                            else { continue }  // Fully behind the focused window.
                            item.windows.append(.init(id: id, frame: ref.frame, appName: appName(ref.pid), pid: ref.pid,
                                                      floating: false, place: place, axis: c.axis))
                        }
                    }
                }
                for ref in windows where !isTiled(ref) && screen.frame.contains(CGPoint(x: ref.frame.midX, y: ref.frame.midY)) {
                    item.windows.append(.init(id: ref.id, frame: ref.frame, appName: appName(ref.pid), pid: ref.pid,
                                              floating: true, place: .front, axis: .horizontal))
                }
                // A pill is shown only over its own window. When another window overlaps a part of the pill,
                // for example a tiled window in front of a floating window, the pill isn't shown.
                let s = item.spacing
                let nameFont = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 10)]
                item.windows.removeAll { w in
                    let f = w.frame
                    let edge: CGFloat = 18  // The app icon pill.
                    let pill: CGRect
                    switch (w.place, w.axis) {
                    case (.front, _):
                        // Icon, state, `f` key, spacing and padding: 120 points. The app name is at most 110 points wide.
                        let width = min((w.appName as NSString).size(withAttributes: nameFont).width, 110) + 120
                        pill = CGRect(x: f.maxX - 6 - width, y: f.maxY - 6 - 22, width: width, height: 22)
                    case (.startEdge, .horizontal): pill = CGRect(x: f.minX + (s - edge) / 2, y: f.maxY - 6 - edge, width: edge, height: edge)
                    case (.endEdge, .horizontal): pill = CGRect(x: f.maxX - (s + edge) / 2, y: f.maxY - 6 - edge, width: edge, height: edge)
                    case (.startEdge, .vertical): pill = CGRect(x: f.maxX - 6 - edge, y: f.minY + (s - edge) / 2, width: edge, height: edge)
                    case (.endEdge, .vertical): pill = CGRect(x: f.maxX - 6 - edge, y: f.maxY - (s + edge) / 2, width: edge, height: edge)
                    }
                    let covered = isCovered(pill, window: w.id, frontToBack: order)
                    if covered { hidden += 1 }
                    return covered
                }
                if !item.containers.isEmpty || !item.windows.isEmpty { result.append(item) }
            }
            Log.write("overlay pills=\(result.map(\.windows.count).reduce(0, +)) coveredHidden=\(hidden)")
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Moves each window of each workspace to its frame in its container. Call on the main thread.
    func rearrange() {
        queue.async {
            let refs = Dictionary(self.ax.windows().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for (uuid, var ws) in self.workspaces {
                Self.removeClosed(&ws, refs: refs)
                self.workspaces[uuid] = ws
                let changed = ws.windowFrames().filter { refs[$0.key]?.frame != $0.value }
                self.ax.setFrames(changed, refs: refs)
                Log.write("rearrange screen=\(uuid) moved=\(changed.count)")
            }
        }
    }

    private static func screen(of window: WindowID?, refs: [WindowID: WindowRef], screens: [ScreenInfo]) -> ScreenInfo? {
        guard let window, let frame = refs[window]?.frame else { return nil }
        return screens.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }
    }

    private func isTiled(_ ref: WindowRef) -> Bool { ref.kind == .tiled && !floated.contains(ref.id) }

    private func run(_ action: Action, received: DispatchTime, screens: [ScreenInfo], mouseScreen: ScreenInfo?, completion: (() -> Void)?) {
        let windows = ax.windows()
        let refs = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        floated.formIntersection(refs.keys)
        untiledFrames = untiledFrames.filter { refs[$0.key] != nil }
        let focused = ax.focusedWindowID()
        guard let screen = Self.screen(of: focused, refs: refs, screens: screens) ?? mouseScreen else { return }

        var ws: Workspace
        var before: [WindowID: CGRect]
        var expectedFocused: WindowID?
        var note = ""
        /// The frame of a window that the `f` key floats.
        var floatFrame: CGRect?
        /// For the focus log line: the focused window in the stored workspace, and the focused window and ring index after the sync with the system focused window.
        var storedFocused: WindowID?
        var startFocused: WindowID?
        var startIndex = 0
        switch action {
        case .layout(let kind):
            ws = Workspace(displayID: screen.uuid, desktop: screen.desktop)
            ws.savedAxes = workspaces[screen.uuid]?.savedAxes ?? [:]
            let onScreen = windows.filter { isTiled($0) && screen.frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
            ws.apply(kind, windows: onScreen.map(\.id), focused: focused)
            before = Dictionary(onScreen.map { ($0.id, $0.frame) }, uniquingKeysWith: { a, _ in a })
            for ref in onScreen where untiledFrames[ref.id] == nil { untiledFrames[ref.id] = ref.frame }
            expectedFocused = ws.focusedWindow
            note = ws.containers.map(\.axis.rawValue).joined(separator: "-")
        case .focusWindow(let offset), .focusContainer(let offset):
            guard let existing = workspaces[screen.uuid] else { return }
            ws = existing
            Self.removeClosed(&ws, refs: refs)
            storedFocused = ws.focusedWindow
            if let focused { ws.focus(window: focused) }
            startFocused = ws.focusedWindow
            startIndex = ws.containers[ws.focusedContainerIndex].focusedIndex
            before = ws.windowFrames()
            if case .focusWindow = action { ws.focusWindow(offset: offset) } else { ws.focusContainer(offset: offset) }
            expectedFocused = ws.focusedWindow
        case .toggleFloat:
            guard let existing = workspaces[screen.uuid], let focused, let ref = refs[focused] else { return }
            ws = existing
            Self.removeClosed(&ws, refs: refs)
            before = ws.windowFrames()
            if ws.contains(focused) {
                ws.remove(focused)
                floated.insert(focused)
                floatFrame = untiledFrames[focused].flatMap { $0.intersects(ws.frame) ? $0 : nil }
                    ?? ws.frame.insetBy(dx: ws.frame.width * 0.2, dy: ws.frame.height * 0.2)
                note = "floated"
            } else if floated.contains(focused) {
                floated.remove(focused)
                ws.insert(focused)
                before[focused] = ref.frame
                note = "tiled"
            } else {
                // The window rule floats this window, for example because its size can't be set.
                note = "not-tileable"
            }
            // Focus stays on the window that was floated or tiled.
            expectedFocused = focused
        case .toggleAxis:
            guard let existing = workspaces[screen.uuid] else { return }
            ws = existing
            Self.removeClosed(&ws, refs: refs)
            if let focused { ws.focus(window: focused) }
            before = ws.windowFrames()
            ws.toggleAxis()
            expectedFocused = ws.focusedWindow
            note = ws.containers[ws.focusedContainerIndex].axis.rawValue
        case .turnOff:
            return
        case .raiseFloating:
            ws = workspaces[screen.uuid] ?? Workspace(displayID: screen.uuid, desktop: screen.desktop)
            before = ws.windowFrames()
            let pid = focused.flatMap { refs[$0]?.pid } ?? NSWorkspace.shared.frontmostApplication?.processIdentifier
            // Raised back to front, so that the front floating window stays in front and gets focus.
            let floating = windows.filter { $0.pid == pid && !isTiled($0) }.reversed()
            ax.raise(Array(floating))
            expectedFocused = floating.last?.id ?? focused
            note = "raised=\(floating.count)"
        }
        workspaces[screen.uuid] = ws

        let target = ws.windowFrames()
        var changed = target.filter { before[$0.key] != $0.value }
        if let floatFrame, let focused { changed[focused] = floatFrame }
        ax.setFrames(changed, refs: refs)
        var raised: WindowID?
        var axResult = "none"
        if case .raiseFloating = action {
        } else if let id = expectedFocused, let ref = refs[id], id != focused || changed[id] != nil {
            axResult = ax.focus(ref)
            raised = id
        }

        let latencyMs = Double(DispatchTime.now().uptimeNanoseconds - received.uptimeNanoseconds) / 1_000_000
        let name = Self.name(action) + (note.isEmpty ? "" : ":\(note)")
        Log.write("action=\(name) screen=\(screen.uuid) layout=\(ws.layout.rawValue) moved=\(changed.count) latencyMs=\(String(format: "%.2f", latencyMs))")
        switch action {
        case .focusWindow, .focusContainer:
            // Written 150 ms later on another queue: the other app applies the focus change after the Accessibility call returns.
            let container = ws.containers[ws.focusedContainerIndex]
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.15) { [ax] in
                func label(_ id: WindowID?) -> String {
                    guard let id else { return "none" }
                    let app = refs[id].flatMap { NSRunningApplication(processIdentifier: $0.pid)?.bundleIdentifier } ?? "?"
                    return "\(app):\(id)"
                }
                Log.write("focus action=\(name) order=[\(container.windows.map(label).joined(separator: ","))] storedFocused=\(label(storedFocused)) systemFocusedBefore=\(label(focused)) index=\(startIndex)->\(container.focusedIndex) from=\(label(startFocused)) raised=\(label(raised)) ax=\(axResult) systemFocusedAfter=\(label(ax.focusedWindowID())) frontmostApp=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")")
            }
        default:
            break
        }

        if let completion { DispatchQueue.main.async(execute: completion) }
        guard onReport != nil else { return }
        // Focus changes are applied by the other app after the Accessibility call returns.
        // `asyncAfter` keeps `queue` free, so that the overlay update after the action isn't delayed.
        queue.asyncAfter(deadline: .now() + 0.15) {
            self.onReport?(self.report(name, ws, refs: refs, latencyMs: latencyMs, moved: changed.count, expectedFocused: expectedFocused))
        }
    }

    private static func removeClosed(_ ws: inout Workspace, refs: [WindowID: WindowRef]) {
        for container in ws.containers {
            for id in container.windows where refs[id] == nil { ws.remove(id) }
        }
    }

    private func report(_ action: String, _ ws: Workspace, refs: [WindowID: WindowRef], latencyMs: Double, moved: Int,
                        expectedFocused: WindowID?) -> ActionReport {
        let target = ws.windowFrames()
        var windows: [ActionReport.Window] = []
        for (index, container) in ws.containers.enumerated() {
            for id in container.windows {
                guard let ref = refs[id], let expected = target[id] else { continue }
                windows.append(.init(id: id, title: ref.title, container: index,
                                     expected: Rect(expected), actual: ref.element.frame.map(Rect.init)))
            }
        }
        let floating = refs.values.filter { !isTiled($0) }.sorted { $0.id < $1.id }.map {
            ActionReport.Window(id: $0.id, title: $0.title, container: -1, expected: Rect($0.frame), actual: $0.element.frame.map(Rect.init))
        }
        return ActionReport(action: action, latencyMs: latencyMs, movedWindows: moved, layout: ws.layout.rawValue,
                            expectedFocused: expectedFocused, actualFocused: ax.focusedWindowID(), windows: windows, floating: floating)
    }

    private static func name(_ action: Action) -> String {
        switch action {
        case .layout(let kind): "layout:\(kind.rawValue)"
        case .focusWindow(let offset): offset > 0 ? "focus-next-window" : "focus-previous-window"
        case .focusContainer(let offset): offset > 0 ? "focus-next-container" : "focus-previous-container"
        case .toggleFloat: "toggle-float"
        case .toggleAxis: "toggle-axis"
        case .raiseFloating: "raise-floating"
        case .turnOff: "turn-off"
        }
    }
}
