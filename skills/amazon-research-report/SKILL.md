---
name: amazon-research-report
description: Save an Amazon search run as a flat results.json in a descriptive search folder and render a PDF report from the bundled Typst template - "here is what I found on Amazon that can be delivered to X, against your spec". Use when the user asks for an evaluation list, recommendation list or report of Amazon options, after amazon-search or amazon-shortlist has produced candidates, or when re-running a saved search to see what is available now.
allowed-tools: Read, Write, Edit, Glob, Bash(python3 *), Bash(typst *), Bash(mkdir *), Bash(cp *), Bash(ls *), Bash(date *), Bash(git *)
---

# Amazon research report

The end product of a research session is two files the user can come back to:
a flat `results.json` and a PDF. Both live in the search folder described in
[`reference/workspace-layout.md`](../../reference/workspace-layout.md) — read it
first. Nothing is only in the chat.

## 1. Find or create the search folder

- **Resuming:** the user names it, or match the need against `searches/INDEX.md`
  (shared repo) / the repo name (dedicated repo). Read `spec.md`, the latest
  `results.json` and the tail of `log.md` before doing anything.
- **New:** in the shared ordering repo, `searches/<YYYY-MM>-<descriptive-slug>/`;
  or a dedicated repo when the user wants one. Descriptive means a stranger can
  tell what was being bought from the name.

## 2. Build `results.json` from what was actually read

Inputs are the extractor outputs from `amazon-search` / `amazon-listing-check`
(via the browser route, `scripts/pw_runner.py`), and the deliver-to block from
`amazon-deliver-to`. Map them field by field per the workspace layout:

| results field | from |
| --- | --- |
| `price` | product page `price` (number), else search card `price` |
| `shipping`, `shipping_condition` | card `shipping` / `shippingCondition`, or product `deliveryOptions[].cost/.condition` |
| `total` | price + shipping; `null` if either is unknown |
| `prime_eligible` | card `prime`, or any product `deliveryOptions[].program` starting `PRIME_` / condition "for Prime members" |
| `arrives`, `order_within` | the fastest option the user would actually get, with its condition in `notes` |
| `sold_by`, `ships_from`, `availability` | product page only; `null` from a card |

Rules:

- Write `results/<run-id>.json` (run id `YYYY-MM-DD-HHMM`) and copy it to
  `results.json`. Never overwrite an older run file.
- No price → `null` and `status: "no-offer"`. Never 0.
- Keep rejected items with the reason in `notes`.
- `spec_fit` keyed by the spec's requirement ids. An unchecked requirement is
  `unknown`, not `pass`.
- Validate: `python3 -c "import json,jsonschema; jsonschema.validate(json.load(open('results.json')), json.load(open('${CLAUDE_SKILL_DIR}/../../schema/results.schema.json')))"`.
  (`uv run --with jsonschema python …` if the module is missing.)

## 3. Render the PDF

```bash
mkdir -p reports
cp "${CLAUDE_SKILL_DIR}/../../templates/amazon-report.typ" reports/amazon-report.typ
typst compile --root . --input results=/results/<run-id>.json \
  reports/amazon-report.typ reports/amazon-<YYYY-MM-DD>.pdf
```

Run from the search folder (`--root .` makes `/results/...` resolve inside it).
Same-day re-run: suffix `-2`, never overwrite. `unknown font family` warnings are
harmless. Look at page 1 (`pdftoppm -r 60 -png -f 1 -l 1`) before handing it
over: an empty shortlist table means the statuses were not set.

If `typst` is missing, the report is the markdown table in your reply plus
`results.json`; say the PDF was not produced.

## 4. Log and ship

- Append to `log.md`: run id, queries, counts, shortlist size, report path.
- Update `searches/INDEX.md` status to `reported` (shared repo).
- Commit the folder (spec, results, report, log) and push.
- Reply with the recommendation, the shortlist table, deliver-to line and the PDF path.

## Related

- `amazon-spec-shopping` — the end-to-end flow that calls this
- `amazon-deliver-to` — sets and verifies the location the results are for
- `procurement-tools:procurement-report` — marketplace-agnostic report when Amazon is one of several shops
