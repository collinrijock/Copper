# Fork plan: Search → Arc-class features

Fork: `collinrijock/Search` · upstream: `driceroland/Search` (single-author, one squashed commit, v1.0).

Ground truth from the code (as of fork):

- `Browser.swift` (1.9k lines) is the model: `@Published tabs: [Tab]`, `activeID`, pins, ghosts, find, omnibox, passwords — everything.
- `Tab.swift` owns one lazy `WKWebView`; sleeps after 30 min; restores from `Session.swift` (`session.json`: flat `[Entry{url,title,pin}]` + `active`).
- `App.swift` → single SwiftUI `Window("browser")`, "one window, on purpose". `Extensions.swift:801` also folds new windows into tabs.
- `Side.swift` / `TabBar.swift` = vertical / horizontal tab UIs. `Stage.swift` = the page area (single `WebStage`).
- `Store.swift` = files under `~/Library/Application Support/Search/`, `UserDefaults` at `Store.settings`.
- Web Inspector is already on (`Tab.swift:280 isInspectable = true`).
- Chrome extensions via `WKWebExtension` + `ExtensionShims.swift` (macOS 15.4+).

"Low code" here means: reuse `Browser`/`Tab`/`Session`, add a field or a file, never a framework. Every item below says what to add and where.

---

## Part 1 — Arc features, ordered by importance

Ordering = (how much of daily Arc use it covers) × (how cheap it is here). Do them in order; each one is shippable alone.

### Tier 1 — the reasons people stay on Arc

#### 1. Spaces (workspaces) — **the** missing feature
- **Arc:** named spaces, each with its own tabs/pins, colour, swipe to switch, ⌃1–9.
- **Low-code design:** don't touch `Tab`. Add `var space: UUID` to `Tab` and `Session.Entry`. Add `Space { id, name, tint, order }` list persisted in `Store.file("spaces.json")`. `Browser.activeSpace: UUID`. Every place that reads `tabs` for display (`Side.swift`, `TabBar.swift`, `⌘K` list, `⌘1–9`) filters by `activeSpace`. Everything else (`close`, `select`, `ghosts`, session write) stays untouched because the array is still flat.
- **UI:** space switcher at the bottom of `Side.swift` (dots/names, like Arc), swipe-with-two-fingers via existing `Swipe.swift` hook, `⌃⌥←/→` and `⌃1–9`.
- **Pins per space:** already free — pins are per-`Tab`, tabs are per-space.
- **Migration:** on first read, `Entry.space == nil` → default space.
- **Effort:** ~300 lines. Files: `Tab.swift`, `Session.swift`, `Browser.swift`, `Side.swift`, `TabBar.swift`, new `Spaces.swift`.

#### 2. Profiles per space (separate cookies/logins)
- **Arc:** a space can bind to a profile → separate `WKWebsiteDataStore`.
- **Low-code:** `Space.profile: String?`. In `Web.configuration(shy:)` → `Web.configuration(store:)`; `Store.websites` becomes `Store.websites(for: profile)` returning `WKWebsiteDataStore(forIdentifier: UUID)` (macOS 14 API — persistent, per-id). `Tab.build()` picks the store from its space. Passwords: `Vault` already keys by host; add profile to the key or accept shared keychain (Arc shares too — accept).
- **Gotcha:** extensions attach per configuration; already handled per view in `Extensions.attach(config)`.
- **Effort:** ~80 lines. Files: `Tab.swift`, `Store.swift`, `Spaces.swift`.

#### 3. Split view (2–4 panes)
- **Arc:** drag a tab beside another; panes share the sidebar entry.
- **Low-code:** `Browser.split: [Tab.ID]` (ordered, active-pane index). `Stage.swift`: replace single `WebStage(page:)` with `HSplitView { ForEach(split) { Page(tab:) } }` — SwiftUI's `HSplitView` gives resizable dividers for free. Selecting a tab while holding ⌥ (or "Open in split" from tab context menu, `⌃⌥=`) appends; `⌘W` on a pane removes from `split`, not from `tabs`. Session: persist `split` ids in `Shape`.
- **Effort:** ~120 lines. Files: `Stage.swift`, `Browser.swift`, `Session.swift`, `TabBar.swift` (context menu).

#### 4. Command bar (Arc's ⌘T "do anything")
- **Arc:** one palette for URL / search / open tabs / bookmarks / history / commands.
- **Low-code:** `Omnibox.swift` already suggests from history; `⌘K` already lists open tabs. Merge: `Browser.guess()` appends sections for open tabs (`tabs.filter title/url contains`), bookmarks (`Bookmarks.all()`), and a static command list (`[("New Space", newSpace), ("Toggle Sidebar", toggleSidebar), …]`). Render sections in the existing suggestion dropdown. Bind `⌘T` to open it with an empty new tab behind it (it already does).
- **Effort:** ~150 lines. Files: `Omnibox.swift`, `Browser.swift`.

### Tier 2 — the things you'd miss in the first week

#### 5. Folders in the sidebar
- `Tab.folder: String?` + collapsible `DisclosureGroup` grouping in `Side.swift`. Persist via `Session.Entry`. Drag-to-folder reuses the existing `take(_ providers:)` drop code.
- ~100 lines.

#### 6. Auto-archive ("Today" tabs clear after N hours)
- Arc moves unpinned, untouched tabs to Archive after 12h/24h/7d/30d.
- `Tab.lastSeen: Date` (already have sleep timer logic — reuse its timestamp). On launch and hourly: unpinned tabs with `lastSeen < now - setting` → append to `ghosts` (the existing reopen-closed list, make it persistent in `Store.file("archive.json")`) and remove. Settings picker for the interval. Archive view = existing ghosts UI, searchable.
- ~80 lines. `Browser.swift`, `Settings.swift`.

#### 7. Little Arc (links from other apps open in a small floating window)
- `Links.swift` already handles incoming URLs. Instead of `newTab`, open in a second `Window("little")` sized 900×650 with a single `Tab` not in `tabs`; toolbar button "Open in Search" moves it in. Requires relaxing the one-window rule in `App.swift` (add a second `Window` scene) — keep main browser single-window.
- ~120 lines. `App.swift`, `Links.swift`, new `Little.swift`.

#### 8. Peek (link preview on ⇧-click / hover-hold)
- Same as Little Arc but modal over the page: `.sheet` with a `Page(tab:)` for a throwaway `Tab`. Escape dismisses, button promotes to real tab.
- ~60 lines after #7 (share `Little`).

#### 9. Site Search / Search engine choice
- `Google.swift` hardcodes Google. Add `Settings › Search: [Google, DuckDuckGo, Kagi, Bing, Custom]` + `@site query` bangs (map `"gh foo"` → `https://github.com/search?q=foo`). Table in `Prefs`.
- ~60 lines.

#### 10. Boosts (per-site CSS/JS)
- `Hidden.swift` already injects per-site CSS selectors at document start. Generalise: `Boost { host, css, js }` stored in `Store.file("boosts.json")`, injected via `WKUserScript` alongside veils. A tiny editor in Settings (TextEditor for CSS, TextEditor for JS). Arc's zap = existing ⌘⇧H. Arc's "replace text/colours" = skip; CSS covers it.
- ~120 lines. `Hidden.swift`, `Tab.swift`, `Settings.swift`.

### Tier 3 — polish that makes it feel like Arc

#### 11. Space colour theming
- `Space.tint: Color` → tint `Palette` accents / sidebar background per active space. `Design.swift` has all colours in one place; add a `tint` parameter.
- ~40 lines.

#### 12. Pinned tab favicons + "reset to pinned URL"
- Pins already exist. Add `Tab.pinURL` and "⌘-click pin → return to pinURL".
- ~20 lines.

#### 13. Tab search across spaces (⌘K global)
- `⌘K` currently lists open tabs; drop the space filter when the query is non-empty. Already done by #4 if you list all spaces with a space label.
- ~10 lines.

#### 14. Media controls / now-playing in sidebar
- `Float.swift` already tracks playing media for PiP. Surface a small row in `Side.swift` with title + pause (calls existing `pauseMedia()`).
- ~50 lines.

#### 15. Downloads tray in sidebar
- Downloads exist as a panel. Show last 3 in the sidebar footer. Pure UI.
- ~40 lines.

#### 16. Reader mode auto-detect + "Ask on page" (AI features)
- Arc Max features. Skip until 1–10 land. If wanted: `Reader.swift` already extracts article text → pipe to a local `ollama` or Exowatt gateway via URLSession; render answer in a sheet. Never phone home by default (upstream's privacy line).
- ~150 lines, opt-in setting.

### Explicitly not doing
- **Sync/iOS** — no backend, no mobile app. iCloud Key-Value/CloudKit sync of `spaces.json` + `session.json` is possible (~200 lines, needs App Store entitlements and a paid dev account) but not Arc-parity worth chasing first.
- **Easels/Notes** — dead in Arc too.
- **Chromium engine** — upstream policy, and the whole point.

### Suggested order to ship
1 → 2 → 4 → 3 → 6 → 5 → 9 → 7 → 8 → 10 → 11–15 → 16.
Spaces first because it unblocks 2, 5, 11 and changes the persistence shape; get the migration right once.

### Persistence shape after Tier 1
```
session.json   { tabs:[{url,title,pin,space,folder,lastSeen}], active, split:[ids] }
spaces.json    [{id,name,tint,order,profile}]
archive.json   [{url,title,space,closedAt}]
boosts.json    [{host,css,js}]
```
All `Codable`, all optional fields so upstream's writer stays readable by the fork and vice-versa on the shared fields.

---

## Part 2 — keeping the fork in sync with upstream

Upstream is one author, one squashed commit, "Claude Code first-pass review", asks for an issue before a big PR. Expect infrequent, large drops (they'll likely squash 1.1 into one commit again). Plan for that.

### Branch layout
```
upstream/main   — never touched, fetched only
main            — mirror of upstream/main (fast-forward only)
fork            — your release branch = main + feature branches merged
feat/spaces, feat/split, …   — one branch per Part-1 item, based on main
```
Build/ship from `fork`. Keep `main` pristine so `git diff main..fork` is always "exactly what the fork adds".

### Rules that make rebases cheap
1. **New files over edited files.** Put spaces, split, boosts, little, command list in new `.swift` files. Upstream can't conflict with a file it doesn't have. Only touch `Browser.swift`/`Tab.swift`/`Session.swift` where a hook is unavoidable, and make those hooks one-liners (`extension Browser` in your own file does the work).
2. **Additive `Codable` fields only, always optional.** Upstream's `Session.Shape` decoder keeps working; yours reads upstream's files.
3. **Match their style** (why-comments, no deps, no force-unwraps, Swift 5 mode) so any piece can be upstreamed as a PR and then deleted from the fork — that is the cheapest maintenance of all. Candidates upstream would plausibly take: #9 search engine choice, #12 pin URL, #6 auto-archive, #14 media row. Candidates they've said no to: multi-window (#7), so keep that isolated.
4. **Don't rename their identifiers.** Their naming is idiosyncratic (`ghosts`, `shy`, `veils`, `hunting`). Leave it; conflicts come from touched lines, not taste.

### Sync procedure (run on every upstream change)
```sh
git fetch upstream
git checkout main && git merge --ff-only upstream/main && git push origin main
git checkout fork
git rebase main            # or: git merge main  — see below
swift build 2>&1 | grep -E "error|warning: .*Search/" ; ./build.sh
git push --force-with-lease origin fork
```
- **Rebase** while the fork is small (Tier 1). History stays linear and `git diff main..fork` is the patch set.
- **Switch to merge** once `fork` has a release users depend on — force-pushing a shipped branch breaks their `git pull`. Merge commits named `Merge upstream 1.x` are fine.
- If upstream squashes a release into one giant commit, rebase will replay your commits onto it; conflicts will be concentrated in `Browser.swift`. Resolve by re-applying your hooks, not by keeping your version of the file.

### Automate the boring part
`.github/workflows/upstream.yml` (weekly + manual):
```yaml
on: { schedule: [{cron: "0 9 * * 1"}], workflow_dispatch: {} }
jobs:
  sync:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
        with: { ref: fork, fetch-depth: 0, token: "${{ secrets.GITHUB_TOKEN }}" }
      - run: |
          git remote add upstream https://github.com/driceroland/Search
          git fetch upstream
          git checkout main && git merge --ff-only upstream/main && git push origin main
          git checkout -b sync/upstream-$(date +%F) fork
          git merge main || { git merge --abort; echo CONFLICT >> $GITHUB_STEP_SUMMARY; exit 1; }
          swift build
          git push origin HEAD
          gh pr create --base fork --title "Sync upstream $(date +%F)" --body "auto"
        env: { GH_TOKEN: "${{ secrets.GITHUB_TOKEN }}" }
```
Clean merge + green build → a PR to click. Conflict → a failed run telling you to do it by hand. Enable "Allow GitHub Actions to create PRs" in repo settings.

### Releasing your build
- `./build.sh release dmg` gives an ad-hoc-signed `Search.dmg`. Fine for your own Macs (right-click → Open once).
- **Updater:** `Updater.swift` polls `officecommun.com` and verifies *their* signature. Your fork must either (a) point `Updater` at your own feed (`raw.githubusercontent.com/collinrijock/Search/fork/VERSION` + a GitHub Release asset) and sign with your own Developer ID, or (b) disable it — otherwise a build of the fork will one day replace itself with upstream 1.1 and drop every feature. Do (b) first (one-line early return), (a) when you have a Developer ID.
- Bundle id: change it (`build.sh`) so the fork and upstream coexist with separate keychain items and `Application Support` folders — otherwise they'll fight over `session.json`. `Store.folder` derives from the bundle; check it.
- Tag releases `v1.0-fork.1`, `v1.0-fork.2`… so the upstream base is visible in the tag.

### Weekly checklist (5 min)
1. Actions ran → merge the sync PR if green.
2. `swift build` warnings = 0 on `fork`.
3. Upstream issues/PRs skim — if they're building something on your list (Spaces is the obvious one), stop and wait; theirs will win the rebase.
4. Anything of yours that's stable and in their spirit → open an upstream issue, then a PR, then delete it from `fork` when merged.
