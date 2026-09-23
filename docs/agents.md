# Agents — driving Copper from Claude Code, phi, Cursor, Claude Desktop

Copper is an MCP server. Turn it on and an agent gets the window you have
open — your tabs, your sign-ins, your extensions — through the same tool
names Playwright MCP uses, so a skill written for that works here unchanged.

## Turn it on

Settings › Agents › **Let agents drive this window**. That starts a
Streamable-HTTP MCP endpoint at `http://127.0.0.1:4123/mcp`, loopback only,
guarded by a bearer token that lives in `agent.json` beside your session
(0600). Every request must carry it; anything with a foreign `Origin` header
is refused, so a page in another browser can't reach in.

## Connect a client

**Claude Code / phi / Cursor (HTTP)** — Settings › Agents › *Copy config*,
paste into `~/.claude.json` (or `~/.pi/agent/mcp.json`, or the editor's MCP
settings):

```json
{
  "mcpServers": {
    "copper": {
      "type": "http",
      "url": "http://127.0.0.1:4123/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

Or the one-liner: `claude mcp add --transport http copper http://127.0.0.1:4123/mcp --header "Authorization: Bearer <token>"`.

**Claude Desktop and other stdio-only clients** — the second *Copy config*.
It runs the app binary with `--mcp-stdio`, which is a pipe to the running
window (and launches Copper if it isn't up):

```json
{
  "mcpServers": {
    "copper": {
      "type": "stdio",
      "command": "/Applications/Copper.app/Contents/MacOS/Copper",
      "args": ["--mcp-stdio"]
    }
  }
}
```

**Rotate** the token from Settings whenever you like; every client config
goes stale at once, on purpose.

## Tools

Playwright MCP's names and argument shapes. `ref`s come from
`browser_snapshot` and are remembered on the element until the page changes.

| tool | does |
|---|---|
| `browser_tabs` | `list` / `new {url}` / `close {index}` / `select {index}` — the real row, groups and pins shown |
| `browser_navigate`, `browser_navigate_back`, `browser_navigate_forward` | the current tab; waits for the load to settle |
| `browser_snapshot` | accessibility tree with `[ref=e12]` on interactive nodes; `interactive: true` for a smaller one, `selector` for a subtree |
| `browser_click` | `ref` or `selector`; `doubleClick`, `button`, `modifiers` — a real `NSEvent` at the element's centre |
| `browser_type` | `text`, `submit`, `slowly` (real key events) — sets the value through the native setter so React/Vue notice |
| `browser_fill_form` | `[{ref, type, value}]` for textbox / checkbox / radio / combobox / slider |
| `browser_press_key` | `Enter`, `Escape`, `ArrowDown`, `Meta+a`, `a` … as real key events (⌘ shortcuts go to the window first) |
| `browser_hover`, `browser_drag`, `browser_select_option`, `browser_scroll` | as named |
| `browser_take_screenshot` | PNG/JPEG at 1×, so image pixels are CSS pixels; `ref` for one element, `fullPage`, `filename` |
| `browser_evaluate` | `function: "() => …"` or `(element) => …` with `ref` |
| `browser_wait_for` | `text`, `textGone`, `time` |
| `browser_get_text`, `browser_find`, `browser_console_messages` | reading without a snapshot; refs for text you name; console since load |
| `browser_resize`, `browser_close` | the window; the tab |
| `browser_groups` | Copper's tab groups: `list`, `assign {group}`, `remove`, `suggest` |

Input goes in as real events when the tab is on screen (trusted `isTrusted`
clicks, key repeat, focus, default actions); when it is not, the DOM gets an
event of the same shape. Screenshots and snapshot coordinates are in the
tab's CSS pixels; the server converts to points for the click.

Each tool call is announced in the line at the bottom of the window (turn
that off in Settings › Agents). `./bench agent` reports status; `./bench
agent on|off|rotate`.

## What it is not

Not a sandbox. The agent acts as you, in your sessions. Turn it off when you
don't need it. There is no server→client event stream (GET on `/mcp` answers
405); tools are synchronous and answer in the POST.

## Where it lives

`Sources/Search/Fork/MCP/`: `MCP.swift` (listener, HTTP, JSON-RPC),
`Tools.swift` (the catalogue and dispatch), `Page.swift` (the injected
helper: snapshot, refs, setters), `Input.swift` (NSEvent synthesis),
`Bridge.swift` (`--mcp-stdio`). Hooks: `Browser.init` starts it,
`SearchApp.init` runs the bridge. See `PATCHES.md` › `mcp-hooks`.
