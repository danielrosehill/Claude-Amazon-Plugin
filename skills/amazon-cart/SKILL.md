---
name: amazon-cart
description: Read and change the signed-in Amazon cart in the agent browser - list what is in it, add an ASIN at a quantity, change a quantity or remove a line - with the user's explicit approval for every change and a re-read to verify it. Use when the user says "add this one to my cart", "what's in my Amazon cart", "put two of B0… in the basket", or as the step before amazon-checkout. Never places an order.
allowed-tools: Read, Write, Edit, Bash(python3 *), mcp__agent-browser__browser_navigate, mcp__agent-browser__browser_evaluate, mcp__agent-browser__browser_snapshot, mcp__agent-browser__browser_click, mcp__agent-browser__browser_select_option, mcp__agent-browser__browser_tabs, mcp__playwright__browser_navigate, mcp__playwright__browser_evaluate, mcp__playwright__browser_snapshot, mcp__playwright__browser_click
---

# Amazon cart

The cart is shared account state: the user's phone and laptop see the same one.
Reading it is free. Every change gets a one-line confirmation first and a
re-read after. Nothing here proceeds to checkout; that is `amazon-checkout`.

Browser: [`reference/browser-route.md`](../../reference/browser-route.md). Check
the deliver-to location (`amazon-deliver-to`) first: the cart's delivery
estimates are for it.

## Read

Works on a remembered session (verified 2026-11-18). Each active line carries
its facts as attributes, which is more reliable than its text:

```js
async () => {
  const r = await fetch('/gp/cart/view.html', { credentials: 'include' });
  if (/\/ap\/signin/.test(r.url)) return { signin: true };
  const d = new DOMParser().parseFromString(await r.text(), 'text/html');
  const c = (s) => (s || '').replace(/\s+/g, ' ').trim();
  const lines = [...d.querySelectorAll('#sc-active-cart div[data-asin]')]
    .filter((n) => n.dataset.asin && n.dataset.itemtype === 'active')
    .map((n) => ({ asin: n.dataset.asin, qty: Number(n.dataset.quantity), price: Number(n.dataset.price),
                   title: c(n.querySelector('.sc-product-title, .a-truncate-full')?.textContent).slice(0, 90) }));
  return { lines, savedForLater: d.querySelectorAll('#sc-saved-cart div[data-asin]').length };
}
```

If `itemtype` filtering returns nothing but the cart is not empty, drop the
filter and dedupe by ASIN; the attribute set is what matters. Show the user
ASIN, title, qty, unit price and the line total.

## Add

1. Read the product page first (`pw_runner.py product <ASIN>`): `buyable` must be
   true, and quote price, seller and the delivery promise to the deliver-to ZIP.
2. Confirm in one line: *"Add B0CZ9LH53B Anker Zolo 20,000 mAh, $42.99, sold by
   AnkerDirect, overnight to Cambridge 02139, qty 1?"* Wait for yes. Approval for
   one item is not approval for the next.
3. On the `/dp/<ASIN>` page: if a quantity is needed, `browser_select_option` on
   `#quantity`; then `browser_click` the **Add to Cart** button (`#add-to-cart-button`)
   from a fresh `browser_snapshot` ref. Never `#buy-now-button`: Buy Now skips the
   cart and goes straight to an order.
4. Dismiss any warranty / add-on side sheet with its "No thanks" / close control.
   Do not accept protection plans or add-ons unless the user asked.
5. Re-read the cart. The ASIN must be there at the requested quantity. Report the
   verified line, not the click.

## Change quantity / remove

Navigate to `/gp/cart/view.html`, snapshot, act on that line's quantity control
or **Delete** link only, then re-read. Confirm first, naming the ASIN. "Clear the
cart" is a list of removals, each named in the confirmation.

## Log

When a search folder is in play, append each verified change to `orders.json`
(`action: cart-add | cart-qty | cart-remove`, `approved_by_user: true`,
`verified: true`) and a line to `log.md`.

## Related

- `amazon-checkout` — the next step, with its own confirmation
- `amazon-search`, `amazon-listing-check` — where the ASIN comes from
