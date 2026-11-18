---
name: amazon-checkout
description: Take the current Amazon cart through checkout in the agent browser and place the order only after the user approves the exact order summary - ship-to address, delivery option and date, payment method, item list and order total. Use when the user says "order it", "check out", "place the order", "buy this one" after a cart is ready. Stops before the final click without an explicit yes on the summary as shown.
allowed-tools: Read, Write, Edit, Bash(python3 *), mcp__agent-browser__browser_navigate, mcp__agent-browser__browser_evaluate, mcp__agent-browser__browser_snapshot, mcp__agent-browser__browser_click, mcp__agent-browser__browser_take_screenshot, mcp__agent-browser__browser_tabs, mcp__playwright__browser_navigate, mcp__playwright__browser_evaluate, mcp__playwright__browser_snapshot, mcp__playwright__browser_click
---

# Amazon checkout

Placing an order spends the user's money and sends a parcel somewhere. The
user approves the **final summary page as it stands**, not the plan, not the
cart. One approval places one order.

Status: the flow below is the standard amazon.com checkout. It was written
2026-11-18 without placing a live order; re-verify selectors on the first real
run and record what changed here.

Browser: [`reference/browser-route.md`](../../reference/browser-route.md). Expect
a sign-in prompt: checkout requires a recently authenticated session. When the
page is `/ap/signin`, ask the user to sign in in the agent browser window
themselves, wait, continue. Never type a password, OTP or card number.

## 1. Preconditions

- Cart read via `amazon-cart`, and it holds exactly what the user means to buy.
  Anything else in it gets named: *"The cart also has B0XXXXXXXX ($4.99). Remove
  it, save it for later, or include it?"*
- The ship-to the user wants is known (address id from `user_config.py resolve`).

## 2. Reach the review page

Navigate to `/gp/cart/view.html`, snapshot, click **Proceed to checkout**
(`input[name="proceedToRetailCheckout"]`). Amazon lands on the single-page
"Review your order" (`/checkout/...` or `/gp/buy/spc/...`).

## 3. Read the summary from the page

Snapshot the review page and read, from the page itself:

| Field | Check |
| --- | --- |
| Ship to | Name + street + city + ZIP. Must match the intended address id. If not, use the page's **Change** link to pick it; never type a new address here. |
| Payment | Card brand + last 4 only, or gift-card balance. |
| Items | ASIN/title, qty, unit price for each line. Must equal the approved cart. |
| Delivery | Chosen option and date per shipment, and its cost. Prefer the free option unless the user asked for speed. |
| Totals | Items, shipping, tax, promotions, **order total**. |

Take a screenshot (`browser_take_screenshot`) of the summary into the search
folder's `orders/` if one is in play.

## 4. Ask

Show it as one block and ask a yes/no:

```
Place this order?
  Ship to:   Jane Doe, 1 Main St, Cambridge MA 02139
  Payment:   Visa •••• 1234
  Items:     B0CZ9LH53B Anker Zolo 20,000 mAh × 1   $42.99
  Delivery:  FREE overnight, Thu Nov 19
  Tax:       $3.55
  Total:     $46.54
```

Only "yes" / "place it" / an equivalent unambiguous approval of **this**
summary counts. A change of any field after approval (re-priced item, new
delivery date, different total) voids it: re-read and ask again.

## 5. Place and verify

Click **Place your order** (`input[name="placeYourOrder1"]` or the button with
that text, via a fresh snapshot ref). Then read the confirmation page: order
number, total, delivery date. Confirm it in order history if the confirmation
page is ambiguous (`amazon-order-history`).

## 6. Log

Append to `orders.json` (`action: order-placed`, order id, total, ship-to line,
arrival, `approved_by_user: true`) and `log.md`; set the search's status to
`ordered` in `searches/INDEX.md`. Commit and push.

## Never

- Use **Buy Now** or 1-Click: both skip the summary.
- Accept subscriptions (Subscribe & Save), protection plans, Prime trials or
  "add a gift" upsells that appear during checkout.
- Change the payment method or add a card.
- Retry a failed "Place your order" click blind: re-read order history first,
  or the retry is a second order.

## Related

- `amazon-cart` — builds the cart this consumes
- `amazon-order-cancel` — when the user changes their mind afterwards
