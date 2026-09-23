import SwiftUI

/// The tabs, down the left instead of across the top.
///
/// The column is one surface washed in the current space's hue (`SpaceTint`),
/// laid out the way Arc lays its own out: the traffic lights' band, the
/// favourites as a grid of soft squares, the rows that came back from
/// yesterday, a hairline and a "New Tab" row, then whatever was opened today.
/// The space strip and one small door close it off at the foot.
///
/// Nothing in here has a border. Separation is spacing, a single hairline,
/// and the fact that the live row is a pill in a stronger tint of the same
/// hue than everything around it.
struct SideBar: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences
    @ObservedObject private var spaces = Spaces.shared

    @Environment(\.colorScheme) private var scheme

    @Namespace private var pill

    @State private var dragging: Tab.ID?
    @State private var from = 0
    @State private var travel: CGFloat = 0
    @State private var landing = false
    /// The width the column had when the edge was picked up.
    @State private var grabbed: CGFloat?
    @State private var onEdge = false

    /// A pin, picked up out of the grid — a separate state from the loose
    /// rows above, since the two gestures never happen at once but move on
    /// two different axes.
    @State private var pinDragging: Tab.ID?
    @State private var pinFrom = 0
    @State private var pinTravel: CGSize = .zero

    private static let row: CGFloat = 28
    private static let gap: CGFloat = 2
    /// The column's own edges. A row's mark lands at `inset + rowInset` from
    /// the window's edge — twelve, which is where Arc puts its own.
    private static let inset: CGFloat = 6
    private static let rowInset: CGFloat = 6
    private static let square: CGFloat = 34
    private static let pinGap: CGFloat = 6
    /// Today's block never takes more than this much of the column; past it
    /// the block scrolls on its own and the rows above keep their room.
    private static let todayMax: CGFloat = 260

    private var tint: SpaceTint { SpaceTint(hue: spaces.space.hue, dark: scheme == .dark) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head

            if browser.pinnedCount > 0 {
                pinned
                    .padding(.horizontal, SideBar.inset)
                    .padding(.bottom, 10)
            }

            carried
            divider
            newTab
            today

            SpaceStrip(browser: browser)
            foot
        }
        .frame(width: prefs.sideWidth)
        .frame(maxHeight: .infinity)
        .background(landing ? tint.hover : tint.ground)
        .overlay(alignment: .trailing) {
            Rectangle().fill(tint.hairline.opacity(0.6)).frame(width: 1)
        }
        .overlay(alignment: .trailing) { edge }
        .onDrop(of: [.url, .text], isTargeted: $landing) { providers in
            browser.take(providers)
        }
        // Yesterday's rows have an address and no page, so nothing has ever
        // asked their sites for a mark. Ask, once per host per launch, and
        // again when a switch brings a whole new column into view.
        .task(id: spaces.current) { Marks.warm(browser.tabs) }
        .animation(Motion.quick, value: landing)
        .animation(Motion.glide, value: browser.activeID)
        .animation(Motion.glide, value: browser.editingTab)
        .animation(Motion.settle, value: browser.tabs.map(\.id))
        .animation(Motion.settle, value: browser.pinnedCount)
    }

    // MARK: - the lights' band

    /// The band the lights sit in is this mode's title bar: the window is
    /// dragged by it and a double-click fills the screen with it, everywhere
    /// but over the three doors, which take their own clicks. Back, forward
    /// and reload sit right of the lights — the same three doors as the top
    /// bar, moved beside the lights since there's no far end of a row to put
    /// them at in this mode.
    private var head: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                DragStrip()
                    .frame(width: 10 + Metrics.sideLights)
                Color.clear
                    .frame(width: Metrics.helm)
                    .allowsHitTesting(false)
                DragStrip()
            }
            HStack(spacing: 0) {
                Color.clear.frame(width: 10 + Metrics.sideLights)
                Helm(browser: browser)
                Spacer(minLength: 0)
            }
        }
        .frame(height: Metrics.strip)
    }

    // MARK: - the favourites

    private var pinnedTabs: [Tab] { browser.tabs.filter { $0.pin != nil } }

    /// Every loose row with its place in the loose list kept alongside it, so
    /// a row can be drawn in either block below and still know where a drag
    /// would put it.
    private var looseRows: [(index: Int, tab: Tab)] {
        browser.tabs.filter { $0.pin == nil }.enumerated().map { (index: $0.offset, tab: $0.element) }
    }

    private var looseCount: Int { browser.tabs.count - browser.pinnedCount }

    /// Three squares to a row, four once the column is wide enough to hold
    /// four without shrinking them below a comfortable mark. Never more:
    /// past four the grid stops being a grid of buttons and starts being a
    /// row of tiny icons, and an eighteenth favourite should wrap onto a new
    /// row rather than squeeze the seventeen above it.
    private func pinColumns(_ count: Int) -> Int {
        prefs.sideWidth >= 292 ? 4 : 3
    }

    /// However many columns the count calls for, they split the column's own
    /// width between them.
    private var pinWidth: CGFloat {
        let cols = pinColumns(browser.pinnedCount)
        let available = prefs.sideWidth - 2 * SideBar.inset - CGFloat(cols - 1) * SideBar.pinGap
        return max(20, available / CGFloat(cols))
    }

    /// A favourite is a wide, short button, not a big square: past three
    /// columns' worth of room the cell stops growing taller and the mark
    /// inside it stays where the eye expects it.
    private var pinHeight: CGFloat {
        min(46, max(26, pinWidth * 0.62))
    }

    /// The grid itself: fixed-size cells, left-aligned, so a half-empty last
    /// row holds its ground rather than stretching to fill it.
    private var pinned: some View {
        let tabs = pinnedTabs
        let cols = pinColumns(tabs.count)
        let width = pinWidth
        let height = pinHeight
        let columns = Array(repeating: GridItem(.fixed(width), spacing: SideBar.pinGap), count: cols)
        // Measured in the grid's own space, not the square's: a square that
        // has just been moved to a new cell would otherwise report the drag
        // from where it now is, the target would jump back, and the square
        // would shuttle between two cells for as long as the finger stayed.
        return VStack(spacing: 0) { LazyVGrid(columns: columns, alignment: .leading, spacing: SideBar.pinGap) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let held = pinDragging == tab.id
                PinSquare(
                    browser: browser,
                    tab: tab,
                    live: tab.id == browser.activeID,
                    tint: tint,
                    pill: pill,
                    width: width,
                    height: height
                )
                .offset(pinOffset(held: held, index: index, columns: cols))
                .zIndex(held ? 1 : 0)
                .shadow(color: .black.opacity(held ? 0.16 : 0), radius: 10, y: 3)
                .gesture(pinReorder(tab: tab, index: index, columns: cols, width: width, height: height))
            }
        } }
        .coordinateSpace(name: "pins")
    }

    /// The one square actually held stays glued to the fingers; every other
    /// square is already exactly where it belongs, because `browser.move`
    /// put it there — this only cancels out the bit of that same movement
    /// the held square already got for free by changing index underneath
    /// its own drag.
    private func pinOffset(held: Bool, index: Int, columns: Int) -> CGSize {
        guard held else { return .zero }
        let stepX = pinWidth + SideBar.pinGap
        let stepY = pinHeight + SideBar.pinGap
        let from = (row: pinFrom / columns, col: pinFrom % columns)
        let now = (row: index / columns, col: index % columns)
        return CGSize(
            width: pinTravel.width - CGFloat(now.col - from.col) * stepX,
            height: pinTravel.height - CGFloat(now.row - from.row) * stepY
        )
    }

    /// How many cells the drag has moved, in the grid's own row-major order
    /// — a straight line through the array a column-major offset would get
    /// wrong the moment it crossed a row. Row and column travel each measure
    /// themselves against that axis's own step now that a cell's width and
    /// height aren't the same number.
    private func pinDelta(columns: Int, stepX: CGFloat, stepY: CGFloat) -> Int {
        let col = Int((pinTravel.width / stepX).rounded())
        let row = Int((pinTravel.height / stepY).rounded())
        return row * columns + col
    }

    private func pinTarget(from: Int, moved: Int) -> Int {
        min(max(0, from + moved), max(0, pinnedTabs.count - 1))
    }

    /// Pick a square up and the others make way — across a row, and down
    /// into the next, exactly as far as the fingers actually moved.
    private func pinReorder(tab: Tab, index: Int, columns: Int, width: CGFloat, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named("pins"))
            .onChanged { value in
                if pinDragging != tab.id {
                    pinDragging = tab.id
                    pinFrom = index
                }
                pinTravel = value.translation
                let stepX = width + SideBar.pinGap
                let stepY = height + SideBar.pinGap
                let target = pinTarget(from: pinFrom, moved: pinDelta(columns: columns, stepX: stepX, stepY: stepY))
                if target != index {
                    withAnimation(Motion.settle) {
                        browser.move(tab, to: target)
                    }
                }
            }
            .onEnded { _ in
                withAnimation(Motion.settle) {
                    pinDragging = nil
                    pinTravel = .zero
                }
            }
    }

    // MARK: - the rows

    /// Everything that came back from the last session — Arc's pinned tabs.
    /// This is the long block, and the only one that scrolls without limit.
    private var carried: some View {
        ScrollView(.vertical, showsIndicators: false) {
            rows(looseRows.filter { spaces.carried.contains($0.tab.id) })
                .padding(.horizontal, SideBar.inset)
                .padding(.bottom, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity)
        .mask(SideBar.fade)
        .coordinateSpace(name: "rows")
    }

    /// Whatever was opened since. Sits under the New Tab row, the way Arc's
    /// today does, and takes only as much of the column as it needs.
    private var today: some View {
        let list = looseRows.filter { !spaces.carried.contains($0.tab.id) }
        let wanted = CGFloat(list.count) * (SideBar.row + SideBar.gap)
        return ScrollView(.vertical, showsIndicators: false) {
            rows(list)
                .padding(.horizontal, SideBar.inset)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(wanted, SideBar.todayMax))
        .mask(SideBar.fade)
        .coordinateSpace(name: "today")
    }

    @ViewBuilder
    private func rows(_ list: [(index: Int, tab: Tab)]) -> some View {
        VStack(spacing: SideBar.gap) {
            // See the grid: the drag is measured in the column's space, not
            // the row's, so a row that has just moved keeps its bearings.
            ForEach(list, id: \.tab.id) { index, tab in
                let step = SideBar.row + SideBar.gap
                let held = dragging == tab.id
                SideRow(
                    browser: browser,
                    tab: tab,
                    live: tab.id == browser.activeID,
                    tint: tint,
                    pill: pill,
                    close: { browser.close(tab) }
                )
                .offset(y: held ? travel - CGFloat(index - from) * step : 0)
                .zIndex(held ? 1 : 0)
                .shadow(color: .black.opacity(held ? 0.14 : 0), radius: 12, y: 4)
                .gesture(reorder(tab: tab, index: index, step: step))
            }
        }
    }

    /// A long column runs out under a soft edge rather than a hard one — the
    /// top and bottom few points of either block fade into the ground, so a
    /// row half-scrolled off doesn't look sliced.
    private static var fade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.025),
                .init(color: .black, location: 0.975),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Pick a row up and the others make way as it passes them.
    private func reorder(tab: Tab, index: Int, step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named("rows"))
            .onChanged { value in
                if dragging != tab.id {
                    dragging = tab.id
                    from = index
                }
                travel = value.translation.height
                let moved = Int((travel / step).rounded())
                let target = min(max(0, from + moved), max(0, looseCount - 1))
                if target != index {
                    // Positions here are among the loose rows; the pinned
                    // block sits in front of them in the real list.
                    withAnimation(Motion.settle) {
                        browser.move(tab, to: target + browser.pinnedCount)
                    }
                }
            }
            .onEnded { _ in
                withAnimation(Motion.settle) {
                    dragging = nil
                    travel = 0
                }
            }
    }

    /// The quiet line between what was carried over and what was opened
    /// today. Half a hairline, inset from both edges, and nothing else.
    private var divider: some View {
        Rectangle()
            .fill(tint.hairline)
            .frame(height: 1)
            .padding(.horizontal, SideBar.inset + SideBar.rowInset)
            .padding(.top, 5)
            .padding(.bottom, 3)
    }

    private var newTab: some View {
        Quiet(icon: "plus", title: "New Tab", height: SideBar.row, inset: SideBar.rowInset, glow: tint.hover, ink: tint.muted) {
            browser.newTab()
        }
        .padding(.horizontal, SideBar.inset)
        .padding(.bottom, 2)
    }

    // MARK: - the edge and the foot

    /// The column's edge: pull it to make the column wider or narrower,
    /// double-click it to put it back. The hairline darkens under the pointer
    /// so the edge says it can be taken before it is.
    private var edge: some View {
        Rectangle()
            .fill(Palette.ink.opacity(onEdge || grabbed != nil ? 0.18 : 0))
            .frame(width: onEdge || grabbed != nil ? 2 : 1)
            .frame(width: 9)
            .contentShape(Rectangle())
            .onHover { over in
                onEdge = over
                if over { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if grabbed == nil { grabbed = prefs.sideWidth }
                        let wanted = (grabbed ?? prefs.sideWidth) + value.translation.width
                        prefs.sideWidth = min(Metrics.sideMax, max(Metrics.sideMin, wanted))
                    }
                    .onEnded { _ in grabbed = nil }
            )
            .modifier(OneClick(double: true) {
                withAnimation(Motion.settle) { prefs.sideWidth = Metrics.side }
            })
            .animation(Motion.quick, value: onEdge)
    }

    /// One small door at the bottom: the settings.
    private var foot: some View {
        HStack(spacing: 2) {
            ExtensionSlot(edge: .trailing)
            Door(icon: "bookmark", help: "Bookmarks") { browser.bookmarksOpen.toggle() }
                .popover(isPresented: $browser.bookmarksOpen, arrowEdge: .trailing) {
                    BookmarksDropdown(browser: browser, bookmarks: browser.bookmarks)
                }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SideBar.inset)
        .padding(.bottom, 8)
    }

}

/// A site's mark, or the letter that stands in for one until it arrives.
///
/// Upstream's `Mark` draws its letter on a grey chip, which on a tinted
/// column reads as a hole punched through it. This is the same thing with
/// the chip borrowed from the space instead.
private struct RowMark: View {
    let icon: NSImage?
    let letter: String
    let tint: SpaceTint
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            } else {
                Text(letter)
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(tint.muted)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                            .fill(tint.chip)
                    )
            }
        }
        .transition(.opacity)
        .animation(Motion.quick, value: icon == nil)
    }
}

/// A favourite: a wide, soft square holding the site's mark. Arc's grid, and
/// the same cell Copper's pins have always been, only with the icon in front
/// and the letter behind it.
private struct PinSquare: View {
    @ObservedObject var browser: Browser
    @ObservedObject var tab: Tab
    let live: Bool
    let tint: SpaceTint
    let pill: Namespace.ID
    var width: CGFloat = 34
    var height: CGFloat = 34

    @State private var hovering = false

    private var radius: CGFloat { min(width, height) * 0.26 }
    /// A mark big enough to recognise at a glance, and no bigger than the
    /// cell can hold with air around it.
    private var mark: CGFloat { max(14, min(20, height * 0.46)) }

    var body: some View {
        Group {
            if browser.editingPin == tab.id {
                PinField(browser: browser, tab: tab)
            } else {
                RowMark(icon: tab.icon, letter: tab.pin ?? tab.monogram, tint: tint, size: mark)
            }
        }
        .frame(width: width, height: height)
        .background {
            if live {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.pill)
                    .matchedGeometryEffect(id: "live", in: pill)
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(hovering ? tint.hover : tint.square)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .modifier(OneClick(double: live) {
            if live { browser.editLetter(tab) } else { browser.select(tab) }
        })
        .onHover { hovering = $0 }
        .contextMenu { TabMenu(browser: browser, tab: tab, close: { browser.close(tab) }) }
        .help(tab.label)
        .animation(Motion.quick, value: hovering)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

/// One tab, as a line in the column.
private struct SideRow: View {
    @ObservedObject var browser: Browser
    @ObservedObject var tab: Tab
    let live: Bool
    let tint: SpaceTint
    let pill: Namespace.ID
    let close: () -> Void

    @State private var hovering = false
    @State private var shake: CGFloat = 0

    private var editing: Bool { browser.editingTab == tab.id }

    var body: some View {
        HStack(spacing: 8) {
            if editing {
                TabAddressField(browser: browser)
                    .frame(height: 16)
            } else {
                if !tab.isBlank {
                    RowMark(icon: tab.icon, letter: tab.monogram, tint: tint, size: 16)
                }
                if tab.bench {
                    // A script's tab, not yours.
                    Image(systemName: "flask")
                        .font(.system(size: 9))
                        .foregroundStyle(colour.opacity(0.7))
                }
                if tab.shy {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 9))
                        .foregroundStyle(colour.opacity(0.7))
                }
                Text(tab.label)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(colour)
            }

            Spacer(minLength: 2)

            ZStack {
                if hovering, !editing {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(tint.muted)
                        .frame(width: 15, height: 15)
                        .background(Palette.ink.opacity(0.07), in: Circle())
                        .transition(.opacity)
                } else if tab.loading {
                    Ring().transition(.opacity)
                } else if tab.noisy {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(tint.muted)
                        .transition(.opacity)
                }
            }
            .frame(width: editing ? 0 : 15, height: 15)
            .opacity(editing ? 0 : 1)
            .overlay {
                if !editing {
                    Color.clear
                        .frame(width: 30, height: 28)
                        .contentShape(Rectangle())
                        .onTapGesture { if hovering { close() } }
                }
            }
            .animation(Motion.quick, value: hovering)
            .animation(Motion.quick, value: tab.loading)
            .animation(Motion.quick, value: tab.noisy)
        }
        .padding(.leading, 6)
        .padding(.trailing, editing ? 8 : 6)
        .frame(height: 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ground }
        .modifier(Shake(travel: shake))
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .modifier(OneClick(double: false) {
            if live { browser.beginTabEdit(tab) } else { browser.select(tab) }
        })
        .onHover { hovering = $0 }
        .contextMenu { TabMenu(browser: browser, tab: tab, close: close) }
        .animation(Motion.quick, value: hovering)
        .animation(Motion.glide, value: editing)
        .onChange(of: browser.refusals) { _, _ in
            guard editing else { return }
            shake = 0
            withAnimation(.easeOut(duration: 0.5)) { shake = 1 }
        }
        .transition(.scale(scale: 0.94, anchor: .leading).combined(with: .opacity))
    }

    @ViewBuilder
    private var ground: some View {
        if live {
            ZStack(alignment: .leading) {
                Rectangle().fill(tint.pill)
                GeometryReader { geo in
                    Rectangle()
                        .fill(Palette.ink.opacity(0.055))
                        .frame(width: geo.size.width * tab.reading)
                        .animation(.easeOut(duration: 0.15), value: tab.reading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .matchedGeometryEffect(id: "live", in: pill)
        } else if hovering {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.hover)
        }
    }

    private var colour: Color {
        if live { return tint.ink }
        return hovering ? tint.ink.opacity(0.78) : tint.muted
    }
}

/// A row that is an action rather than a page. Quiet until the pointer is on it.
struct Quiet: View {
    let icon: String
    let title: String
    var height: CGFloat = 28
    var inset: CGFloat = 10
    /// What it wears under the pointer, and what it says — a tinted column
    /// hands its own in, so this row belongs to the same surface.
    var glow: Color?
    var ink: Color?
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: act) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .foregroundStyle(hovering ? (ink ?? Palette.faint).opacity(1) : (ink ?? Palette.faint).opacity(0.82))
            .padding(.leading, inset)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(hovering ? (glow ?? Palette.hover) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

/// A small square holding one symbol. Lit when what it opens is open.
struct Door: View {
    let icon: String
    var on = false
    var help = ""
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: act) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(on ? Palette.ink : (hovering ? Palette.ink.opacity(0.7) : Palette.muted))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? Palette.wash : (hovering ? Palette.hover : .clear))
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .animation(Motion.quick, value: hovering)
        .animation(Motion.quick, value: on)
    }
}
