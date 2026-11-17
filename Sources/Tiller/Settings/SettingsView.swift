import AppKit
import SwiftUI
import TillerCore

/// Which shortcut field records now. Only one field records at a time.
enum RecordTarget: Equatable {
    case leader
    case action(ActionID)
}

/// State of the settings window. Read and written on the main thread.
final class SettingsModel: ObservableObject {
    let store: ShortcutStore
    let leaderKey: LeaderKey
    @Published var page: SettingsPage = .general
    @Published private(set) var recording: RecordTarget?

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

    func clear(_ target: RecordTarget) {
        if recording == target { cancel() }
        switch target {
        case .leader: store.setLeader(nil)
        case .action(let id): store.set(nil, for: id)
        }
    }

    func cancel() {
        recording = nil
        leaderKey.recorder = nil
    }

    private func finish(_ target: RecordTarget, _ chord: KeyChord?) {
        recording = nil
        guard let chord else { return }
        switch target {
        case .leader: store.setLeader(chord)
        case .action(let id): store.set(chord, for: id)
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
                Text(model.page.title).font(.system(size: 15, weight: .bold)).padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 8)
                ScrollView {
                    Group {
                        switch model.page {
                        case .general: GeneralPage(store: model.store)
                        case .shortcuts: ShortcutsPage(model: model, store: model.store)
                        case .about: AboutPage()
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
        HStack(spacing: 6) {
            Button { recording ? model.cancel() : model.record(target) } label: {
                Text(recording ? "Press keys…" : chord.map { $0.labels.joined(separator: " ") } ?? "Record shortcut")
                    .font(.system(size: 12, weight: chord == nil || recording ? .regular : .semibold))
                    .foregroundStyle(recording ? theme.accent : (chord == nil ? Color.secondary : Color.primary))
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
            Text(LeaderKey.toggleChord.labels.joined(separator: " ")).foregroundStyle(Theme.current.secondaryText)
            // A `Toggle` in a menu is drawn grey, because the app isn't active. This switch keeps the accent color.
            Button { store.enabled.toggle() } label: {
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

struct ShortcutsPage: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var store: ShortcutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsHeader(text: "Leader key")
            SettingsGroup {
                SettingsRow(title: "Leader key", showsDivider: false) {
                    ShortcutField(model: model, target: .leader, chord: store.shortcuts.leader, accessibilityName: "Leader key")
                }
                Text("Press the leader key, then one key from the lists below. Esc ends leader key mode.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.bottom, 8)
                Divider().padding(.leading, 12)
                SettingsRow(title: "Show the key bar", showsDivider: false) {
                    Toggle("Show the key bar", isOn: $store.showKeyBar).toggleStyle(.switch).labelsHidden().tint(Theme.current.accent)
                }
            }
            ForEach(KeyGuide.sections, id: \.title) { section in
                SettingsHeader(text: section.title.capitalized)
                SettingsGroup {
                    let ids = section.entries.flatMap(\.actions)
                    ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                        SettingsRow(title: id.title, showsDivider: index < ids.count - 1) {
                            ShortcutField(model: model, target: .action(id), chord: store.shortcuts.actions[id], accessibilityName: id.title)
                        }
                    }
                }
            }
        }
    }
}

struct AboutPage: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("Tiller").font(.system(size: 18, weight: .bold))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }
}

/// Opens the settings window. Tiller is an accessory app, so the window brings the app to the front.
final class SettingsWindowController {
    let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) { self.model = model }

    var isOpen: Bool { window?.isVisible == true }

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
