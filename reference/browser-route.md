# Browser route: which browser the signed-in skills drive

Every skill here that needs a signed-in session drives **a dedicated agent
browser first**, and the user's own browser only as a fallback. An agent
browser is a separate, persistent, signed-in browser profile exposed to the
agent through a Playwright MCP server. It does not steal focus, does not touch
the tabs the user is working in, and can be watched or taken over by the user
when a login or a re-auth prompt needs a human.

## Order of preference

1. **Agent browser (Playwright MCP).** The server name comes from the user's
   marketplace preferences (`marketplaces.yaml` → `marketplaces[id=amazon-us].browser`,
   read via `scripts/user_config.py resolve`). Tools are then
   `mcp__<server>__browser_*`. If the preference is unset, use a Playwright MCP
   server whose name contains `agent-browser`, then one named `playwright`.
2. **Claude in Chrome** (`mcp__claude-in-chrome__*`), the user's own browser.
   Only when no agent browser is available, or the user asks for it. Say which
   one you used.

Never fall back silently from 1 to 2: driving the user's main browser is the
thing this order exists to avoid. Tell them, then proceed.

## Tool mapping

| Job | Agent browser (Playwright MCP) | Claude in Chrome |
| --- | --- | --- |
| Open a page | `browser_navigate(url)` | `navigate` |
| Run a short snippet | `browser_evaluate(function="() => …")` (async allowed) | `javascript_tool(text=…)` |
| Run a bundled extractor | `scripts/pw_runner.py` → `browser_run_code_unsafe(filename=…)` | paste file into `javascript_tool` |
| See the page | `browser_snapshot` (writes a file; read it by range) | `read_page` / `find` |
| Click / type | `browser_click(ref)` / `browser_type(ref, text)` from a snapshot ref | `computer` / `form_input` |
| Tabs | `browser_tabs` | `tabs_context_mcp` / `tabs_create_mcp` |

### Running the bundled extractors

`skills/amazon-search/extract-results.js` and `extract-product.js` are page
expressions. Two things about the Playwright route, verified 2026-11-18 on a
Firefox-based Playwright MCP agent browser:

- `browser_run_code_unsafe` has **no `require`**, so it cannot read the
  extractor from disk itself. `scripts/pw_runner.py` writes a runner file with
  the extractor inlined (comments stripped, about half the size) and you pass it
  by `filename`.
- The server reads runner files **only under its allowed roots** (its output
  directory and its workspace root). `/tmp` is refused with "outside allowed
  roots". Point `--out-dir` at the server's output directory; the refusal
  message names the allowed roots if you do not know them.

```bash
python3 scripts/pw_runner.py search "https://www.amazon.com/s?k=usb+c+power+bank" --out-dir <allowed-root>
python3 scripts/pw_runner.py product B0CZ9LH53B B0XXXXXXXX --out-dir <allowed-root>
python3 scripts/pw_runner.py search-then-products "<search url>" --top 5 --out-dir <allowed-root>
```

The server echoes the code it ran into the tool result. That is why the runner
strips comments; keep batches to a handful of ASINs per call.

The Claude-in-Chrome restriction on results that look like cookies or query
strings does not apply on the Playwright route, but keep the extractors'
"parsed fields only" rule anyway: the extractors must work on both.

## Session facts the agent browser does and does not have

A synced or remembered session is **not** a recently authenticated one.
Measured 2026-11-18 on amazon.com:

| Page | Works from a remembered session? |
| --- | --- |
| Search, product pages, Prime-aware delivery dates | Yes |
| "Deliver to" location change (glow endpoint) | Yes, see `amazon-deliver-to` |
| Cart read (`/gp/cart/view.html`) | Yes |
| Address book (`/a/addresses`) | **No** — redirects to `/ap/signin?...max_auth_age=900` |
| Prime membership (`/gp/primecentral`) | **No** — redirects to `/ap/signin?...max_auth_age=3600` |
| Checkout, order placement, payment | Expect a re-auth prompt |

An HTTP 200 from those pages can be the sign-in page. Check the final URL for
`/ap/signin` before parsing anything; an empty parse from a sign-in page looks
exactly like an empty address book. When re-auth is needed, ask the user to
sign in in the agent browser window themselves, then continue. Never type a
password.
