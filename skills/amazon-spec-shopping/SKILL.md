---
name: amazon-spec-shopping
description: End-to-end, spec-driven Amazon shopping that never loses state - save the user's requirements as a versioned spec in a search folder, set the delivery location, search Amazon against the spec, save results.json, render the PDF report, and optionally cart and order with confirmation; or resume a saved spec later and re-check what is available now. Use when the user says "I need X with these requirements", "save this as the spec and search Amazon", "is my old spec still available", "re-run the power bank search", or describes a purchase by its requirements rather than a product.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(python3 *), Bash(typst *), Bash(mkdir *), Bash(cp *), Bash(ls *), Bash(date *), Bash(git *), mcp__agent-browser__browser_navigate, mcp__agent-browser__browser_evaluate, mcp__agent-browser__browser_run_code_unsafe, mcp__agent-browser__browser_snapshot, mcp__agent-browser__browser_tabs, mcp__playwright__browser_navigate, mcp__playwright__browser_evaluate, mcp__playwright__browser_run_code_unsafe, mcp__playwright__browser_snapshot
---

# Spec-driven Amazon shopping

The usual shape of a purchase: the user has specific requirements, wants to know
what Amazon can deliver that meets them, wants a report, and sometimes says
"order that one". This skill runs that whole chain and writes every step to the
search folder ([`reference/workspace-layout.md`](../../reference/workspace-layout.md)),
so a later session can pick the spec back up and ask "still my requirements —
what's available now?"

Each stage is its own skill; this one sequences them and owns the bookkeeping.

## Stage 0 — new or resume?

- **Resume** when the user refers to an earlier search, or the need matches a row
  in `searches/INDEX.md` / an existing purchase repo. Read `spec.md` (and
  `spec.yaml`), latest `results.json`, tail of `log.md`. Show the spec's musts in
  a few lines and ask: *"Still your requirements?"* Changes → Stage 1 as an
  amendment. Unchanged → Stage 2.
- **New** otherwise. Create the folder (descriptive slug) and go to Stage 1.

## Stage 1 — save the spec (before any search)

Write `spec.md` from what the user said, without re-interviewing for things
already said:

```markdown
# <What is being bought>
Revision: 1 · Deliver to: <address id / ZIP> · Budget: <number or "none stated">

## Must
- REQ-001 <single, checkable requirement>
## Must not
- REQ-00x …
## Nice to have
- REQ-00x …
## Out of scope
<attributes the user did not ask for, so they do not creep in as requirements>

## History
- 2026-11-18 r1 created from the user's description
```

Split compound requirements until each has one answer. Ask only about genuine
gaps that would change the search (a missing size, voltage, budget ceiling). If
`procurement-tools` is installed and the spec is technical, also run its
`spec-as-code` for `spec.yaml` with the same ids.

**Amending:** bump the revision, add a dated history line with the reason, retire
rather than delete requirements, never reuse an id. Say which earlier results
the change invalidates.

Log `spec rN saved` and commit.

## Stage 2 — set the delivery location

`amazon-deliver-to` for the spec's address. Stop if it cannot be verified.

## Stage 3 — search against the spec

Derive 2-4 queries from the musts (the product's real names, not the user's
paraphrase; `amazon-shortlist` is the cheaper sweep when the category is
unclear). Run them in the agent browser with `scripts/pw_runner.py`
(`search-then-products --top N`) and the `amazon-us` profile recipes from
`amazon-search` — e.g. `reputable_fast` when speed matters, `budget` with the
user's real number.

Judge each candidate against every must from what the listing actually says
(title, bullets, product details; the manufacturer's datasheet when the listing
is silent). An unverified must is `unknown`, which keeps an item a `candidate`,
not a `shortlist` pick. A failed must is `rejected` with the reason.

Tell the user if a must eliminates the whole market rather than quietly
relaxing it.

## Stage 4 — results and report

`amazon-research-report`: write `results/<run-id>.json` + `results.json`, render
the PDF, log, update the index, commit and push. Reply with the recommendation,
the shortlist table, the deliver-to line and the PDF path.

## Stage 5 — order (only if asked)

"Order this one" → `amazon-cart` (confirm, add, verify) → `amazon-checkout`
(confirm the exact summary, place, verify). Both log to `orders.json`. Status
`ordered`.

## Resuming later: what changed

On a re-run against an unchanged spec, compare the new run with the previous
`results/*.json` and lead with the differences: new items, items gone, price
moves, Prime/delivery changes, the old pick no longer available. That diff is
usually the answer the user wants.

## Related

- `amazon-deliver-to`, `amazon-search`, `amazon-shortlist`, `amazon-listing-check`
- `amazon-research-report`, `amazon-cart`, `amazon-checkout`
- `procurement-tools:spec-as-code`, `procurement-tools:evaluation-matrix` — heavier spec tooling for technical buys
