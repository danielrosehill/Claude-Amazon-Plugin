#!/usr/bin/env python3
"""Wrap this plugin's page extractors as a Playwright MCP runner file.

Why this exists: the Playwright MCP server's `browser_run_code_unsafe` has no
`require`, so it cannot read an extractor from disk itself, and pasting a 200-line
extractor into `browser_evaluate` puts it in the transcript twice (the call, then
the server's "Ran Playwright code" echo). A runner file inlines the extractor,
comment-stripped, and is passed by `filename` instead.

The server only reads files under its allowed roots (verified 2026-11-18: its
output directory and the configured workspace root). `/tmp` is refused. Pass
--out-dir pointing inside one of them.

Usage:
    pw_runner.py search  "<amazon search url>"   --out-dir DIR
    pw_runner.py product <ASIN> [<ASIN> ...]     --out-dir DIR [--domain www.amazon.com]
    pw_runner.py search-then-products "<url>" --top N --out-dir DIR

Prints the runner path as JSON. Call:
    browser_run_code_unsafe(filename=<path>)
"""

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent / "skills" / "amazon-search"


def load(name):
    src = (HERE / name).read_text()
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)           # block comments
    src = "\n".join(l for l in src.splitlines() if not l.strip().startswith("//"))
    src = re.sub(r"\s+//\s[^\n'\"`]*$", "", src, flags=re.M)  # trailing // comments
    return src.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["search", "product", "search-then-products"])
    ap.add_argument("args", nargs="+")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--domain", default="www.amazon.com")
    ap.add_argument("--top", type=int, default=5)
    a = ap.parse_args()

    res = json.dumps(load("extract-results.js"))
    prod = json.dumps(load("extract-product.js"))
    base = f"https://{a.domain}"

    if a.mode == "search":
        body = f"""await page.goto({json.dumps(a.args[0])});
  return await page.evaluate({res});"""
    elif a.mode == "product":
        body = f"""const out = [];
  for (const asin of {json.dumps(a.args)}) {{
    await page.goto({json.dumps(base)} + '/dp/' + asin);
    out.push(await page.evaluate({prod}));
  }}
  return out;"""
    else:
        body = f"""await page.goto({json.dumps(a.args[0])});
  const search = await page.evaluate({res});
  const pick = search.rows.filter(r => !r.sponsored && r.price).slice(0, {a.top}).map(r => r.asin);
  const products = [];
  for (const asin of pick) {{
    await page.goto({json.dumps(base)} + '/dp/' + asin);
    products.push(await page.evaluate({prod}));
  }}
  return {{ search, products }};"""

    out = Path(a.out_dir).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    p = out / f"amazon-{a.mode}.runner.js"
    p.write_text(f"async (page) => {{\n  {body}\n}}\n")
    print(json.dumps({"runner": str(p), "call": "browser_run_code_unsafe(filename=<runner>)"}))


if __name__ == "__main__":
    sys.exit(main())
