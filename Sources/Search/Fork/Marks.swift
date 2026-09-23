import AppKit
import Foundation

// Icons for rows that have no page.
//
// Upstream asks a site for its favicon through the tab's own web view, which
// means a row restored from yesterday — asleep, holding an address and
// nothing else — shows a letter until you click it. A sidebar of forty
// letters is the single loudest difference between Copper and Arc, which has
// every mark on screen the moment the window opens.
//
// So: for each host in the column with nothing in the cache, ask for the one
// address every site on the web has answered since 1999, and hand whatever
// comes back to `Favicons.adopt`, which squares it, keeps it next to the
// history, and tells every tab on that host. No page, no JavaScript, one
// small GET per host per launch — hosts that don't answer are never asked
// twice.

@MainActor
enum Marks {
    /// Hosts already tried this launch, answered or not.
    private static var asked: Set<String> = []

    /// How many hosts are in flight at once. Enough to fill a column of 150
    /// rows in a couple of seconds, few enough that a space switch doesn't
    /// look like a crawl.
    private static let lane = 10

    /// Every host in these rows that has no mark yet.
    static func warm(_ tabs: [Tab]) {
        var hosts: [String] = []
        for tab in tabs {
            // A sleeping tab keeps its address in `pending`; either will do.
            guard let url = tab.pending ?? tab.address,
                  url.scheme?.hasPrefix("http") == true,
                  let host = url.host()?.lowercased(), !host.isEmpty,
                  !asked.contains(host),
                  Favicons.shared.cached(host) == nil
            else { continue }
            asked.insert(host)
            hosts.append(host)
        }
        guard !hosts.isEmpty else { return }
        Task { await fetch(hosts) }
    }

    private static func fetch(_ hosts: [String]) async {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 10
        config.httpMaximumConnectionsPerHost = 2
        let session = URLSession(configuration: config)
        var next = 0
        while next < hosts.count {
            let slice = Array(hosts[next..<min(next + lane, hosts.count)])
            next += slice.count
            await withTaskGroup(of: (String, Data?).self) { group in
                for host in slice {
                    group.addTask { (host, await Marks.ask(host, session)) }
                }
                for await (host, data) in group {
                    guard let data else { continue }
                    await Favicons.shared.adopt(data, for: host)
                }
            }
        }
        session.invalidateAndCancel()
    }

    /// The root icon first, the touch icon as a second guess — between them
    /// they cover nearly every site that has an icon at all. Anything that
    /// isn't plausibly an image is dropped here rather than in the decoder.
    private nonisolated static func ask(_ host: String, _ session: URLSession) async -> Data? {
        for path in ["/favicon.ico", "/apple-touch-icon.png"] {
            guard let url = URL(string: "https://\(host)\(path)"),
                  let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false,
                  data.count > 60, data.count < 2_000_000
            else { continue }
            return data
        }
        return nil
    }
}
