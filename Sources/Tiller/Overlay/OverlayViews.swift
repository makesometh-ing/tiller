import AppKit
import SwiftUI
import TillerCore

/// State of the overlay on one screen. It is written on the main thread.
final class OverlayState: ObservableObject {
    @Published var screen: OverlayScreen?
    /// The container whose `v` key is under the mouse pointer.
    @Published var hoveredKeyContainer: Int?
    /// The frame of the `v` key of each container chip, in overlay coordinates. It is used to find the hovered key.
    var keyRects: [Int: CGRect] = [:]
}

/// A flat key cap: a rounded square with a solid fill, without a border, and the key in the system sans font.
struct KeyCap: View {
    let key: String
    var onChip = false

    var body: some View {
        let theme = Theme.current
        Text(key.count == 1 ? key.uppercased() : key)
            .font(theme.keyFont)
            .foregroundStyle(onChip ? Color.white : theme.keyText)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(onChip ? theme.keyBackgroundOnChip : theme.keyBackground, in: RoundedRectangle(cornerRadius: 5))
    }
}

/// Two overlapped windows, used next to a window count. The SF Symbol is drawn in the text color with a transparent fill.
struct WindowStackIcon: View {
    var body: some View {
        Image(systemName: "rectangle.on.rectangle").font(.system(size: 10, weight: .semibold))
    }
}

struct ContainerChip: View {
    let item: OverlayScreen.ContainerItem
    let hovered: Bool
    let state: OverlayState

    var body: some View {
        let theme = Theme.current
        HStack(spacing: 6) {
            Text("\(item.id + 1)").fontWeight(.heavy).opacity(0.75)
            Text(item.axis == .horizontal ? "⇆" : "⇅")
            HStack(spacing: 3) { WindowStackIcon(); Text("\(item.windowCount)") }
            KeyCap(key: "v", onChip: true)
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { state.keyRects[item.id] = g.frame(in: .named("overlay")) }
                        .onChange(of: g.frame(in: .named("overlay"))) { _, frame in state.keyRects[item.id] = frame }
                })
        }
        .font(theme.chipFont)
        .foregroundStyle(theme.chipText)
        .padding(.leading, 9)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(item.focused ? theme.chipFocused : theme.chipOther, in: Capsule())
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .overlay(alignment: .bottomTrailing) {
            if hovered {
                Text("Switch to \(item.axis == .horizontal ? "vertical" : "horizontal") carousel")
                    .font(theme.pillFont)
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(theme.glass, in: RoundedRectangle(cornerRadius: 6))
                    .fixedSize()
                    .offset(y: 26)
            }
        }
    }
}

struct WindowPill: View {
    let item: OverlayScreen.WindowItem

    var body: some View {
        let theme = Theme.current
        let icon = NSRunningApplication(processIdentifier: item.pid)?.icon ?? NSImage()
        if item.place == .front {
            HStack(spacing: 5) {
                Image(nsImage: icon).resizable().frame(width: 15, height: 15)
                Text(item.appName).lineLimit(1).frame(maxWidth: 110, alignment: .leading).fixedSize(horizontal: true, vertical: false)
                Text(item.floating ? "◳ Floating" : "▦ Tiled")
                    .fontWeight(.semibold)
                    .foregroundStyle(item.floating ? theme.floatingState : theme.text)
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(theme.keyBackground, in: RoundedRectangle(cornerRadius: 4))
                KeyCap(key: "f")
            }
            .font(theme.pillFont)
            .foregroundStyle(theme.text)
            .padding(.leading, 4).padding(.trailing, 4).padding(.vertical, 3)
            .background(theme.glass, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.keyBorder))
            .opacity(0.92)
        } else {
            Image(nsImage: icon).resizable().frame(width: 14, height: 14)
                .padding(2)
                .background(theme.glass, in: RoundedRectangle(cornerRadius: 5))
        }
    }
}

/// The overlay content of one screen: container edges and chips, and window pills.
struct ScreenOverlayView: View {
    @ObservedObject var state: OverlayState

    var body: some View {
        let theme = Theme.current
        ZStack(alignment: .topLeading) {
            Color.clear
            if let screen = state.screen {
                ForEach(screen.containers) { c in
                    let r = local(c.frame, screen)
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(c.focused ? theme.containerEdgeFocused : theme.containerEdge, lineWidth: 2)
                        .frame(width: r.width, height: r.height)
                        .offset(x: r.minX, y: r.minY)
                }
                ForEach(screen.windows) { w in
                    WindowPill(item: w)
                        .fixedSize()
                        .alignmentGuide(.leading) { d in -pillOrigin(w, screen, d).x }
                        .alignmentGuide(.top) { d in -pillOrigin(w, screen, d).y }
                }
                ForEach(screen.containers) { c in
                    let r = local(c.frame, screen)
                    ContainerChip(item: c, hovered: state.hoveredKeyContainer == c.id, state: state)
                        .fixedSize()
                        .alignmentGuide(.leading) { d in -(r.midX - d.width / 2) }
                        .alignmentGuide(.top) { d in -(r.minY - d.height / 2) }
                }
            }
        }
        .coordinateSpace(name: "overlay")
    }

    private func local(_ r: CGRect, _ screen: OverlayScreen) -> CGRect {
        r.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
    }

    private func pillOrigin(_ w: OverlayScreen.WindowItem, _ screen: OverlayScreen, _ d: ViewDimensions) -> CGPoint {
        let r = local(w.frame, screen)
        let inset: CGFloat = 6
        let s = screen.spacing
        switch (w.place, w.axis) {
        case (.front, _): return CGPoint(x: r.maxX - d.width - inset, y: r.maxY - d.height - inset)
        case (.startEdge, .horizontal): return CGPoint(x: r.minX + (s - d.width) / 2, y: r.maxY - d.height - inset)
        case (.endEdge, .horizontal): return CGPoint(x: r.maxX - s + (s - d.width) / 2, y: r.maxY - d.height - inset)
        case (.startEdge, .vertical): return CGPoint(x: r.maxX - d.width - inset, y: r.minY + (s - d.height) / 2)
        case (.endEdge, .vertical): return CGPoint(x: r.maxX - d.width - inset, y: r.maxY - s + (s - d.height) / 2)
        }
    }
}

/// The keys of leader key mode, grouped by what they act on. The key bar, the `?` list and the settings window read this list.
enum KeyGuide {
    struct Entry { let actions: [ActionID]; let label: String; let detail: String }
    struct Section { let title: String; let entries: [Entry] }

    static func sections(_ shortcuts: Shortcuts) -> [Section] { [
        Section(title: "SCREEN", entries: [Entry(actions: [.layoutFullScreen, .layoutVerticalSplit, .layoutLeftTwoThirds, .layoutRightTwoThirds],
                                                 label: "Layout", detail: "Full screen, vertical split, left ⅔, right ⅔")]),
        Section(title: "CONTAINER", entries: [Entry(actions: [.focusPreviousContainer, .focusNextContainer], label: "Focus", detail: "Previous or next container"),
                                              Entry(actions: [.toggleAxis], label: "Mode", detail: "Horizontal or vertical carousel")]),
        Section(title: "WINDOW", entries: [Entry(actions: [.focusPreviousWindow, .focusNextWindow], label: "Focus", detail: "Previous or next window in the carousel"),
                                           Entry(actions: [.toggleFloat], label: "Float", detail: "Float a tiled window, or tile it again"),
                                           Entry(actions: [.moveWindowPreviousContainer, .moveWindowNextContainer], label: "Move",
                                                 detail: "Move the focused window to the previous or next container")]),
        Section(title: "APP", entries: [Entry(actions: [.raiseFloating], label: "Raise", detail: "Raise the floating windows of the focused app")]),
        Section(title: "TILLER", entries: [Entry(actions: [.turnOff], label: "Off",
                                                  detail: shortcuts.toggle.map { "Turn Tiller off. \($0.labels.joined(separator: " ")) turns it on again" } ?? "Turn Tiller off")]),
    ] }

    /// The key cap labels of an entry. An action without a key isn't shown.
    static func labels(_ entry: Entry, _ shortcuts: Shortcuts) -> [String] {
        entry.actions.compactMap { shortcuts.actions[$0] }.flatMap(\.labels)
    }
}

private struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 8, weight: .bold)).kerning(0.8).foregroundStyle(Theme.current.secondaryText.opacity(0.8))
    }
}

/// The key bar at the bottom of the screen. Each section has a heading that says what its keys act on.
struct KeyBar: View {
    @ObservedObject var store: ShortcutStore

    var body: some View {
        let theme = Theme.current
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").rotationEffect(.degrees(90)).foregroundStyle(theme.secondaryText).font(.system(size: 9))
            Text("TILLER").font(.system(size: 10, weight: .bold)).kerning(0.6).foregroundStyle(theme.accent)
            ForEach(KeyGuide.sections(store.shortcuts), id: \.title) { section in
                Divider().frame(height: 26)
                VStack(alignment: .leading, spacing: 3) {
                    SectionTitle(text: section.title)
                    HStack(spacing: 8) {
                        ForEach(section.entries.filter { !KeyGuide.labels($0, store.shortcuts).isEmpty }, id: \.label) { entry in
                            HStack(spacing: 3) {
                                ForEach(Array(KeyGuide.labels(entry, store.shortcuts).enumerated()), id: \.offset) { KeyCap(key: $0.element) }
                                Text(entry.label).foregroundStyle(theme.secondaryText).padding(.leading, 1).fixedSize()
                            }
                        }
                    }
                }
            }
            Divider().frame(height: 26)
            KeyCap(key: "?")
            KeyCap(key: "Esc")
        }
        .font(theme.barFont)
        .padding(.leading, 9).padding(.trailing, 7).padding(.vertical, 6)
        .background(theme.glass, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(theme.keyBorder))
        .fixedSize()
    }
}

/// The full key list, opened with `?` in leader key mode.
struct KeyList: View {
    @ObservedObject var store: ShortcutStore

    var body: some View {
        let theme = Theme.current
        VStack(alignment: .leading, spacing: 6) {
            ForEach(KeyGuide.sections(store.shortcuts), id: \.title) { section in
                SectionTitle(text: section.title).padding(.top, section.title == "SCREEN" ? 0 : 4)
                ForEach(section.entries.filter { !KeyGuide.labels($0, store.shortcuts).isEmpty }, id: \.label) { entry in
                    HStack(spacing: 6) {
                        HStack(spacing: 3) { ForEach(Array(KeyGuide.labels(entry, store.shortcuts).enumerated()), id: \.offset) { KeyCap(key: $0.element) } }
                            .frame(minWidth: 92, alignment: .leading)
                        Text(entry.label).frame(width: 44, alignment: .leading)
                        Text(entry.detail).foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
        .font(theme.barFont)
        .padding(12)
        .background(theme.glass, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(theme.keyBorder))
        .fixedSize()
    }
}
