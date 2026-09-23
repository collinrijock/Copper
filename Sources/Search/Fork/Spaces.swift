import SwiftUI

// Spaces: several rows of tabs, one on screen at a time.
//
// The browser keeps working on one array, `tabs` — the row you are looking
// at. The other spaces' rows are parked here, and switching swaps the whole
// row and its active tab in one move. Nothing that draws or walks `tabs`
// (the column, the strip, ⌘1–9, ⌘W, drag to reorder) knows spaces exist.

struct Space: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    /// A hue, 0…1, or nil for the plain grey.
    var hue: Double?

    var tint: Color { hue.map { Color(hue: $0, saturation: 0.55, brightness: 0.75) } ?? Palette.muted }
}

@MainActor
final class Spaces: ObservableObject {
    static let shared = Spaces()

    @Published private(set) var all: [Space]
    @Published private(set) var current: UUID

    /// The rows not on screen, by space.
    private var parked: [UUID: (tabs: [Tab], active: Tab.ID?)] = [:]
    var parkedTabs: [Tab] { parked.values.flatMap(\.tabs) }

    private init() {
        let home = Space(name: "Home")
        all = [home]
        current = home.id
    }

    var space: Space { all.first { $0.id == current } ?? all[0] }

    // MARK: - switching

    func select(_ id: UUID, in browser: Browser) {
        guard id != current, all.contains(where: { $0.id == id }) else { return }
        parked[current] = (browser.tabs, browser.activeID)
        let next = parked.removeValue(forKey: id) ?? ([], nil)
        current = id
        browser.tabs = next.tabs
        if next.tabs.isEmpty {
            browser.newTab()
        } else if let active = next.tabs.first(where: { $0.id == next.active }) ?? next.tabs.first {
            browser.activeID = nil
            browser.select(active)
        }
    }

    func step(_ by: Int, in browser: Browser) {
        guard let here = all.firstIndex(where: { $0.id == current }) else { return }
        select(all[(here + by + all.count) % all.count].id, in: browser)
    }

    func select(index: Int, in browser: Browser) {
        guard all.indices.contains(index) else { return }
        select(all[index].id, in: browser)
    }

    // MARK: - editing

    func add(named name: String = "", in browser: Browser) {
        let space = Space(name: name.isEmpty ? "Space \(all.count + 1)" : name, hue: Double(all.count % 8) / 8)
        all.append(space)
        select(space.id, in: browser)
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = all.firstIndex(where: { $0.id == id }), !name.isEmpty else { return }
        all[i].name = name
    }

    func tint(_ id: UUID, hue: Double?) {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        all[i].hue = hue
    }

    /// Its tabs close for good. The last space cannot be removed.
    func remove(_ id: UUID, in browser: Browser) {
        guard all.count > 1, let i = all.firstIndex(where: { $0.id == id }) else { return }
        if id == current { step(i == 0 ? 1 : -1, in: browser) }
        parked.removeValue(forKey: id)?.tabs.forEach { $0.close() }
        all.remove(at: i)
    }

    /// Move the active tab to another space; it lands at that row's end and
    /// this row moves on, as if the tab had been closed.
    func move(_ tab: Tab, to id: UUID, in browser: Browser) {
        guard id != current, all.contains(where: { $0.id == id }) else { return }
        var row = parked[id] ?? ([], nil)
        row.tabs.append(tab)
        parked[id] = row
        browser.tabs.removeAll { $0.id == tab.id }
        if browser.tabs.isEmpty { browser.newTab() }
        else if browser.activeID == tab.id { browser.activeID = nil; browser.select(browser.tabs[0]) }
    }

    // MARK: - session

    /// Every row, on screen or parked, in one shape upstream can still read:
    /// a flat list of tabs and the index of the one on screen.
    func shape(visible: [Tab], active: Tab.ID?) -> Session.Shape {
        var entries: [Session.Entry] = []
        var activeIndex = 0
        func put(_ tabs: [Tab], _ id: UUID, _ activeID: Tab.ID?, visible: Bool) {
            for tab in tabs {
                guard var entry = Session.Entry(tab) else { continue }
                entry.space = id
                entry.active = tab.id == activeID ? true : nil
                if visible, entry.active == true { activeIndex = entries.count }
                entries.append(entry)
            }
        }
        put(visible, current, active, visible: true)
        for (id, row) in parked { put(row.tabs, id, row.active, visible: false) }
        return .init(tabs: entries, active: activeIndex, spaces: all, space: current)
    }

    /// Yesterday's rows. The visible one lands in `browser.tabs` (built,
    /// nothing fetched); the rest are parked the same way.
    func restore(_ saved: Session.Shape, into browser: Browser) {
        if let spaces = saved.spaces, !spaces.isEmpty {
            all = spaces
            current = saved.space.flatMap { c in spaces.first { $0.id == c }?.id } ?? spaces[0].id
        }
        var rows: [UUID: (tabs: [Tab], active: Tab.ID?)] = [:]
        for (i, entry) in saved.tabs.enumerated() {
            guard let url = URL(string: entry.url) else { continue }
            let tab = Tab()
            browser.prepare(tab)
            tab.restore(url: url, title: entry.title)
            tab.pin = entry.pin
            let id = entry.space.flatMap { s in all.first { $0.id == s }?.id } ?? current
            var row = rows[id] ?? ([], nil)
            row.tabs.append(tab)
            // Upstream's file has no `active` flag — its `active` index does.
            if entry.active == true || (entry.space == nil && i == saved.active) { row.active = tab.id }
            rows[id] = row
        }
        let mine = rows.removeValue(forKey: current) ?? ([], nil)
        parked = rows
        browser.tabs = mine.tabs
        guard let first = mine.tabs.first else { return }
        let active = mine.tabs.first { $0.id == mine.active } ?? first
        browser.activeID = active.id
        _ = active.wake()
    }
}

extension Session.Entry {
    /// What the row needs to draw the tab again, or nil for a tab that is not
    /// worth keeping: private, the bench's, or not yet on a real page.
    @MainActor init?(_ tab: Tab) {
        guard !tab.shy, !tab.bench else { return nil }
        // A sleeping tab holds its address in `pending`; asking for it there
        // too means a pin can never be written out of existence by whatever
        // its web view happens to be showing.
        guard let url = tab.pending ?? tab.address, url.scheme?.hasPrefix("http") == true else { return nil }
        self.init(url: url.absoluteString, title: tab.title, pin: tab.pin)
    }
}

// MARK: - the strip at the foot of the column

struct SpaceStrip: View {
    @ObservedObject var browser: Browser
    @ObservedObject var spaces = Spaces.shared
    @State private var renaming: UUID?
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 4) {
            ForEach(spaces.all) { space in
                let live = space.id == spaces.current
                Button { spaces.select(space.id, in: browser) } label: {
                    HStack(spacing: 5) {
                        Circle().fill(space.tint).frame(width: 7, height: 7)
                        if live {
                            Text(space.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        }
                    }
                    .padding(.horizontal, live ? 8 : 5)
                    .frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(live ? Palette.wash : .clear))
                }
                .buttonStyle(.plain)
                .foregroundStyle(live ? Palette.ink : Palette.muted)
                .help(space.name)
                .contextMenu { menu(for: space) }
                .popover(isPresented: Binding(get: { renaming == space.id }, set: { if !$0 { renaming = nil } })) {
                    TextField("Name", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .padding(8)
                        .onSubmit { spaces.rename(space.id, to: draft); renaming = nil }
                }
            }
            Door(icon: "plus", help: "New Space") { spaces.add(in: browser) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .animation(Motion.glide, value: spaces.current)
    }

    @ViewBuilder
    private func menu(for space: Space) -> some View {
        Button("Rename…") { draft = space.name; renaming = space.id }
        Menu("Colour") {
            Button("Grey") { spaces.tint(space.id, hue: nil) }
            ForEach(Array(stride(from: 0.0, to: 1.0, by: 0.125)), id: \.self) { hue in
                Button { spaces.tint(space.id, hue: hue) } label: {
                    Label { Text(String(format: "%.0f°", hue * 360)) } icon: {
                        Image(systemName: "circle.fill").foregroundStyle(Color(hue: hue, saturation: 0.55, brightness: 0.75))
                    }
                }
            }
        }
        if let tab = browser.active, space.id != spaces.current {
            Button("Move Current Tab Here") { spaces.move(tab, to: space.id, in: browser) }
        }
        if spaces.all.count > 1 {
            Divider()
            Button("Remove Space", role: .destructive) { spaces.remove(space.id, in: browser) }
        }
    }
}

/// The Spaces menu: ⌃⌥← / ⌃⌥→ to step, ⌃1–9 to jump, ⌃N for a new one.
struct SpaceCommands: Commands {
    @ObservedObject var browser: Browser
    @ObservedObject var spaces = Spaces.shared

    var body: some Commands {
        CommandMenu("Spaces") {
            Button("New Space") { spaces.add(in: browser) }
                .keyboardShortcut("n", modifiers: [.control])
            Divider()
            Button("Previous Space") { spaces.step(-1, in: browser) }
                .keyboardShortcut(.leftArrow, modifiers: [.control, .option])
            Button("Next Space") { spaces.step(1, in: browser) }
                .keyboardShortcut(.rightArrow, modifiers: [.control, .option])
            Divider()
            ForEach(Array(spaces.all.prefix(9).enumerated()), id: \.element.id) { i, space in
                Button(space.name) { spaces.select(space.id, in: browser) }
                    .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: [.control])
            }
        }
    }
}

// MARK: - the bench

extension Spaces {
    /// `./bench spaces` lists; `spaces new [NAME]`, `spaces select N|NAME`,
    /// `spaces next`, `spaces prev`, `spaces move N|NAME` (the active tab).
    func bench(_ request: [String: Any], in browser: Browser) -> [String: Any] {
        func find(_ key: String) -> UUID? {
            if let n = Int(key), all.indices.contains(n) { return all[n].id }
            return all.first { $0.name.lowercased() == key.lowercased() }?.id
        }
        let arg = request["arg"] as? String ?? ""
        switch request["op"] as? String ?? "" {
        case "new": add(named: arg, in: browser)
        case "next": step(1, in: browser)
        case "prev": step(-1, in: browser)
        case "select": guard let id = find(arg) else { return ["error": "no space \(arg)"] }; select(id, in: browser)
        case "move":
            guard let id = find(arg) else { return ["error": "no space \(arg)"] }
            guard let tab = browser.active else { return ["error": "no active tab"] }
            move(tab, to: id, in: browser)
        case "remove": guard let id = find(arg) else { return ["error": "no space \(arg)"] }; remove(id, in: browser)
        default: break
        }
        return ["spaces": all.enumerated().map { i, s in
            ["index": i, "name": s.name, "current": s.id == current,
             "tabs": s.id == current ? browser.tabs.count : (parked[s.id]?.tabs.count ?? 0)] as [String: Any]
        }]
    }
}
