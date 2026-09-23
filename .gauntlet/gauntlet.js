export const meta = {
  name: 'copper_arc_gauntlet',
  description: 'Gauntlet Loop: builder/critic rounds pushing Copper (Search fork) Tier 1 surfaces — sidebar, command bar, split view, folders — to Arc grade, judged on screenshots beside real Arc screenshots.',
  phases: [{ title: 'Foundation' }, { title: 'Surfaces' }, { title: 'Smoothing' }],
};

const ROOT = '/Users/collinrijock/Developer/Copper';
const TREES = '/Users/collinrijock/Developer/Copper-gauntlet';
const BRIEF = `${ROOT}/.gauntlet/BRIEF.md`;
const BUILDER = 'anthropic/claude-opus-5';
const CRITIC = 'anthropic/claude-opus-5';
const SMOOTHER = 'anthropic/claude-fable-5-1';
const MAX_ROUNDS = args?.maxRounds ?? 4;

const pieces = {
  sidebar: {
    title: 'Sidebar: Arc-grade space sidebar — favicons, space tint, favourites grid, pinned/today split, space strip',
    from: 'fork',
    refs: ['arc-sidebar-exowatt.png', 'arc-command-bar-google-search.png'],
    scenario: `.gauntlet/run.sh g-sidebar . lands on the Exowatt space (6 favourites + 25 pinned + open tabs). Shoot that. Then \`./bench --world g-sidebar spaces select 0\` (Casual, 154 tabs) and shoot again — the long-list case must still look composed.`,
    writeSet: [
      'Sources/Search/Fork/** (new files welcome: e.g. SpaceTint.swift, PinGrid.swift)',
      'Sources/Search/Side.swift (the sidebar itself — reshape as needed, smallest diff that gets the result, logged in PATCHES.md)',
      'Sources/Search/Fork/Spaces.swift (SpaceStrip)',
      'Sources/Search/Tab.swift / Favicons.swift — hooks only, if favicons need a nudge',
      'Sources/Search/Palette.swift / Metrics.swift — only to add, never to change an existing value',
      'PATCHES.md',
    ],
    scope: `Make Copper's sidebar read as Arc's sidebar. Concretely: (1) favicons — the favourites grid shows 16–20pt favicons on soft squares (not letters), every tab row shows a 16pt favicon (fall back to the monogram only when none is cached; fetch on wake as upstream already does); (2) the whole sidebar is washed with the current space's hue (Space.hue is on the model; Arc uses roughly 8–12% saturation in light mode, deeper in dark) and the active row is a pill in a stronger tint of the same hue; (3) the favourites grid survives any count — rows of 3 or 4 squares, wrapping, never widening past the sidebar or clipping under the traffic lights (today the sidebar starts scrolled with the grid hidden — fix that); (4) a quiet separation between pinned tabs and today's tabs: a hairline or spacing plus a "New Tab" row with a + glyph, Arc-style; (5) the space strip at the foot becomes Arc's: the current space's name/emoji on the left, the other spaces as small tinted dots, a + at the end; (6) density — 13px text, ~28pt rows, 16pt icons, 12pt left inset, no hard borders anywhere. Titles truncate with an ellipsis; a long list scrolls under a soft fade, not a hard edge. Keep every existing interaction (click, close, pin/unpin, drag reorder, context menus, ⌃1–9) working.`,
  },
  commandbar: {
    title: 'Command bar: ⌘K as Arc\'s ⌘T — floating card, big input, icon rows, right-side hints',
    from: 'fork',
    refs: ['arc-command-bar-google-search.png', 'arc-command-bar-raindrop.png'],
    scenario: `After .gauntlet/run.sh g-commandbar .: \`./bench --world g-commandbar summon "goo"\` and shoot (mixed offers: pages in this and other spaces, history, bookmarks, a search). Then \`summon ""\` and shoot (the empty state). Then \`summon "split"\` and shoot (a command row). Close with \`bar ""\`.`,
    writeSet: [
      'Sources/Search/Fork/CommandBar.swift and new files under Sources/Search/Fork/',
      'Sources/Search/Omnibox.swift (the row/panel views — hooks or restyling, logged in PATCHES.md)',
      'Sources/Search/History.swift — additive only (e.g. a subtitle/hint field on Suggestion)',
      'PATCHES.md',
    ],
    scope: `The ⌘K bar must look like Arc's ⌘T: one floating card ~640pt wide centred horizontally about a third of the way down the window, 12–14pt corner radius, soft large shadow, no visible border, page dimmed slightly behind it. Input row ~56pt tall with a magnifier glyph and 17–18pt text. Result rows ~40pt: a 16–18pt icon on the left (favicon for pages/bookmarks, a glyph for commands, a magnifier for searches), the title in primary text, the URL/host or space name in muted text after it, and on the right a muted hint that says what Enter does ("Switch to Tab", "Open", "Search Google", "Run", "· Exowatt" for another space's tab). The selected row is a soft filled pill (Arc uses the space tint; we can too). Sections may be grouped (Tabs / Commands / History) with tiny muted headers only if it reads calmer. The empty state shows open tabs in this space and a few commands, not nothing. Keep keyboard behaviour: ↑↓ move, Enter runs, Esc closes, typing filters live.`,
  },
  split: {
    title: 'Split view: Arc-style panes — rounded cards, gutter, per-pane toolbar, active outline',
    from: 'fork',
    refs: ['arc-split-view.png', 'arc-command-bar-google-search.png'],
    scenario: `After .gauntlet/run.sh g-split .: \`./bench --world g-split tabs\` and pick two tabs with real sites (e.g. Lightspeed hosted and the Confluence wiki, or open two with \`./bench --world g-split open https://en.wikipedia.org\` and \`open https://example.com\`). \`select A\`, then \`split B\`, wait ~4s for both to render, shoot. Then \`select B\` (focus moves to the other pane) and shoot. \`split off\` when done.`,
    writeSet: [
      'Sources/Search/Fork/Split.swift and new files under Sources/Search/Fork/',
      'Sources/Search/App.swift — the existing SplitStage hook only',
      'Sources/Search/Sleep.swift / Browser.swift — hooks only if focus/sleep needs it, logged',
      'PATCHES.md',
    ],
    scope: `Make the split read as Arc's: both panes are rounded cards (10–12pt radius) floating in the page area with an 8pt gutter between them and a 6–8pt margin around, the page background showing through. Each pane carries a hairline toolbar (~32pt): back/forward glyphs, the tab's favicon and title or pretty URL centred/leading in muted text, a × on the right that closes that pane's tab (and thereby the split). The focused pane has a 2pt outline in the space tint (or the accent); the other pane has none. The divider is invisible until hovered, then a soft 4pt handle; dragging resizes with the existing fraction; double-click on it resets to 50/50. Clicking anywhere in the unfocused pane focuses it (existing Tab.touched path). The sidebar should show which tabs are in the split (a subtle ⫽ glyph or a linked pair) — small and optional if time is short. Keep ⌘⇧D toggling and \`bench split\` working.`,
  },
  folders: {
    title: 'Folders: Arc-style collapsible folders in the sidebar, imported from Arc',
    from: 'gauntlet/sidebar',
    refs: ['arc-sidebar-exowatt.png', 'arc-command-bar-google-search.png'],
    scenario: `After .gauntlet/run.sh g-folders .: \`./bench --world g-folders spaces select 0\` (Casual — Arc had Saved Sites, Web Inspo, Misc › LOTFG/BuildrFi/…, Ent folders there) and shoot with folders collapsed; expand one (add a bench verb \`folders open NAME\` if none exists) and shoot again. Also shoot Exowatt (Misc, Benefits).`,
    writeSet: [
      'Sources/Search/Fork/Folders.swift and new files under Sources/Search/Fork/',
      'Sources/Search/Fork/Spaces.swift (folder placement in the space shape)',
      'Sources/Search/Side.swift — the loose-tab list only, smallest hook to render folder rows and indented children',
      'Sources/Search/Session.swift — additive optional fields only (Entry.folder: UUID?, Shape.folders: [Folder]?)',
      'Sources/Search/Fork/Fork.swift — bench dispatcher case for a `folders` verb',
      'arc-import — emit folders (nested) and the tabs\' folder ids',
      'bench — the folders verb',
      'PATCHES.md',
    ],
    scope: `Arc folders in Copper's sidebar. Model: struct Folder { id, name, parent: UUID?, collapsed } per space; a tab may belong to a folder. Row: a chevron (rotates on expand), a folder glyph (Arc's is a tinted folder outline), the name in medium weight; children indented 16pt, nested folders indent again. Collapsed folders hide their tabs; expanded show them. Interactions: click the row to toggle; context menu on a folder — Rename, New Folder Inside, Ungroup (tabs stay, folder goes), Remove (closes the tabs); context menu on a tab — Move to Folder › (list) / None; "New Folder" in the Spaces menu and in ⌘K commands. Persist in the session additively so upstream-shaped files still load. arc-import writes the real folder tree from StorableSidebar.json (the walker already sees 'list' items). Drag-into-folder is optional; skip if it costs the round. Style must match the sidebar piece you are branched from — do not restyle the sidebar itself.`,
  },
};

function tree(key) { return `${TREES}/${key}`; }

function builderPrompt(piece, round, feedback) {
  const setup = round === 0
    ? `Your worktree does not exist yet if this is the folders piece; if \`${tree(piece.key)}\` is missing run \`git -C ${ROOT} worktree add -B gauntlet/${piece.key} ${tree(piece.key)} ${piece.from}\`. Then \`cd ${tree(piece.key)}\`.`
    : `\`cd ${tree(piece.key)}\` — your worktree from the previous round, with your commits.`;
  return `You are the BUILDER for one piece of a Gauntlet Loop on Copper, a Swift/SwiftUI/WebKit macOS browser. Read ${BRIEF} completely first; then read PATCHES.md, FORK-PLAN.md (the entry for this piece) and the Fork/ sources you will touch.

${setup}
Work only in that worktree, on branch gauntlet/${piece.key}. Your probe world is g-${piece.key}.

PIECE: ${piece.title}
SCOPE: ${piece.scope}
WRITE SET (edit nothing outside it):
- ${piece.writeSet.join('\n- ')}
REFERENCES to open and study with your image tool: ${piece.refs.map((r) => `${ROOT}/.gauntlet/refs/${r}`).join(', ')}
HOW THE CRITIC WILL LOOK AT IT: ${piece.scenario}

${round === 0
  ? 'Round 1. Look first: run `.gauntlet/run.sh g-' + piece.key + ' .` from your worktree, take the scenario shots into .gauntlet/shots/ (the .s.png half-size copies are what you open), read the code that draws them, then build. Aim for the whole scope this round, not a sliver.'
  : `Round ${round + 1}. A fresh critic compared your last round with Arc and Arc won. Their verdict:\n\n${feedback}\n\nClose that gap first, then anything else you notice. Do not argue with the critic; fix it.`}

Finish the round only when: \`./build.sh debug app\` passes in your worktree, the app launches via run.sh and the scenario works through the bench with no crash (check /tmp/copper-g-${piece.key}.log), every upstream file you touched has a PATCHES.md row, you have taken the scenario shots to ${ROOT}/.gauntlet/shots/${piece.key}-r${round + 1}-<what>.png (use \`.gauntlet/shot.sh g-${piece.key} ${ROOT}/.gauntlet/shots/${piece.key}-r${round + 1}-<what>.png .\`), and your files are committed on gauntlet/${piece.key}. Leave the app running for the critic. Reply with ≤10 lines: what changed, shot paths, anything you could not do.`;
}

function criticPrompt(piece, round) {
  return `You are a fresh, ruthless product-design CRITIC in a Gauntlet Loop. You have no history with the builder; judge only what renders.

Read ${BRIEF} (sections "The bar", "What Arc feels like", "Running and screenshotting", "Progress page"). Then:
1. \`cd ${piece.dir ?? tree(piece.key)} && git log --oneline -5 && ./build.sh debug app\`. If the build fails → verdict FAIL, biggest gap = the error, skip to step 5.
2. Take your OWN screenshots: \`.gauntlet/run.sh g-${piece.key} .\` then exactly this scenario — ${piece.scenario} — saving to ${ROOT}/.gauntlet/shots/${piece.key}-r${round + 1}-critic-<what>.png via \`.gauntlet/shot.sh g-${piece.key} <path> .\`. If the app crashes or the bench does not answer, that is a FAIL with the log (/tmp/copper-g-${piece.key}.log) as the gap.
3. Open the .s.png copies and the references ${piece.refs.map((r) => `${ROOT}/.gauntlet/refs/${r}`).join(', ')} with your image tool. Compare as a senior product designer would: hierarchy, density, alignment, type scale, icon quality (favicons vs letters), tint and contrast, hairlines vs hard borders, spacing rhythm, whether the piece looks like it belongs to the same product as Arc's version, anything that reads as "prototype" or "default SwiftUI". Also try one interaction through the bench that the scope promises (e.g. select another tab, switch space, summon with other text) and make sure it holds.
4. Decide: would a designer shown both call ours the clearly weaker one? If yes → FAIL and name the ONE biggest remaining gap concretely (what, where, what it should be, with pt values or the reference detail to match). If ours holds up next to Arc for this piece's scope ("${piece.title}") → PASS. Do not pass a piece whose favicons are letters, whose panel has a hard 1px border, or whose text sizes are visibly larger than Arc's.
5. Append a <section> to ${ROOT}/.gauntlet/progress.html (piece ${piece.key}, round ${round + 1}, PASS/FAIL, biggest gap, your primary shot beside the reference; paths relative to .gauntlet/). Append only; never rewrite earlier sections.

Piece scope for context (judge only this; ignore surfaces other pieces own): ${piece.scope}

Return JSON only.`;
}

const verdictSchema = {
  type: 'object',
  properties: {
    pass: { type: 'boolean' },
    biggestGap: { type: 'string' },
    notes: { type: 'string' },
  },
  required: ['pass', 'biggestGap', 'notes'],
};

async function gauntlet(key) {
  const piece = { key, ...pieces[key] };
  const history = [];
  let feedback;
  for (let round = 0; round < MAX_ROUNDS; round++) {
    log(`[${key}] round ${round + 1} — build`);
    const built = await agent(builderPrompt(piece, round, feedback), {
      label: `${key}-build-${round + 1}`, model: BUILDER, thread: `builder:${key}`,
    });
    log(`[${key}] round ${round + 1} — critique`);
    const verdict = await agent(criticPrompt(piece, round), {
      label: `${key}-critic-${round + 1}`, model: CRITIC, schema: verdictSchema,
    });
    history.push({ round: round + 1, built: built ?? null, verdict: verdict ?? null });
    if (!verdict) { feedback = 'Critic returned nothing; re-verify build, relaunch, retake the scenario shots, then tighten polish.'; continue; }
    log(`[${key}] round ${round + 1} — ${verdict.pass ? 'PASS' : 'FAIL: ' + verdict.biggestGap}`);
    if (verdict.pass) break;
    feedback = `${verdict.biggestGap}\n\nNotes: ${verdict.notes}`;
  }
  return { key, rounds: history.length, passed: !!history.at(-1)?.verdict?.pass, history };
}

phase('Foundation');
const sidebar = await gauntlet('sidebar');

phase('Surfaces');
const [commandbar, split, folders] = await parallel([
  () => gauntlet('commandbar'),
  () => gauntlet('split'),
  () => gauntlet('folders'),
]);

phase('Smoothing');
const smooth = await agent(`You are the SMOOTHING agent at the end of a Gauntlet Loop on Copper (${ROOT}, branch fork). Read ${BRIEF} and PATCHES.md. Four builders worked in separate worktrees on separate branches: gauntlet/sidebar, gauntlet/folders (branched from sidebar), gauntlet/commandbar, gauntlet/split (the latter two from fork). Your job:
1. In ${ROOT} on branch fork: merge gauntlet/folders (which contains sidebar), then gauntlet/commandbar, then gauntlet/split. Resolve conflicts by keeping both intents (Side.swift and Fork/ files are where they will meet); \`./build.sh debug app\` must pass after each merge. Do not rebase or rewrite history; plain merges are fine here.
2. Make it feel like one product: \`.gauntlet/run.sh g-final\` in ${ROOT} and walk every surface with shots to .gauntlet/shots/final-<what>.png — Exowatt sidebar, Casual with folders open and closed, ⌘K with "goo" and empty, a split of two real pages, the space strip after \`spaces next\`, and dark mode (\`./bench --world g-final ui look dark\` if the look setting exists, else skip). Fix inconsistent radii, tints, type sizes, spacing, leftover hard borders, glyph styles that differ between pieces, anything that crashes or logs errors in /tmp/copper-g-final.log. Also confirm ⌘K's "Switch to <space>", split via ⌘⇧D's bench twin, and folder toggling all still work through the bench.
3. PATCHES.md must list every upstream file the merged fork now touches, one row per hook group; COLLIN.md's status table gets a line per piece (shipped / partly). Commit in small logical commits on fork and push (\`git push\`). Do not touch main.
4. Remove the worktrees when done: \`git worktree remove --force ${TREES}/<piece>\` for each, and \`git branch -D gauntlet/<piece>\` only after confirming its commits are in fork (\`git branch --merged fork\`).
5. Append a final "Smoothing" section to .gauntlet/progress.html with before/after pairs for the sidebar and ⌘K (before-*.png vs final-*.png).
Reply with ≤15 lines: what you unified, what is still visibly unfinished, the merge commits.`, { label: 'smoothing', model: SMOOTHER });

const finalVerdict = await agent(criticPrompt({
  key: 'final',
  dir: ROOT,
  title: 'Whole browser: Copper Tier 1 beside Arc',
  refs: Object.keys(pieces).flatMap((k) => pieces[k].refs).filter((v, i, a) => a.indexOf(v) === i),
  scenario: `In ${ROOT} (branch fork, not a worktree — use \`.gauntlet/run.sh g-final\` and \`.gauntlet/shot.sh g-final <path>\` without a checkout argument): shoot the Exowatt sidebar, \`spaces select 0\` Casual with a folder expanded, \`summon "goo"\` then \`bar ""\`, and a split of two real pages.`,
  scope: 'The entire Tier 1 surface — sidebar with spaces/favourites/folders, command bar, split view — judged as one product against Arc.',
}, 0), { label: 'final-critic', model: CRITIC, schema: verdictSchema });

return { sidebar, commandbar, split, folders, smoothing: smooth ?? null, finalVerdict: finalVerdict ?? null };
