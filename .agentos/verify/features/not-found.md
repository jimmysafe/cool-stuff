# Not found

A `GET` or `HEAD` for a path outside the app's pages gets the app's Not found page: status 404, `text/html; charset=UTF-8`, `<h1>Not found</h1>` and a link "Homepage" to `/`. Any other method on any path keeps Hono's plain-text `404 Not Found`. Both come from `app.notFound` in `src/index.ts`, so a route registered on the Hono app always wins over them.

## Sub-features

- `nf-path` returns the Not found page with 404 for an unknown path.
- `nf-nested` returns the same for a nested unknown path.
- `nf-method` returns plain-text 404 (not 405) for `POST`, `PUT` or `DELETE` on `/`, where only the pages answer GET.

## How to get to it (user POV)

- Open any path that is not a page, e.g. `http://<host>/nope`. The browser shows "Not found" and a link back to the Homepage.
- Submit data to the root, e.g. `curl -X POST http://<host>/ -d hello`.

## Driving it with verify.sh

Preconditions:

- `$V doctor` prints `DOCTOR OK`.

- **Unknown path.** Run `$V drive nf-path GET /nope`. `result.txt` reads `status: 404`, `content-type: text/html; charset=UTF-8`, and the body contains `<h1>Not found</h1>` and `href="/"`.
- **Nested path.** Run `$V drive nf-nested GET /a/b/c`. Same as `nf-path`.
- **Wrong method on root.** Run `$V drive nf-method-post POST / 'hello'`, then `$V drive nf-method-delete DELETE /`. Both give `status: 404`, `content-type: text/plain; charset=UTF-8`, `body: 404 Not Found`.
- **Proof.** Each `$TMPDIR/verify-cool-stuff-evidence/nf-*/result.txt` shows the 404. In `http` mode, `server-log-tail.txt` shows `404 Not Found` for the same request.

## Gotchas

- The Not found page is the app's, rendered by React. Wrangler's or Cloudflare's own error page means you hit the wrong server.
- In `inproc` mode `GET /client.js` also returns the Not found page, because the asset layer is outside the Worker bundle. In `http` mode the asset layer answers it first.
- Hono answers an unrouted method with 404, not 405. If a change adds `app.all` or method handlers, update this file in the same diff.
- The plain 404 content-type has a space before `charset` (`text/plain; charset=UTF-8`).
