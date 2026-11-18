# Search workspace layout

Every Amazon research or ordering exercise leaves a folder behind, so nothing
lives only in a chat: the spec, every run's results, every report and every
cart or order action. A later session resumes from the folder, not from memory.

The folder is either a **dedicated repo** for one purchase (repo root = search
folder) or **one folder inside a shared ordering repo** (`searches/<slug>/`).
Use the shared repo the user names; if they name neither, ask once and record
the answer in their preferences.

## Folder

```
<search>/
  spec.md                       requirements, prose; revision + dated history at the bottom
  spec.yaml                     optional; machine-readable spec (procurement-tools spec-as-code)
  results/
    2026-11-18-1422.json        one file per run, never overwritten
  results.json                  copy of the latest run (what the report reads by default)
  reports/
    amazon-2026-11-18.typ       generated from templates/amazon-report.typ
    amazon-2026-11-18.pdf
  orders.json                   cart and order events, append-only
  log.md                        append-only, one dated line per step
```

**Naming.** `<slug>` is descriptive and dated: `2026-11-usb-c-power-bank-20000mah`,
not `search-1`. In a dedicated repo, the repo carries the name instead
(`Power-Bank-Purchase-1126`).

**Shared repo index.** A shared repo keeps `searches/INDEX.md`: one row per
search folder with slug, one-line need, status (`open`, `reported`, `ordered`,
`closed`), spec revision and last run date. Update it whenever a status changes.

## `log.md`

One line per event, newest last. The point is that a resumed session can see
what happened without re-running anything.

```
- 2026-11-18 14:20 spec r1 saved (5 musts, 2 nices)
- 2026-11-18 14:22 deliver-to set Cambridge 02139 (verified), Prime membership unverified
- 2026-11-18 14:25 run 2026-11-18-1422: 3 queries, 48 cards, 9 shortlisted -> results/2026-11-18-1422.json
- 2026-11-18 14:31 report reports/amazon-2026-11-18.pdf
- 2026-11-18 15:02 cart: added B0CZ9LH53B x1 (user approved)
```

## `results.json`

Flat, one object per run, schema `schema/results.schema.json`. The fields a
report and a later comparison need, and nothing scraped in bulk:

```json
{
  "schema": "amazon-results/1",
  "search": {"slug": "2026-11-usb-c-power-bank-20000mah", "title": "20,000 mAh USB-C power bank",
             "spec_ref": "spec.md", "spec_revision": 1},
  "run": {"id": "2026-11-18-1422", "read_at": "2026-11-18T14:22:54Z", "domain": "www.amazon.com",
          "deliver_to": {"address_id": "home", "zip": "02139", "verified_line": "Cambridge 02139"},
          "prime_membership": "unverified-needs-reauth", "browser": "agent-browser",
          "queries": [{"query": "usb c power bank 20000mah", "recipe": "reputable_fast", "result_count": "over 1,000"}]},
  "items": [{
    "asin": "B0CZ9LH53B", "title": "Anker Zolo Power Bank 20,000mAh 30W", "brand": "Anker",
    "price": 42.99, "currency": "USD", "shipping": 0, "shipping_condition": null, "total": 42.99,
    "prime_eligible": true, "prime_exclusive_price": false,
    "arrives": "Overnight 5 AM - 8 AM", "order_within": "12 hrs 32 mins",
    "sold_by": "AnkerDirect", "ships_from": "Amazon", "availability": "In Stock",
    "rating": 4.4, "rating_count": 15314,
    "status": "shortlist", "spec_fit": {"REQ-001": "pass", "REQ-002": "unknown"},
    "notes": "FBA, brand-direct seller"
  }],
  "recommendation": {"asin": "B0CZ9LH53B", "why": "Only shortlisted item passing every must; overnight to Cambridge."}
}
```

`status` is one of `shortlist`, `candidate`, `rejected`, `no-offer`. Rejected
items stay in the file with the reason in `notes`: a later run needs to know
they were seen.

Prices are numbers in the listing currency; a missing price is `null`, never 0.
`spec_fit` values are `pass`, `fail`, `unknown`, keyed by requirement id from the
spec (`REQ-001`…); with a prose-only spec, number the musts in `spec.md` and key
by those.

## `orders.json`

```json
[{"at": "2026-11-18T15:02:00Z", "action": "cart-add", "asin": "B0CZ9LH53B", "qty": 1,
  "price": 42.99, "approved_by_user": true, "verified": true},
 {"at": "2026-11-18T15:10:00Z", "action": "order-placed", "order_id": "112-...",
  "total": 46.12, "deliver_to": "Cambridge 02139", "arrives": "Thu Nov 19", "approved_by_user": true}]
```
