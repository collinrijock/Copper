import Foundation

// ⌘K, widened. Upstream's switcher lists the pages you have open; this adds
// the pages open in other spaces, your bookmarks, and the browser's own
// commands — all in the rows it already draws, matched by what you type.
// An empty field still shows only open pages, so ⌘K-Return stays what it was.
//
// A command travels as a URL, copper://command/<id>, because a Suggestion is
// a URL with a name; submit() hands those here instead of to a page.

enum CommandBar {
    struct Command {
        let id: String
        let name: String
        let run: (Browser) -> Void
    }

    @MainActor static func commands(_ browser: Browser) -> [Command] {
        var list: [Command] = [
            .init(id: "new-tab", name: "New Tab") { $0.newTab() },
            .init(id: "new-private", name: "New Private Tab") { $0.newShyTab() },
            .init(id: "reopen", name: "Reopen Closed Tab") { $0.reopen() },
            .init(id: "close", name: "Close Tab") { b in if let t = b.active { b.close(t) } },
            .init(id: "pin", name: "Pin Tab") { b in if let t = b.active { b.pin(t) } },
            .init(id: "bookmark", name: "Bookmark This Page") { $0.bookmarkCurrent() },
            .init(id: "sidebar", name: "Toggle Sidebar") { $0.toggleSidebar() },
            .init(id: "reader", name: "Reading Mode") { $0.toggleReader() },
            .init(id: "float", name: "Float the Video") { $0.toggleFloat() },
            .init(id: "hide", name: "Hide Something on This Page") { $0.toggleHiding() },
            .init(id: "history", name: "History") { $0.recalling = true },
            .init(id: "downloads", name: "Downloads") { $0.hoarding = true },
            .init(id: "passwords", name: "Passwords") { $0.managing = true },
            .init(id: "settings", name: "Settings") { $0.tuning = true },
            .init(id: "clear-history", name: "Clear History") { $0.clearHistory() },
            .init(id: "split", name: Split.shared.on ? "Close Split View" : "Split View") { Split.shared.toggle(in: $0) },
            .init(id: "new-space", name: "New Space") { Spaces.shared.add(in: $0) },
            .init(id: "next-space", name: "Next Space") { Spaces.shared.step(1, in: $0) },
            .init(id: "prev-space", name: "Previous Space") { Spaces.shared.step(-1, in: $0) },
        ]
        for space in Spaces.shared.all where space.id != Spaces.shared.current {
            list.append(.init(id: "space-\(space.id)", name: "Switch to \(space.name)") {
                Spaces.shared.select(space.id, in: $0)
            })
        }
        return list
    }

    /// The rows for what was typed: upstream's open pages first, then the
    /// other spaces' pages, bookmarks, and commands. Nothing beyond the open
    /// pages on an empty field.
    @MainActor static func offers(for typed: String, open: [Suggestion], in browser: Browser) -> [Suggestion] {
        let needle = typed.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return open }
        func hit(_ texts: String...) -> Bool { texts.contains { $0.lowercased().contains(needle) } }
        var list = open

        for tab in Spaces.shared.parkedTabs where !tab.isBlank {
            guard let url = tab.address, hit(tab.title, Address.pretty(url)) else { continue }
            let space = Spaces.shared.name(of: tab)
            var row = Suggestion(key: Address.pretty(url), title: "\(tab.title) · \(space)", url: url, kind: .open)
            row.tab = tab.id
            list.append(row)
        }

        for (title, url) in bookmarks(browser.bookmarks.roots) where hit(title, url.absoluteString) {
            list.append(Suggestion(key: Address.pretty(url), title: title, url: url, kind: .bookmark))
        }

        for command in commands(browser) where hit(command.name) {
            list.append(Suggestion(key: command.name, title: "", url: URL(string: "copper://command/\(command.id)")!, kind: .command))
        }
        return Array(list.prefix(12))
    }

    private static func bookmarks(_ nodes: [Bookmark]) -> [(String, URL)] {
        nodes.flatMap { node -> [(String, URL)] in
            if let children = node.children { return bookmarks(children) }
            guard let url = node.url.flatMap(URL.init(string:)) else { return [] }
            return [(node.title, url)]
        }
    }

    /// True when the URL was a command and has been run.
    @MainActor static func run(_ url: URL, in browser: Browser) -> Bool {
        guard url.scheme == "copper", url.host() == "command" else { return false }
        let id = url.lastPathComponent
        commands(browser).first { $0.id == id }?.run(browser)
        return true
    }
}

extension Spaces {
    func name(of tab: Tab) -> String {
        for space in all where parkedRow(space.id)?.contains { $0.id == tab.id } == true { return space.name }
        return space.name
    }

    /// Bring a tab open in another space to the front, switching to it.
    func reveal(_ id: Tab.ID, in browser: Browser) -> Bool {
        guard let space = all.first(where: { parkedRow($0.id)?.contains { $0.id == id } == true }) else { return false }
        select(space.id, in: browser)
        if let tab = browser.tabs.first(where: { $0.id == id }) { browser.select(tab) }
        return true
    }
}
