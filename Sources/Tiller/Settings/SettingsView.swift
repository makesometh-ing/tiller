import AppKit
import SwiftUI
import TillerCore

/// Which shortcut field records now. Only one field records at a time.
enum RecordTarget: Equatable {
    case leader
    case toggle
    /// The key of an action in leader key mode.
    case action(ActionID)
    /// The global shortcut of an action.
    case global(ActionID)

    /// Keys in leader key mode aren't global shortcuts, so they return nil.
    var globalSlot: GlobalSlot? {
        switch self {
        case .leader: .leader
        case .toggle: .toggle
        case .global(let id): .action(id)
        case .action: nil
        }
    }
}

extension GlobalSlot {
    var title: String {
        switch self {
        case .leader: "Leader key"
        case .toggle: "Turn Tiller on and off"
        case .action(let id): id.title
        }
    }
}

/// The action shortcuts that the Shortcuts page shows: the keys in leader key mode or the global shortcuts.
enum ShortcutsMode: String, CaseIterable, Identifiable {
    case leader, global
    var id: String { rawValue }
    var title: String { self == .leader ? "Leader key mode" : "Global" }
}

/// State of the settings window. Read and written on the main thread.
final class SettingsModel: ObservableObject {
    let store: ShortcutStore
    let leaderKey: LeaderKey
    @Published var page: SettingsPage = .general {
        didSet { if page == .about { readLogFiles() } }
    }
    /// The log folder, the file count and the total size, for example `~/Library/Logs/Tiller · 3 files · 2.1 MB`.
    @Published private(set) var logFiles = ""
    @Published private(set) var exporting = false
    /// Writes the diagnostics zip to the Desktop and shows it in Finder. Set by the app delegate. It calls `completion` on the main thread.
    var exportDiagnostics: (_ completion: @escaping () -> Void) -> Void = { $0() }
    @Published private(set) var recording: RecordTarget?
    @Published var shortcutsMode: ShortcutsMode = .leader
    /// A field that didn't save the recorded chord, and the text that the field shows for 2 seconds.
    @Published private(set) var refused: (target: RecordTarget, text: String)?

    init(store: ShortcutStore, leaderKey: LeaderKey) {
        self.store = store
        self.leaderKey = leaderKey
    }

    /// Starts recording. The event tap passes the next key press to the field. `Esc` cancels.
    func record(_ target: RecordTarget) {
        recording = target
        leaderKey.recorder = { [weak self] chord in
            DispatchQueue.main.async { self?.finish(target, chord) }
        }
    }

    func readLogFiles() {
        let urls = Log.shared.fileURLs
        let bytes = urls.reduce(0) { $0 + ((try? FileManager.default.attributesOfItem(atPath: $1.path)[.size] as? Int) ?? 0) }
        let folder = Log.directory.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        logFiles = "\(folder) · \(urls.count) \(urls.count == 1 ? "file" : "files") · \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
    }

    func export() {
        exporting = true
        exportDiagnostics { [weak self] in
            self?.exporting = false
            self?.readLogFiles()
        }
    }

    func clear(_ target: RecordTarget) {
        if recording == target { cancel() }
        switch target {
        case .leader: store.setLeader(nil)
        case .toggle: store.setToggle(nil)
        case .action(let id): store.set(nil, for: id)
        case .global(let id): store.setGlobal(nil, for: id)
        }
    }

    func cancel() {
        recording = nil
        leaderKey.recorder = nil
    }

    private func finish(_ target: RecordTarget, _ chord: KeyChord?) {
        recording = nil
        guard let chord else { return }
        if let slot = target.globalSlot, let owner = store.shortcuts.conflict(chord, for: slot) {
            refused = (target, owner == slot ? "Add a modifier" : "Used by \(owner.title)")
            Log.event(.settingsChanged, ["setting": "refused", "field": .string(slot.title), "value": .string(chord.spec), "usedBy": .string(owner.title)])
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if self?.refused?.target == target { self?.refused = nil }
            }
            return
        }
        switch target {
        case .leader: store.setLeader(chord)
        case .toggle: store.setToggle(chord)
        case .action(let id): store.set(chord, for: id)
        case .global(let id): store.setGlobal(chord, for: id)
        }
    }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, shortcuts, about
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .shortcuts: "command"
        case .about: "info"
        }
    }
    var color: Color { self == .shortcuts ? Color(white: 0.45) : Color(white: 0.55) }
}

/// The settings window: a sidebar with colored icons and a page of grouped rows.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(model.page.title).font(.system(size: 15, weight: .bold))
                    Spacer()
                    if model.page == .shortcuts {
                        Picker("Shortcuts", selection: $model.shortcutsMode) {
                            ForEach(ShortcutsMode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize().tint(Theme.current.accent)
                    }
                }
                .frame(height: 22).padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 8)
                ScrollView {
                    Group {
                        switch model.page {
                        case .general: GeneralPage(store: model.store)
                        case .shortcuts: ShortcutsPage(model: model, store: model.store)
                        case .about: AboutPage(model: model, store: model.store)
                        }
                    }
                    .padding(.horizontal, 22).padding(.bottom, 22)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 680, height: 600)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            navItem(.general)
            navItem(.shortcuts)
            Spacer()
            navItem(.about)
        }
        .padding(.horizontal, 10).padding(.top, 52).padding(.bottom, 12)
        .frame(width: 190)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func navItem(_ page: SettingsPage) -> some View {
        Button { model.page = page } label: {
            HStack(spacing: 9) {
                Image(systemName: page.symbol)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 22, height: 22).background(page.color, in: RoundedRectangle(cornerRadius: 6))
                Text(page.title)
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(model.page == page ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A group of rows with a rounded background, as in the System Settings forms.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.07)))
    }
}

struct SettingsRow<Accessory: View>: View {
    let title: String
    var showsDivider = true
    @ViewBuilder var accessory: Accessory
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                Spacer()
                accessory
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            if showsDivider { Divider().padding(.leading, 12) }
        }
    }
}

/// A shortcut field, after Rectangle Pro: the keys in a grey field and a clear button.
/// A click starts recording. The field then has a teal edge and shows "Press keys…".
struct ShortcutField: View {
    @ObservedObject var model: SettingsModel
    let target: RecordTarget
    let chord: KeyChord?
    let accessibilityName: String

    var body: some View {
        let theme = Theme.current
        let recording = model.recording == target
        let refused = model.refused.flatMap { $0.target == target ? $0.text : nil }
        HStack(spacing: 6) {
            Button { recording ? model.cancel() : model.record(target) } label: {
                Text(recording ? "Press keys…" : refused ?? chord.map { $0.labels.joined(separator: " ") } ?? "Record shortcut")
                    .font(.system(size: 12, weight: chord == nil || recording || refused != nil ? .regular : .semibold))
                    .foregroundStyle(recording ? theme.accent : refused != nil ? Color.red : (chord == nil ? Color.secondary : Color.primary))
                    .frame(width: 160, height: 24)
                    .background(chord == nil || recording ? Color.primary.opacity(0.05) : Color.primary.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(recording ? theme.accent : .clear, lineWidth: 2))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityName)
            Button { model.clear(target) } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    .frame(width: 16, height: 16).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(chord == nil ? 0 : 1)
            .disabled(chord == nil)
            .accessibilityLabel("Clear \(accessibilityName)")
        }
    }
}

struct SettingsHeader: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 12, weight: .bold)).padding(.top, 10).padding(.leading, 2)
    }
}

/// The first row of the menu bar menu: the shortcut that turns Tiller off and on, and a switch.
struct MenuSwitchRow: View {
    @ObservedObject var store: ShortcutStore

    var body: some View {
        HStack(spacing: 8) {
            Text("Tiller").fontWeight(.semibold)
            Spacer(minLength: 24)
            Text(store.shortcuts.toggle?.labels.joined(separator: " ") ?? "").foregroundStyle(Theme.current.secondaryText)
            // A `Toggle` in a menu is drawn grey, because the app isn't active. This switch keeps the accent color.
            Button { store.setEnabled(!store.enabled, source: "menu") } label: {
                Capsule().fill(store.enabled ? Theme.current.accent : Color.primary.opacity(0.18)).frame(width: 30, height: 17)
                    .overlay(alignment: store.enabled ? .trailing : .leading) { Circle().fill(.white).padding(2).shadow(radius: 0.5) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enable Tiller")
            .accessibilityValue(store.enabled ? "on" : "off")
        }
        .padding(.horizontal, 14).frame(height: 24)
    }
}

struct EnabledSwitch: View {
    @ObservedObject var store: ShortcutStore
    var body: some View {
        Toggle("Enable Tiller", isOn: $store.enabled).toggleStyle(.switch).labelsHidden().tint(Theme.current.accent)
    }
}

struct GeneralPage: View {
    @ObservedObject var store: ShortcutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsHeader(text: "App")
            SettingsGroup {
                SettingsRow(title: "Enable Tiller", showsDivider: false) { EnabledSwitch(store: store) }
                Text("When Tiller is off, the leader key goes to the focused app. Windows stay where they are.")
                    .font(.system(size: 11)).foregroundStyle(Theme.current.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.bottom, 8)
            }
            SettingsHeader(text: "Menu bar and Dock")
            SettingsGroup {
                SettingsRow(title: "Show Tiller in", showsDivider: false) {
                    Picker("Show Tiller in", selection: $store.showIn) {
                        ForEach(ShowIn.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize().tint(Theme.current.accent)
                }
                Text("With \"Dock\", click the Tiller icon in the Dock to open the settings.")
                    .font(.system(size: 11)).foregroundStyle(Theme.current.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.bottom, 8)
            }
        }
    }
}

/// Variant 1 in `docs/mockups/exit-leader-key-mode.html`: the global shortcuts, then the action keys with an "Exit after" checkbox column.
struct ShortcutsPage: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var store: ShortcutStore

    var body: some View {
        let shortcuts = store.shortcuts
        VStack(alignment: .leading, spacing: 6) {
            SettingsHeader(text: "Global shortcuts")
            SettingsGroup {
                SettingsRow(title: "Leader key") {
                    ShortcutField(model: model, target: .leader, chord: shortcuts.leader, accessibilityName: "Leader key")
                }
                SettingsRow(title: "Turn Tiller on and off", showsDivider: false) {
                    ShortcutField(model: model, target: .toggle, chord: shortcuts.toggle, accessibilityName: "Turn Tiller on and off")
                }
                HelpText(text: "These shortcuts work in every app. The shortcut to turn Tiller on and off works also while Tiller is off.")
                Divider().padding(.leading, 12)
                SettingsRow(title: "Show the key bar", showsDivider: false) {
                    Toggle("Show the key bar", isOn: $store.showKeyBar).toggleStyle(.switch).labelsHidden().tint(Theme.current.accent)
                }
            }
            let leaderMode = model.shortcutsMode == .leader
            ForEach(KeyGuide.sections(shortcuts), id: \.title) { section in
                HStack(alignment: .lastTextBaseline) {
                    SettingsHeader(text: section.title.capitalized)
                    Spacer()
                    if leaderMode {
                        Text("Exit after").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                            .frame(width: Self.checkboxColumn).padding(.trailing, 12)
                    }
                }
                SettingsGroup {
                    let ids = section.entries.flatMap(\.actions)
                    ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                        SettingsRow(title: id.title, showsDivider: index < ids.count - 1) {
                            if leaderMode {
                                ShortcutField(model: model, target: .action(id), chord: shortcuts.actions[id], accessibilityName: id.title)
                                Toggle("Exit leader key mode after \(id.title)", isOn: Binding(
                                    get: { store.shortcuts.exits(after: id) }, set: { store.setExitAfter($0, for: id) }))
                                    .toggleStyle(.checkbox).labelsHidden().tint(Theme.current.accent)
                                    .disabled(id == .turnOff)
                                    .help(id == .turnOff ? "Turn Tiller off always exits leader key mode" : "Exit leader key mode after this action")
                                    .frame(width: Self.checkboxColumn)
                            } else {
                                ShortcutField(model: model, target: .global(id), chord: shortcuts.global[id], accessibilityName: "Global shortcut for \(id.title)")
                            }
                        }
                    }
                }
            }
            HelpText(text: leaderMode
                     ? "A checked action ends leader key mode. With an action unchecked, press more keys, then Esc or the leader key to end leader key mode. Turn Tiller off always ends leader key mode."
                     : "A global shortcut does its action in every app, without the leader key. It needs a modifier. Each chord can have only one global shortcut.")
                .padding(.horizontal, -12)
        }
    }

    private static let checkboxColumn: CGFloat = 56
}

private struct HelpText: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.bottom, 8)
    }
}

/// `docs/mockups/about-page.html`, variant 4: the "Log" group, then the "Diagnostics" group.
struct AboutPage: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var store: ShortcutStore

    var body: some View {
        let theme = Theme.current
        let info = Bundle.main.infoDictionary ?? [:]
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: 0) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 84, height: 84)
                Text("Tiller").font(.system(size: 18, weight: .bold)).padding(.top, 10)
                Text("Version \(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))")
                    .foregroundStyle(theme.secondaryText).padding(.top, 3)
            }
            .frame(maxWidth: .infinity).padding(.top, 14).padding(.bottom, 8)
            SettingsHeader(text: "Log")
            SettingsGroup {
                DetailRow(title: "Log file", detail: Text(model.logFiles).font(theme.pathFont), showsDivider: false) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([Log.shared.fileURLs.first ?? Log.directory])
                    }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.accent)
                }
            }
            SettingsHeader(text: "Diagnostics")
            SettingsGroup {
                let hoursLeft = DebugLogging.hoursLeft(until: store.debugLoggingUntil, now: Date())
                DetailRow(title: "Debug logging", badge: hoursLeft.map { "\($0) h left" },
                          detail: Text("Logs each Accessibility call. Turns off after 24 hours.")) {
                    Toggle("Debug logging", isOn: Binding(get: { hoursLeft != nil }, set: { store.setDebugLogging($0) }))
                        .toggleStyle(.switch).labelsHidden().tint(theme.accent)
                }
                DetailRow(title: "Include window titles in logs", detail: Text("Titles can contain private text, for example a document name.")) {
                    Toggle("Include window titles in logs", isOn: $store.logTitles).toggleStyle(.switch).labelsHidden().tint(theme.accent)
                }
                DetailRow(title: "Diagnostics file", detail: Text("The log, the settings, the windows and the workspace of each screen."),
                          showsDivider: false) {
                    Button(model.exporting ? "Exporting…" : "Export Diagnostics…") { model.export() }.disabled(model.exporting)
                }
            }
            HelpText(text: "The zip file is written to the Desktop and shown in Finder. Send it with a bug report.").padding(.horizontal, -10)
        }
    }
}

/// A settings row with a second line of grey text under the title, and an optional teal badge after the title.
private struct DetailRow<Accessory: View>: View {
    let title: String
    var badge: String?
    let detail: Text
    var showsDivider = true
    @ViewBuilder var accessory: Accessory

    var body: some View {
        let theme = Theme.current
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                        if let badge {
                            Text(badge).font(.system(size: 10, weight: .semibold)).foregroundStyle(theme.accent)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(theme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    detail.font(theme.detailFont).foregroundStyle(theme.secondaryText)
                }
                Spacer()
                accessory
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            if showsDivider { Divider().padding(.leading, 12) }
        }
    }
}

/// Opens the settings window. Tiller is an accessory app, so the window brings the app to the front.
final class SettingsWindowController {
    let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) { self.model = model }

    var isOpen: Bool { window?.isVisible == true }
    /// The window server number of the settings window. The proof runner takes a screenshot of this window.
    var windowNumber: Int { window?.windowNumber ?? 0 }

    func show(page: SettingsPage = .general) {
        model.page = page
        let window = self.window ?? {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 600),
                             styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.title = "Tiller Settings"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(model: model))
            w.center()
            return w
        }()
        self.window = window
        // `activate()` is refused after a change of the activation policy to `.accessory`. `activate(ignoringOtherApps:)` isn't refused.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // macOS can refuse the activation when it wasn't caused by a click, for example from the proof runner.
        // The window is then still shown in front.
        window.orderFrontRegardless()
    }

    func close() {
        model.cancel()
        window?.close()
    }
}
