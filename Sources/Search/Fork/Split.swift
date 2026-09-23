import SwiftUI

// Two pages side by side. The row of tabs is unchanged: one tab is the
// active one, as ever, and a second — `side` — is shown beside it. Everything
// that acts on "the tab" (⌘L, ⌘W, find, reader) still acts on the active one;
// clicking into the other pane makes that one active, so focus follows the
// pointer without a second notion of selection anywhere.

@MainActor
final class Split: ObservableObject {
    static let shared = Split()
    @Published private(set) var side: Tab.ID?
    /// Fraction of the stage the left pane takes.
    @Published var fraction: CGFloat = 0.5

    var on: Bool { side != nil }

    /// ⌘⇧D. Splits with the tab to the right of the active one (or the
    /// left, at the end of the row); a second press closes the split.
    func toggle(in browser: Browser) {
        if side != nil { side = nil; return }
        guard let here = browser.tabs.firstIndex(where: { $0.id == browser.activeID }), browser.tabs.count > 1 else {
            browser.announce("Nothing to split with — open another tab")
            return
        }
        let other = browser.tabs[here + 1 < browser.tabs.count ? here + 1 : here - 1]
        open(with: other, in: browser)
    }

    func open(with tab: Tab, in browser: Browser) {
        guard tab.id != browser.activeID else { return }
        side = tab.id
        if !tab.wake() { tab.revive() }
        tab.touch()
    }

    func close() { side = nil }

    /// Which pane a tab is in: left (active), right (side), or nowhere.
    func has(_ id: Tab.ID?) -> Bool { id != nil && id == side }

    /// Called when a tab's page is clicked. The side pane becoming active
    /// swaps the two, so the pages stay where they are on screen.
    func touched(_ tab: Tab, in browser: Browser) {
        guard tab.id == side, let active = browser.active else { return }
        side = active.id
        swapped.toggle()
        browser.select(tab)
    }

    /// The side pane sits right unless a swap put the old active there.
    @Published private(set) var swapped = false

    /// Selecting the tab already in the side pane just swaps the panes.
    /// Selecting a third tab replaces the active pane, as it always did.
    /// Closing either pane's tab ends the split.
    func reconcile(_ browser: Browser) {
        guard let side else { return }
        if !browser.tabs.contains(where: { $0.id == side }) || side == browser.activeID { self.side = nil }
    }
}

extension Tab {
    /// The stage tells the split when a page was clicked.
    static var touched: ((Tab) -> Void)?
}

struct SplitStage: View {
    @ObservedObject var browser: Browser
    @ObservedObject var split = Split.shared
    let active: Tab

    var body: some View {
        if let id = split.side, let side = browser.tabs.first(where: { $0.id == id }) {
            GeometryReader { geo in
                let left = split.swapped ? side : active
                let right = split.swapped ? active : side
                HStack(spacing: 0) {
                    pane(left, live: left.id == active.id)
                        .frame(width: max(200, geo.size.width * split.fraction) - 2)
                    Divider()
                        .frame(width: 4)
                        .background(Palette.hairline)
                        .contentShape(Rectangle().inset(by: -4))
                        .gesture(DragGesture(minimumDistance: 1).onChanged { drag in
                            split.fraction = min(0.85, max(0.15, drag.location.x / geo.size.width))
                        })
                        .onHover { inside in inside ? NSCursor.resizeLeftRight.push() : NSCursor.pop() }
                    pane(right, live: right.id == active.id)
                }
            }
            .onChange(of: browser.activeID) { _, _ in split.reconcile(browser) }
            .onChange(of: browser.tabs.map(\.id)) { _, _ in split.reconcile(browser) }
        } else {
            Page(tab: active)
        }
    }

    private func pane(_ tab: Tab, live: Bool) -> some View {
        Page(tab: tab)
            .overlay {
                RoundedRectangle(cornerRadius: 0).strokeBorder(live ? Palette.ink.opacity(0.35) : .clear, lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .animation(Motion.quick, value: live)
    }
}
