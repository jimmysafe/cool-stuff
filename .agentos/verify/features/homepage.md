# Homepage

A visitor opening the site root gets the server-rendered Home page: status 200, an HTML document with the heading `Home` and a link to `/about`. The client script `/assets/client.js` then hydrates the page, so the About link navigates without a new document load.

## Sub-features

- `home-get` returns `200`, `text/html; charset=utf-8`, a body with `<h1>Home</h1>` and `href="/about"`.
- `home-query` returns the same page when a query string is present.
- `home-head` returns `200` with the same content-type and an empty body.
- In the browser, the page renders, hydrates and moves to About and back without a document request.

## How to get to it (user POV)

- Open `http://<host>/` in a browser. The page shows the heading Home and a link About.
- Click About, then Home on the About page. The URL changes and the heading swaps without a full page load.
- `curl http://<host>/` returns the HTML.

## Driving it with verify.sh

Preconditions:

- `$V doctor` prints `DOCTOR OK`.

HTTP evidence:

- **GET root.** Run `$V drive home-get GET /`. `result.txt` reads `status: 200`, `content-type: text/html; charset=utf-8`, `body-bytes: 384`. The body contains `<h1>Home</h1>`, `href="/about"` and `<script type="module" src="/assets/client.js">`.
- **Query string.** Run `$V drive home-query GET '/?utm_source=x&a=1'`. The output is identical to `home-get`.
- **HEAD root.** Run `$V drive home-head HEAD /`. `status: 200`, the same content-type, `body-bytes: 0`.
- **Negative.** A POST to `/` does not render the page. See `nf-post` in [Not found](./not-found.md).
- **Proof.** `$TMPDIR/verify-cool-stuff-evidence/home-{get,query,head}/` each hold `request.txt`, `response.json`, `result.txt`.

Browser evidence (setup in [README](./README.md#browser-preconditions), launched with `VERIFY_MODE=inproc`):

- **Run.** `node .agentos/verify/scripts/browser-check.mjs "$RUN/bundle/index.js" "$RUN/src/dist/client" "$TMPDIR/verify-cool-stuff-evidence/browser-pages"`. It exits 0 and prints `browser-check: all 31 PASS`.
- **Lines for this feature.** In `browser-pages/browser-result.txt`: `PASS GET / responds 200`, `PASS /: heading Home visible`, `PASS /: link About visible`, `PASS /: client script ran and React hydrated the page`, `PASS /: /assets/client.js loaded with 200`, and the `after click` lines for `/about` and back to `/` (`window.__marker survived`, `no new document request`).
- **Proof.** `browser-result.txt` plus `home.png`, `home-to-about.png`, `about-to-home.png` in the same directory.

## Gotchas

- The 200 content-type is lowercase `text/html; charset=utf-8`, set by `renderPage`. Hono's 404 text uses `text/plain; charset=UTF-8`. Compare exactly.
- The body also carries `data-discover="true"` on the link and a `window.__staticRouterHydrationData` script. Assert on substrings, not the whole body.
- `body-bytes` changes with any markup change. Treat it as a snapshot of this revision, not part of the contract.
- In `inproc` mode the empty HEAD body comes from `inproc-fetch.mjs`, not from workerd. `home-head` proves only that HEAD routes to the GET handler.
- HTTP drives alone do not prove hydration or client navigation. Only `browser-check.mjs` does.
