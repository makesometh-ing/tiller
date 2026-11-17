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
    /// The time of Tiller's last focus call. Read and written on `queue`.
    private var lastFocusCall = DispatchTime(uptimeNanoseconds: 0)
    private var focusRetryScheduled = false
    /// Each window from the last window list read on `queue`. The element of a window that is removed from its carousel is read from here.
    private var known: [WindowID: WindowRef] = [:]
    /// True from a window notification until `queue` starts the window sync for it. Notifications in that time use the same sync.
    private var syncPending = false
    private let syncLock = NSLock()
    /// The latency and the moved window count of the last window sync. The proof runner reads it. Read and written on `queue`.
    private var lastWindowChange: (latencyMs: Double, moved: Int)?

    init(ax: AXWindows) { self.ax = ax }

    /// Call on the main thread. `completion` runs on the main thread after the windows are moved and focused. An action that doesn't change a workspace doesn't call it.
    func perform(_ action: Action, received: DispatchTime, completion: (() -> Void)? = nil) {
        let screens = ScreenInfo.all()
        let mouseScreen = ScreenInfo.underMouse(in: screens)
        queue.async {
            self.run(action, received: received, screens: screens, mouseScreen: mouseScreen, completion: completion)
        }
    }

    /// Call on the main thread after a focus change notification. `clicked` is the time of the last mouse down.
    func focusChanged(clicked: DispatchTime?) {
        let notified = DispatchTime.now()
        let screens = ScreenInfo.all()
        queue.async { self.syncFocus(notified: notified, clicked: clicked, screens: screens) }
    }

    /// Call on the main thread after a window opens, closes, is minimized or unminimized, or after an app is hidden, shown, launched or quit.
    func windowsChanged(trigger: String) {
        let notified = DispatchTime.now()
        let screens = ScreenInfo.all()
        guard syncLock.withLock({ defer { syncPending = true }; return !syncPending }) else { return }
        queue.async {
            self.syncLock.withLock { self.syncPending = false }
            self.syncWindows(trigger: trigger, notified: notified, screens: screens, retry: true)
        }
    }

    /// Removes closed, minimized and hidden windows from their carousels, puts unminimized and shown windows back at their
    /// ring position, and puts each new tiled window into the focused container after the focused window. Then sets the frames of the changed carousels.
    /// A window can be on the screen a short time after its notification. When nothing changed, the windows are read again 0.25 seconds later if `retry` is true.
    private func syncWindows(trigger: String, notified: DispatchTime, screens: [ScreenInfo], retry: Bool) {
        guard !workspaces.isEmpty else { return }
        let t = DispatchTime.now()
        let windows = ax.windows()
        let windowListMs = Log.ms(since: t)
        let refs = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let before = workspaces.mapValues { $0.windowFrames() }
        let removed = removeGone(refs: refs)
        let focused = ax.focusedWindowID()
        let untracked = windows.filter { ref in isTiled(ref) && !workspaces.values.contains { $0.contains(ref.id) } }
        var restored: [WindowID] = []
        for uuid in workspaces.keys {
            let saved = workspaces[uuid]!.savedPositions
            for id in workspaces[uuid]!.restore(untracked.map(\.id)) {
                restored.append(id)
                let p = workspaces[uuid]!.position(of: id)
                Log.event(.windowRestored, Self.fields(refs[id], id: id, screen: uuid, position: p).merging(
                    ["sameContainer": .bool(p?.container == saved[id]?.container && p?.layout == saved[id]?.layout)]) { $1 })
            }
        }
        // An unminimized window and the focused window of a shown app usually get focus. Until 1 second after Tiller's
        // last focus call, the system focused window can be the window that had focus before, so it isn't read.
        if removed + restored.count > 0, DispatchTime.now() >= lastFocusCall + 1.0, let focused,
           let uuid = workspaces.first(where: { $0.value.contains(focused) })?.key {
            workspaces[uuid]!.focus(window: focused)
        }
        var opened: [WindowRef] = []
        for ref in untracked where !restored.contains(ref.id) {
            guard let uuid = Self.screen(of: ref.id, refs: refs, screens: screens)?.uuid, workspaces[uuid] != nil else { continue }
            workspaces[uuid]!.insert(ref.id)
            if untiledFrames[ref.id] == nil { untiledFrames[ref.id] = ref.frame }
            opened.append(ref)
            Log.event(.windowOpened, Self.fields(ref, id: ref.id, screen: uuid, position: workspaces[uuid]!.position(of: ref.id)))
        }
        guard removed + restored.count + opened.count > 0 else {
            if retry {
                queue.asyncAfter(deadline: .now() + 0.25) { self.syncWindows(trigger: trigger, notified: notified, screens: screens, retry: false) }
            }
            return
        }
        var changed: [WindowID: CGRect] = [:]
        for (uuid, ws) in workspaces {
            for (id, frame) in ws.windowFrames() where (before[uuid]?[id] ?? refs[id]?.frame) != frame { changed[id] = frame }
        }
        let setFramesMs = ax.setFrames(changed, refs: refs)
        let focusStart = DispatchTime.now()
        // A new window gets focus from its app. Tiller gives it focus when its app doesn't.
        if let ref = opened.last, ref.id != focused {
            ax.focus(ref)
            lastFocusCall = .now()
        }
        let focusMs = Log.ms(since: focusStart)
        let latencyMs = Double(DispatchTime.now().uptimeNanoseconds - notified.uptimeNanoseconds) / 1e6
        lastWindowChange = (latencyMs, changed.count)
        Self.logAction(["action": "window-change", "trigger": .string(trigger), "opened": .int(opened.count), "restored": .int(restored.count),
                        "removed": .int(removed), "moved": .int(changed.count), "windowListMs": windowListMs, "setFramesMs": setFramesMs,
                        "focusMs": focusMs, "totalMs": .ms(latencyMs)], totalMs: latencyMs)
        checkFrames(changed, refs: refs)
    }

    /// The fields of `window.opened`, `window.closed`, `window.removed` and `window.restored`. The container is 1-based. The ring index is 0-based.
    private static func fields(_ ref: WindowRef?, id: WindowID, screen: String, position: RingPosition?) -> [String: LogValue] {
        ["windowId": .int(Int(id)), "bundleId": .string(ref.flatMap { NSRunningApplication(processIdentifier: $0.pid)?.bundleIdentifier } ?? ""),
         "screen": .string(screen), "container": position.map { .int($0.container + 1) } ?? .null, "ringIndex": position.map { .int($0.index) } ?? .null]
    }

    /// Makes the system focused window the focused window of its carousel and its container, and sets the frames
    /// of the carousel, as `H`, `L`, `J` and `K` do. A focus change made by Tiller doesn't change the workspace,
    /// because the window that gets focus is already the focused window of the workspace.
    private func syncFocus(notified: DispatchTime, clicked: DispatchTime?, screens: [ScreenInfo]) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier != getpid(),
              let focused = ax.focusedWindowID(),
              !workspaces.values.contains(where: { $0.focusedWindow == focused }) else { return }
        guard let uuid = workspaces.first(where: { $0.value.contains(focused) })?.key else {
            // A window of an app that opened before the app was observed gets focus.
            syncWindows(trigger: "focusChanged", notified: notified, screens: screens, retry: false)
            return
        }
        // Some apps apply Tiller's focus call late. Until then, the system focused window is the window that had focus before.
        // A focus change without a click after Tiller's last focus call is read again 1 second after that call.
        let settled = lastFocusCall + 1.0
        if clicked.map({ $0 < lastFocusCall }) ?? true, DispatchTime.now() < settled {
            guard !focusRetryScheduled else { return }
            focusRetryScheduled = true
            queue.asyncAfter(deadline: settled) {
                self.focusRetryScheduled = false
                self.syncFocus(notified: notified, clicked: clicked, screens: screens)
            }
            return
        }
        let t = DispatchTime.now()
        let refs = Dictionary(ax.windows().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let windowListMs = Log.ms(since: t)
        let before = workspaces[uuid]?.windowFrames() ?? [:]
        removeGone(refs: refs)
        guard var ws = workspaces[uuid] else { return }
        ws.focus(window: focused)
        workspaces[uuid] = ws
        let changed = ws.windowFrames().filter { before[$0.key] != $0.value }
        let setFramesMs = ax.setFrames(changed, refs: refs)
        checkFrames(changed, refs: refs)
        // The latency is measured from the click when the click is less than 1 second before the notification.
        let click = clicked.flatMap { $0 <= notified && notified.uptimeNanoseconds - $0.uptimeNanoseconds < 1_000_000_000 ? $0 : nil }
        let ms = { (t: DispatchTime) in Double(DispatchTime.now().uptimeNanoseconds - t.uptimeNanoseconds) / 1e6 }
        let latencyMs = ms(click ?? notified)
        lastFocusChange = (latencyMs, changed.count)
        // `totalMs` is from the click, or from the notification when the focus change wasn't a click.
        Self.logAction(["action": "focus-change", "trigger": click == nil ? "other" : "click", "screen": .string(uuid),
                        "layout": .string(ws.layout.rawValue), "container": .int(ws.focusedContainerIndex + 1), "moved": .int(changed.count),
                        "notificationMs": click.map { .ms(Double(notified.uptimeNanoseconds - $0.uptimeNanoseconds) / 1e6) } ?? .null,
                        "windowListMs": windowListMs, "setFramesMs": setFramesMs, "totalMs": .ms(latencyMs)], totalMs: latencyMs)
    }

    /// The latency and the moved window count of the last arrangement after a focus change. The proof runner reads it. Read and written on `queue`.
    private var lastFocusChange: (latencyMs: Double, moved: Int)?

    /// Call on the main thread. `expectedFocused` is the system focused window when nil, or the focused window of the workspace when `workspaceFocus` is true.
    func reportCurrentState(action: String, latencyMs: Double = 0, expectedFocused: WindowID? = nil, workspaceFocus: Bool = false) {
        guard onReport != nil else { return }
        let screens = ScreenInfo.all()
        let mouseScreen = ScreenInfo.underMouse(in: screens)
        queue.async {
            let refs = Dictionary(self.ax.windows().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let focused = self.ax.focusedWindowID()
            guard let screen = Self.screen(of: focused, refs: refs, screens: screens) ?? mouseScreen,
                  let ws = self.workspaces[screen.uuid] else { return }
            // After a click, the report gives the latency of the arrangement that the click caused.
            // After a window step, the report gives the latency of the window sync.
            let change = action.hasPrefix("click:") ? self.lastFocusChange
                : action.hasPrefix("window:") || action.hasPrefix("app:") ? self.lastWindowChange : nil
            self.lastFocusChange = nil
            self.lastWindowChange = nil
            self.onReport?(self.report(action, ws, refs: refs, latencyMs: change?.latencyMs ?? latencyMs, moved: change?.moved ?? 0,
                                       expectedFocused: expectedFocused ?? (workspaceFocus ? ws.focusedWindow : focused)))
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
                // The visible point nearest to the center of the window, 8 points or more from the edge of a window in front.
                // A click near the edge of the focused window resizes that window.
                var best = CGFloat.infinity
                for x in stride(from: frame.minX + 8, to: frame.maxX - 8, by: 2) {
                    for y in stride(from: frame.minY + 8, to: frame.maxY - 8, by: 6) {
                        let d = hypot(x - frame.midX, y - frame.midY)
                        if d < best, !isCovered(CGRect(x: x - 8, y: y - 8, width: 16, height: 16), window: id, frontToBack: order) {
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
    /// `completion` gets the screens and the number of pills hidden because another window covers them.
    func overlayScreens(syncFocus: Bool = true, completion: @escaping ([OverlayScreen], Int) -> Void) {
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
                    for id in ws.containers.flatMap(\.windows) where refs[id] == nil { ws.remove(id) }
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
            DispatchQueue.main.async { completion(result, hidden) }
        }
    }

    /// The workspace of each screen and the floating windows, for the diagnostics zip. Window titles aren't included.
    /// Don't call it on `queue`.
    func workspaceState() -> LogValue {
        queue.sync {
            let refs = Dictionary(ax.windows().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            func window(_ id: WindowID) -> LogValue {
                let ref = refs[id]
                return ["windowId": .int(Int(id)),
                        "bundleId": .string(ref.flatMap { NSRunningApplication(processIdentifier: $0.pid)?.bundleIdentifier } ?? ""),
                        "frame": ref.map { .frame($0.frame) } ?? .null]
            }
            let spaces: [LogValue] = workspaces.values.sorted { $0.displayID < $1.displayID }.map { ws in
                ["screen": .string(ws.displayID), "layout": .string(ws.layout.rawValue), "focusedContainer": .int(ws.focusedContainerIndex + 1),
                 "containers": .array(ws.containers.map { c in
                     ["frame": .frame(c.frame), "axis": .string(c.axis.rawValue), "focusedIndex": .int(c.focusedIndex),
                      "windows": .array(c.windows.map(window))]
                 }),
                 "savedAxes": .object(Dictionary(uniqueKeysWithValues: ws.savedAxes.map { ($0.key.rawValue, .array($0.value.map { .string($0.rawValue) })) }))]
            }
            return ["workspaces": .array(spaces),
                    "floating": .array(refs.values.filter { !isTiled($0) }.sorted { $0.id < $1.id }.map { window($0.id) }),
                    "floatedWithF": .array(floated.sorted().map { .int(Int($0)) })]
        }
    }

    /// Moves each window of each workspace to its frame in its container. Call on the main thread.
    func rearrange() {
        queue.async {
            let refs = Dictionary(self.ax.windows().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            self.removeGone(refs: refs)
            for (uuid, ws) in self.workspaces {
                let changed = ws.windowFrames().filter { refs[$0.key]?.frame != $0.value }
                let start = DispatchTime.now()
                let setFramesMs = self.ax.setFrames(changed, refs: refs)
                Log.event(.actionDone, ["action": "rearrange", "screen": .string(uuid), "layout": .string(ws.layout.rawValue),
                                        "moved": .int(changed.count), "setFramesMs": setFramesMs, "totalMs": Log.ms(since: start)])
                self.checkFrames(changed, refs: refs)
            }
        }
    }

    private static func screen(of window: WindowID?, refs: [WindowID: WindowRef], screens: [ScreenInfo]) -> ScreenInfo? {
        guard let window, let frame = refs[window]?.frame else { return nil }
        return screens.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }
    }

    private func isTiled(_ ref: WindowRef) -> Bool { ref.kind == .tiled && !floated.contains(ref.id) }

    private func run(_ action: Action, received: DispatchTime, screens: [ScreenInfo], mouseScreen: ScreenInfo?, completion: (() -> Void)?) {
        var t = DispatchTime.now()
        let windows = ax.windows()
        let windowListMs = Log.ms(since: t)
        let refs = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        floated.formIntersection(refs.keys)
        untiledFrames = untiledFrames.filter { refs[$0.key] != nil }
        t = .now()
        let focused = ax.focusedWindowID()
        let focusReadMs = Log.ms(since: t)
        guard let screen = Self.screen(of: focused, refs: refs, screens: screens) ?? mouseScreen else { return }
        let storedFrames = workspaces[screen.uuid]?.windowFrames() ?? [:]
        removeGone(refs: refs)

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
            ws.savedPositions = workspaces[screen.uuid]?.savedPositions ?? [:]
            let onScreen = windows.filter { isTiled($0) && screen.frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
            ws.apply(kind, windows: onScreen.map(\.id), focused: focused)
            before = Dictionary(onScreen.map { ($0.id, $0.frame) }, uniquingKeysWith: { a, _ in a })
            for ref in onScreen where untiledFrames[ref.id] == nil { untiledFrames[ref.id] = ref.frame }
            expectedFocused = ws.focusedWindow
            note = ws.containers.map(\.axis.rawValue).joined(separator: "-")
        case .focusWindow(let offset), .focusContainer(let offset):
            guard let existing = workspaces[screen.uuid] else { return }
            ws = existing
            storedFocused = ws.focusedWindow
            if let focused { ws.focus(window: focused) }
            startFocused = ws.focusedWindow
            startIndex = ws.containers[ws.focusedContainerIndex].focusedIndex
            before = storedFrames
            if case .focusWindow = action { ws.focusWindow(offset: offset) } else { ws.focusContainer(offset: offset) }
            expectedFocused = ws.focusedWindow
        case .toggleFloat:
            guard let existing = workspaces[screen.uuid], let focused, let ref = refs[focused] else { return }
            ws = existing
            before = storedFrames
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
            if let focused { ws.focus(window: focused) }
            before = storedFrames
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
            lastFocusCall = .now()
            expectedFocused = floating.last?.id ?? focused
            note = "raised=\(floating.count)"
        }
        workspaces[screen.uuid] = ws

        let target = ws.windowFrames()
        var changed = target.filter { before[$0.key] != $0.value }
        if let floatFrame, let focused { changed[focused] = floatFrame }
        let setFramesMs = ax.setFrames(changed, refs: refs)
        var raised: WindowID?
        var axResult = "none"
        t = .now()
        if case .raiseFloating = action {
        } else if let id = expectedFocused, let ref = refs[id], id != focused || changed[id] != nil {
            axResult = ax.focus(ref)
            lastFocusCall = .now()
            raised = id
        }
        let focusMs = Log.ms(since: t)

        let latencyMs = Double(DispatchTime.now().uptimeNanoseconds - received.uptimeNanoseconds) / 1_000_000
        let name = Self.name(action) + (note.isEmpty ? "" : ":\(note)")
        Self.logAction(["action": .string(name), "screen": .string(screen.uuid), "layout": .string(ws.layout.rawValue), "moved": .int(changed.count),
                        "windowListMs": windowListMs, "focusReadMs": focusReadMs, "setFramesMs": setFramesMs, "focusMs": focusMs,
                        "totalMs": .ms(latencyMs)], totalMs: latencyMs)
        checkFrames(changed, refs: refs)
        switch action {
        case .focusWindow, .focusContainer:
            // Written 150 ms later on another queue: the other app applies the focus change after the Accessibility call returns.
            let container = ws.containers[ws.focusedContainerIndex]
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.15) { [ax] in
                func label(_ id: WindowID?) -> LogValue {
                    guard let id else { return .null }
                    let app = refs[id].flatMap { NSRunningApplication(processIdentifier: $0.pid)?.bundleIdentifier } ?? "?"
                    return .string("\(app):\(id)")
                }
                Log.event(.actionFocus, [
                    "action": .string(name), "order": .array(container.windows.map(label)), "storedFocused": label(storedFocused),
                    "titles": .array(container.windows.map { .string(refs[$0]?.title ?? "") }),
                    "systemFocusedBefore": label(focused), "indexBefore": .int(startIndex), "indexAfter": .int(container.focusedIndex),
                    "from": label(startFocused), "raised": label(raised), "ax": .string(axResult),
                    "systemFocusedAfter": label(ax.focusedWindowID()),
                    "frontmostApp": .string(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"),
                ])
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

    /// Removes the windows that `refs` doesn't contain from their carousels, and writes `window.closed` or `window.removed` for each.
    /// The ring position of a minimized window, a window of a hidden app and a window that is still open but not on the screen
    /// is saved. Returns the number of removed windows. Then `known` is set to `refs`.
    @discardableResult
    private func removeGone(refs: [WindowID: WindowRef]) -> Int {
        var count = 0
        for (uuid, var ws) in workspaces {
            let gone = ws.containers.flatMap(\.windows).filter { refs[$0] == nil }
            guard !gone.isEmpty else { continue }
            let reasons = Dictionary(uniqueKeysWithValues: gone.map { ($0, Self.removalReason(known[$0])) })
            for id in gone {
                Log.event(reasons[id] == "closed" ? .windowClosed : .windowRemoved,
                          Self.fields(known[id], id: id, screen: uuid, position: ws.position(of: id)).merging(["reason": .string(reasons[id]!)]) { $1 })
            }
            ws.removeSavingPositions(gone.filter { reasons[$0] != "closed" })
            for id in gone where reasons[id] == "closed" { ws.remove(id) }
            workspaces[uuid] = ws
            count += gone.count
        }
        known = refs
        return count
    }

    /// `closed`, `appHidden`, `minimized`, or `notOnScreen` for a window on another Space or a window that isn't tiled now.
    private static func removalReason(_ ref: WindowRef?) -> String {
        guard let ref, let app = NSRunningApplication(processIdentifier: ref.pid), !app.isTerminated else { return "closed" }
        if app.isHidden { return "appHidden" }
        if ref.element.value(kAXMinimizedAttribute) as? Bool == true { return "minimized" }
        return ref.element.value(kAXRoleAttribute) == nil ? "closed" : "notOnScreen"
    }

    /// Writes `action.done`, and `action.slow` when the action took more than 100 ms.
    private static func logAction(_ fields: [String: LogValue], totalMs: Double) {
        Log.event(.actionDone, fields)
        if totalMs > 100 { Log.event(.actionSlow, fields) }
    }

    /// Reads the frames of the moved windows 150 ms later, on another queue, and writes `window.frameMismatch`
    /// for each frame that differs from its target by more than 1 point. Some apps have a minimum size or move their windows back.
    private func checkFrames(_ targets: [WindowID: CGRect], refs: [WindowID: WindowRef]) {
        guard !targets.isEmpty else { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.15) {
            for (id, target) in targets {
                guard let ref = refs[id], let actual = ref.element.frame, !Rect(actual).matches(Rect(target)) else { continue }
                Log.event(.windowFrameMismatch, ["bundleId": .string(NSRunningApplication(processIdentifier: ref.pid)?.bundleIdentifier ?? ""),
                                                 "windowId": .int(Int(id)), "target": .frame(target), "actual": .frame(actual)])
            }
        }
    }

    private func report(_ action: String, _ ws: Workspace, refs: [WindowID: WindowRef], latencyMs: Double, moved: Int,
                        expectedFocused: WindowID?) -> ActionReport {
        let target = ws.windowFrames()
        var windows: [ActionReport.Window] = []
        for (index, container) in ws.containers.enumerated() {
            for id in container.windows {
                guard let ref = refs[id], let expected = target[id] else { continue }
                windows.append(.init(id: id, title: ref.title, container: index, expected: Rect(expected), actual: ref.element.frame.map(Rect.init),
                                     bundleID: NSRunningApplication(processIdentifier: ref.pid)?.bundleIdentifier))
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
