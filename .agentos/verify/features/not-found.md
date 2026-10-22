# Not found

A GET for a path with no page gets the app's Not found page: status 404, an HTML document with the heading `Not found` and a link to `/`. Any other method, on any path, gets Hono's default response instead: status 404, plain text `404 Not Found`.

## Sub-features

- `nf-path` returns the 404 HTML page for an unknown path.
- `nf-nested` returns the 404 HTML page for a nested unknown path.
- `nf-post`, `nf-post-about` and `nf-delete` return Hono's text 404 for a non-GET method on a page path.
- In the browser, `/nope` renders Not found with status 404, and its Home link navigates without a document request.

## How to get to it (user POV)

- Open any path without a page, e.g. `http://<host>/nope`. Click Home to get back.
- Send data to a page, e.g. `curl -X POST http://<host>/ -d hello`.

## Driving it with verify.sh

Preconditions:

- `$V doctor` prints `DOCTOR OK`.

HTTP evidence:

- **Unknown path.** Run `$V drive nf-path GET /does-not-exist`. `result.txt` reads `status: 404`, `content-type: text/html; charset=utf-8`, `body-bytes: 562`. The body contains `<h1>Not found</h1>` and `<a href="/" data-discover="true">Home</a>`.
- **Nested path.** Run `$V drive nf-nested GET /a/b/c`. Same status, content-type and markers as `nf-path`, `body-bytes: 553`.
- **POST on a page.** Run `$V drive nf-post POST / 'hello'`, then `$V drive nf-post-about POST /about`. Both read `status: 404`, `content-type: text/plain; charset=UTF-8`, `body-bytes: 13`, `body: 404 Not Found`.
- **DELETE on a page.** Run `$V drive nf-delete DELETE /`. Same as `nf-post`.
- **Proof.** Each `$TMPDIR/verify-cool-stuff-evidence/nf-*/result.txt` shows the 404 and its content-type.

Browser evidence (setup in [README](./README.md#browser-preconditions), same single run as the homepage):

- **Lines for this feature.** In `browser-pages/browser-result.txt`: `PASS GET /nope responds 404`, `PASS /nope: heading Not found visible`, `PASS /nope: link Home visible`, `PASS /nope: client script ran and React hydrated the page`, `PASS /nope: click Home goes to /` with its `after click` lines, and `PASS no console errors (hydration mismatches log here)`.
- **Proof.** `not-found.png` and `not-found-to-home.png` in `browser-pages/`.

## Gotchas

- The two 404s differ. GET gets HTML from React Router (`text/html; charset=utf-8`). Other methods fall through `app.get('*')` to Hono (`text/plain; charset=UTF-8`, space before `charset`). Hono answers an unrouted method with 404, not 405.
- `body-bytes` for the HTML 404 grows with the path, because the hydration data embeds `No route matches URL "<path>"`.
- `/assets/client.js` is served by the asset layer, not the Worker. `$V drive nf-asset GET /assets/client.js` hits the Worker in `inproc` mode and gets this 404 HTML page. That is not a bug. Only `browser-check.mjs` serves assets, from `$RUN/src/dist/client`.
- Chrome logs `Failed to load resource ... 404` for the `/nope` document itself. `browser-check.mjs` allows exactly that entry and fails on any other console error.
- If a change adds API routes, `app.notFound` or `app.all`, update this file in the same diff.
