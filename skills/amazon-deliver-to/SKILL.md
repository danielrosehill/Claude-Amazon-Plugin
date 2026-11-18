---
name: amazon-deliver-to
description: Set the signed-in Amazon session's "Deliver to" location to the user's chosen delivery address before any search, so every price, Prime badge and delivery date is rendered for the place the parcel will actually go; then report Prime membership state. Use at the start of every Amazon research or ordering session, when the user says "set Amazon to my US address", "check it's delivering to X", or when a result shows the wrong ZIP. Changes only the browsing location, never the account address book.
allowed-tools: Read, Bash(python3 *), mcp__agent-browser__browser_navigate, mcp__agent-browser__browser_evaluate, mcp__agent-browser__browser_snapshot, mcp__agent-browser__browser_tabs, mcp__playwright__browser_navigate, mcp__playwright__browser_evaluate, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__javascript_tool
---

# Amazon "Deliver to"

Amazon renders every delivery promise, Prime badge and "cannot ship" flag for the
session's **Deliver to** location, and says nothing on the page about whether that
location is the one you meant. Results read for the wrong ZIP are well formatted
and wrong. So the location is set and verified **before** the first search, and
stated with every answer.

This changes the *browsing location* only (the header's "Deliver to" chip). It
does not touch the address book, the default shipping address or any order. That
is `amazon-address-book`, which needs a recently authenticated session.

Browser: follow [`reference/browser-route.md`](../../reference/browser-route.md).
Agent browser first; the user's own browser only as a stated fallback.

## 1. Resolve the target

```bash
python3 "${CLAUDE_SKILL_DIR}/../../scripts/user_config.py" resolve [address-id]
```

Take `domain`, `country` and `postcode` from the output. No address id given →
the store's `default_address`. If the user names a place that is not in the
store, ask for its ZIP rather than guessing one; for a country with no Amazon
storefront, use the country route below.

## 2. Read where the session delivers now

Navigate to `https://<domain>/` and evaluate:

```js
() => ({
  line1: document.querySelector('#glow-ingress-line1')?.textContent?.trim(),
  line2: document.querySelector('#glow-ingress-line2')?.textContent?.trim(),
  account: document.querySelector('#nav-link-accountList-nav-line-1')?.textContent?.trim(),
  token: !!document.querySelector('#glowValidationToken'),
})
```

`account` reading "Hello, sign in" means the session is not signed in: stop and
ask the user to sign in in the agent browser window. If `line2` already shows the
target ZIP, skip to step 4.

## 3. Change it

Same-origin POST from the page. Verified 2026-11-18 on amazon.com, from a
remembered (not recently re-authenticated) session:

```js
async () => {
  const tok = document.querySelector('#glowValidationToken')?.value;
  const body = new URLSearchParams({ locationType: 'LOCATION_INPUT', zipCode: '02139',
    deviceType: 'web', storeContext: 'generic', pageType: 'Gateway', actionSource: 'glow' });
  const r = await fetch('/portal-migration/hz/glow/address-change?actionSource=glow', {
    method: 'POST', credentials: 'include',
    headers: { 'anti-csrftoken-a2z': tok, 'content-type': 'application/x-www-form-urlencoded' }, body });
  const j = await r.json();
  return { successful: j.successful, updated: j.isAddressUpdated, city: j.address?.city, zip: j.address?.zipCode };
}
```

`successful: 1` with the expected city is the response; it is **not** the
verification. Step 4 is.

**Country instead of ZIP** (destination outside the storefront's country, e.g.
Israel on amazon.com): body `{"locationType":"COUNTRY","countryCode":"IL","district":"IL"}`
as JSON to the same endpoint, after a GET of
`/portal-migration/hz/glow/get-rendered-address-selections` with the token. Then
product pages show AmazonGlobal shipping and import charges, or "cannot be
shipped". See `reference/delivery.md`.

**Choosing a saved address** from the popover needs a recently authenticated
session: on a remembered session the popover renders "Sign in to see your
addresses". ZIP is enough for every research purpose; the street only matters at
checkout, where `amazon-checkout` reads it from the order summary.

## 4. Verify

Re-fetch `/` (or reload) and read `#glow-ingress-line2` again. It must show the
target ZIP. Report it as:

```
Deliver to: Cambridge 02139 (set and verified 2026-11-18 14:22 UTC, agent browser)
```

If it does not match, stop. Do not search on a session you could not set.

## 5. Prime membership state

Per-item Prime eligibility comes for free on every search card (`prime`) and
product page (`deliveryOptions[].condition` "for Prime members", program ids
starting `PRIME_`). Whether the **membership** is live is a different fact, and
only `/gp/primecentral` has it — which redirects to sign-in on a remembered
session (`max_auth_age=3600`, measured 2026-11-18).

So:

- If `/gp/primecentral` returns the page (final URL not `/ap/signin`), read the
  state per `amazon-delivery-check` § membership and report it.
- Otherwise report **"Prime membership: not verified (needs re-auth)"** and carry
  on. Search and product pages still show Prime-eligible items and Prime dates;
  say they assume a live membership. Ask the user to sign in in the agent
  browser only if the decision turns on it (a Prime-exclusive price, a free
  Prime shipping threshold).

## Output

One block, reused at the top of every later answer and in `results.json`
(`run.deliver_to`, `run.prime_membership`):

```json
{"domain": "www.amazon.com", "address_id": "home", "zip": "02139",
 "verified_line": "Cambridge 02139", "verified_at": "2026-11-18T14:22:00Z",
 "prime_membership": "unverified-needs-reauth", "browser": "agent-browser"}
```

## Related

- `amazon-address-book` — the account's saved addresses (needs re-auth)
- `amazon-search`, `amazon-spec-shopping` — call this first
- [`reference/browser-route.md`](../../reference/browser-route.md)
