# About

A visitor opening `/about` gets the server-rendered About page: status 200, an HTML document with the heading `About` and a link to `/`. A direct load and a refresh both work, so the URL is shareable.

## Sub-features

- `about-get` returns `200`, `text/html; charset=utf-8`, a body with `<h1>About</h1>` and `href="/"`.
- `about-slash` returns the same page for `/about/`.
- In the browser, a direct load and a reload of `/about` render About, and the Home link navigates without a document request.

## How to get to it (user POV)

- Click About on the homepage, or open `http://<host>/about` directly.
- Refresh the page on `/about`. It stays on About.
- Click Home to go back to `/`.

## Driving it with verify.sh

Preconditions:

- `$V doctor` prints `DOCTOR OK`.

HTTP evidence:

- **GET about.** Run `$V drive about-get GET /about`. `result.txt` reads `status: 200`, `content-type: text/html; charset=utf-8`, `body-bytes: 379`. The body contains `<h1>About</h1>` and `<a href="/" data-discover="true">Home</a>`.
- **Trailing slash.** Run `$V drive about-slash GET /about/`. The output is identical to `about-get`.
- **Negative.** A POST to `/about` does not render the page. See `nf-post-about` in [Not found](./not-found.md).
- **Proof.** `$TMPDIR/verify-cool-stuff-evidence/about-{get,slash}/` each hold `request.txt`, `response.json`, `result.txt`.

Browser evidence (setup in [README](./README.md#browser-preconditions), same single run as the homepage):

- **Lines for this feature.** In `browser-pages/browser-result.txt`: `PASS GET /about directly responds 200`, `PASS /about direct: heading About visible`, `PASS /about direct: link Home visible`, `PASS /about direct: client script ran and React hydrated the page`, `PASS /about reload responds 200`, `PASS /about reload: one new document request and window.__marker cleared`, `PASS /about reload: still on /about`, `PASS /about reload: heading About visible`, and `PASS /about: click Home goes to /` with its `after click` lines.
- **Proof.** `about.png` and `about-reload.png` in `browser-pages/`.

## Gotchas

- `/about` and `/about/` render the same page with no redirect. A change that adds a canonical redirect updates `about-slash` here.
- The Home link is `href="/"`, which also matches inside other attributes. Assert on `<h1>About</h1>` first.
- The reload line also proves the marker check works: a real document load clears `window.__marker` and adds one document request.
