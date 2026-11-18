// Amazon research report. Reads a results.json (schema amazon-results/1).
// Compile from the search folder:
//   typst compile --root . --input results=/results.json reports/amazon-report.typ reports/amazon-YYYY-MM-DD.pdf
// Optional inputs: spec=/spec.md is not parsed; pass need="one line" to override the heading line.

#let data = json(sys.inputs.at("results", default: "/results.json"))
#let run = data.run
#let items = data.items
#let money(v, cur) = if v == none { "—" } else { cur + (if cur.len() > 1 { " " } else { "" }) + str(calc.round(v, digits: 2)) }
#let cur(it) = if it.at("currency", default: "USD") == "USD" { "$" } else { it.at("currency", default: "") }
#let opt(it, k) = { let v = it.at(k, default: none); if v == none { "—" } else { str(v) } }
#let yn(v) = if v == true { "yes" } else if v == false { "no" } else { "—" }

#set document(title: "Amazon: " + data.search.title)
#set page(paper: "a4", margin: (x: 1.6cm, y: 1.8cm), numbering: "1 / 1",
  footer: context [#set text(8pt, fill: gray); Run #run.id · read #run.read_at · #run.domain #h(1fr) #counter(page).display("1 / 1", both: true)])
#set text(font: ("IBM Plex Sans", "Liberation Sans", "DejaVu Sans"), size: 9.5pt)
#show heading.where(level: 1): set text(17pt)
#show heading.where(level: 2): it => block(above: 1.2em, below: 0.6em, text(11.5pt, it))

= #data.search.title
#text(fill: gray)[What was found on Amazon that can be delivered to *#run.deliver_to.verified_line*]

#grid(columns: (auto, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [*Deliver to*], [#run.deliver_to.verified_line (ZIP #run.deliver_to.zip), set and verified before searching],
  [*Prime membership*], [#run.at("prime_membership", default: "—")],
  [*Spec*], [#data.search.at("spec_ref", default: "—") #if data.search.at("spec_revision", default: none) != none [revision #data.search.spec_revision]],
  [*Queries*], [#run.at("queries", default: ()).map(q => q.query + if q.at("result_count", default: none) != none { " (" + q.result_count + ")" } else { "" }).join("; ")],
)

#let rec = data.at("recommendation", default: none)
#if rec != none and rec.at("asin", default: none) != none {
  let pick = items.find(i => i.asin == rec.asin)
  block(fill: rgb("#eef6ee"), inset: 10pt, radius: 4pt, width: 100%)[
    *Recommendation:* #if pick != none [#pick.title (#raw(pick.asin)), #money(pick.at("total", default: pick.price), cur(pick))] else [#raw(rec.asin)] \
    #rec.why
  ]
}

#let table-for(rows) = table(
  columns: (auto, 1fr, auto, auto, auto, auto, auto),
  stroke: 0.4pt + luma(200), inset: 5pt,
  fill: (_, y) => if y == 0 { luma(235) },
  table.header([*ASIN*], [*Product*], [*Total*], [*Prime*], [*Arrives*], [*Sold by*], [*Rating*]),
  ..rows.map(it => (
    link("https://" + run.domain + "/dp/" + it.asin, raw(it.asin)),
    [#it.title #if it.at("notes", default: none) != none [\ #text(8pt, fill: gray)[#it.notes]]],
    money(it.at("total", default: it.price), cur(it)),
    yn(it.at("prime_eligible", default: none)),
    opt(it, "arrives"),
    opt(it, "sold_by"),
    [#opt(it, "rating") #if it.at("rating_count", default: none) != none [(#it.rating_count)]],
  )).flatten()
)

#for (status, label) in (("shortlist", "Shortlist"), ("candidate", "Other candidates"), ("no-offer", "No current offer"), ("rejected", "Rejected")) {
  let rows = items.filter(i => i.status == status)
  if rows.len() > 0 {
    heading(level: 2)[#label (#rows.len())]
    table-for(rows)
  }
}

#let reqs = items.filter(i => i.at("spec_fit", default: (:)).len() > 0)
#if reqs.len() > 0 {
  let ids = reqs.map(i => i.spec_fit.keys()).flatten().dedup().sorted()
  heading(level: 2)[Spec fit]
  table(
    columns: (auto,) + ids.map(_ => auto),
    stroke: 0.4pt + luma(200), inset: 4pt,
    table.header([*ASIN*], ..ids.map(i => [*#i*])),
    ..reqs.map(it => (raw(it.asin),) + ids.map(i => {
      let v = it.spec_fit.at(i, default: "—")
      text(fill: if v == "pass" { green.darken(30%) } else if v == "fail" { red } else { gray })[#v]
    })).flatten()
  )
}

#v(1fr)
#text(8pt, fill: gray)[Prices, Prime eligibility and delivery dates were read live for the location above at the time shown, and change by the hour. "Prime: yes" assumes a live membership#if run.at("prime_membership", default: none) == "unverified-needs-reauth" [, which was not verified for this run].]
