import Foundation

// Everything Copper adds to Search lives under Fork/. Upstream files get
// one-line hooks into here and nothing else, so a rebase onto the next
// upstream release touches as few of their lines as possible. See PATCHES.md.
enum Fork {
    static let name = "Copper"
    static let bundle = "com.collinrijock.copper"
    /// Upstream's updater verifies Office Commun's signature against their
    /// feed. Running it from a Copper build would replace Copper with Search.
    /// Until there is a Copper feed and a signing identity, it stays off.
    static let updates = false

    /// The bench verbs Copper adds; see Bench.swift's switch.
    @MainActor static func bench(_ verb: String, _ request: [String: Any], in browser: Browser) -> [String: Any] {
        switch verb {
        case "spaces": return Spaces.shared.bench(request, in: browser)
        case "split":
            // `split` toggles; `split ID` opens beside the active tab; `split off` closes.
            let arg = request["arg"] as? String ?? ""
            if arg == "off" { Split.shared.close() }
            else if arg.isEmpty { Split.shared.toggle(in: browser) }
            else if let tab = browser.tabs.first(where: { $0.id.uuidString.lowercased().hasPrefix(arg.lowercased()) }) { Split.shared.open(with: tab, in: browser) }
            else { return ["error": "no tab \(arg)"] }
            return ["side": Split.shared.side.map { String($0.uuidString.prefix(8)).lowercased() } ?? "", "active": browser.activeID.map { String($0.uuidString.prefix(8)).lowercased() } ?? ""]
        case "bar":
            // What ⌘K would offer for this text, without the keyboard.
            browser.summon()
            browser.typed = request["text"] as? String ?? ""
            let rows = browser.offers.map { ["key": $0.key, "title": $0.title, "kind": "\($0.kind)", "url": $0.url.absoluteString] }
            if request["go"] as? Bool == true, !browser.offers.isEmpty { browser.picked = 0; browser.submit() }
            else { browser.editing = false; browser.typed = "" }
            return ["offers": rows]
        default: return ["error": "unknown verb \(verb)"]
        }
    }
}
