# Pages

The Worker serves a React app with two pages, rendered on the server and hydrated in the browser by `/client.js`. `/` is the Homepage (`<h1>Homepage</h1>` and a link "About" to `/about`). `/about` is the About page (`<h1>About</h1>` and a link "Homepage" to `/`). Clicking a link changes page on the client with React Router, without loading a new document. The pages are the `routes` list in `src/app.tsx`.

## Sub-features

- `pages-home`: `GET /` returns `200`, `text/html; charset=UTF-8`, a document whose `#root` holds `<h1>Homepage</h1>` and `<a href="/about" ...>About</a>`.
- `pages-about`: `GET /about` returns `200` with `<h1>About</h1>` and `<a href="/" ...>Homepage</a>`. A direct URL and a refresh are the same request.
- `pages-query`: `GET '/about?x=1'` returns the same as `pages-about`.
- `pages-head`: `HEAD /about` returns `200`, `text/html; charset=UTF-8`.
- `pages-script`: every page loads `<script type="module" src="/client.js"></script>`.
- `pages-asset`: `GET /client.js` returns `200` JavaScript, served by Wrangler's asset layer from `dist/client/`.
- `pages-client-nav`: clicking "About" on the Homepage, then "Homepage" on About, changes the URL and the heading with no new document request.

## How to get to it (user POV)

- Open `http://<host>/` in a browser and click "About", then "Homepage".
- Open `http://<host>/about` directly, or reload it.

## Driving it with verify.sh

Preconditions:

- `$V doctor` prints `DOCTOR OK` (in `http` mode inside the AgentOS sandbox see the `ps` gotcha in `../SKILL.md`).

- **Homepage.** Run `$V drive pages-home GET /`. `result.txt` reads `status: 200`, `content-type: text/html; charset=UTF-8`, and the body contains `<h1>Homepage</h1>`, `href="/about"`, `>About</a>` and `<script type="module" src="/client.js"></script>`.
- **About.** Run `$V drive pages-about GET /about`. `status: 200`, the same content-type, body contains `<h1>About</h1>`, `href="/"` and `>Homepage</a>`.
- **Query string.** Run `$V drive pages-query GET '/about?x=1'`. Same as `pages-about`.
- **HEAD.** Run `$V drive pages-head HEAD /about`. `status: 200`, `content-type: text/html; charset=UTF-8`.
- **Asset (`http` mode only).** Run `$V drive pages-asset GET /client.js`. `status: 200`, `content-type: text/javascript; charset=utf-8`, about 260 KB. In `inproc` mode report it unverified: the asset layer is not part of the Worker bundle, and the Worker answers `/client.js` with the Not found page.
- **Negative.** Run `$V drive pages-neg GET /about/x`. `status: 404` with the app's Not found page (see [Not found](./not-found.md)).
- **Client navigation.** Not drivable over HTTP. `pnpm run check` proves it in `test/navigation.test.tsx`: it hydrates the server HTML of `/` through `src/client.tsx` in happy-dom, clicks the links, and asserts the click is default prevented (no document load), the URL and heading change, and hydration logs no error. With a real browser against an `http` instance: open `/`, click "About", and check that `server-log-tail.txt` or `logs/wrangler.log` shows no `GET /about` (only the first `GET /` and `GET /client.js`).
- **Proof.** `ls $TMPDIR/verify-cool-stuff-evidence/pages-*/` shows `request.txt`, `response.json`, `result.txt` for each. In `http` mode, `server-log-tail.txt` in `pages-about` shows `GET /about 200 OK`.

## Gotchas

- The anchors carry `data-discover="true"` from React Router. Match `href="/about"` and `>About</a>` separately, not the whole tag.
- `$V drive ... HEAD` in `http` mode uses `curl -I`, so `body:` in `result.txt` is the header dump, not a body. Assert only on `status` and `content-type`. In `inproc` mode the empty HEAD body comes from `inproc-fetch.mjs`, not workerd.
- `wrangler dev` and `wrangler deploy --dry-run` run `pnpm run build:client` first (`build.command` in `wrangler.jsonc`, logged as `[custom build]` in `logs/build.log` or `logs/wrangler.log`). If `/client.js` is missing, look there first.
- The status of a page comes from `statusFor` in `src/app.tsx`, which matches the same `routes` the app renders. A page added there answers 200 with no server change.
