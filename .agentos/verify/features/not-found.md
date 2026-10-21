# Not found

Any request that matches no route gets Hono's default response: status 404, plain text `404 Not Found`. That covers an unknown path or a method the root does not handle.

## Sub-features

- `nf-path` returns 404 for an unknown path.
- `nf-nested` returns 404 for a nested unknown path.
- `nf-method` returns 404 (not 405) for `POST`, `PUT` or `DELETE` on `/`, where only GET is routed.

## How to get to it (user POV)

- Open any path other than `/`, e.g. `http://<host>/does-not-exist`.
- Submit data to the root, e.g. `curl -X POST http://<host>/ -d hello`.

## Driving it with verify.sh

Preconditions:

- `$V doctor` prints `DOCTOR OK`.

- **Unknown path.** Run `$V drive nf-path GET /does-not-exist`. `result.txt` reads `status: 404`, `content-type: text/plain; charset=UTF-8`, `body: 404 Not Found`.
- **Nested path.** Run `$V drive nf-nested GET /a/b/c`. Same as `nf-path`.
- **Wrong method on root.** Run `$V drive nf-method-post POST / 'hello'`, then `$V drive nf-method-delete DELETE /`. Both give `status: 404`, `body: 404 Not Found`.
- **Proof.** Each `$TMPDIR/verify-cool-stuff-evidence/nf-*/result.txt` shows the 404. In `http` mode, `server-log-tail.txt` shows `404 Not Found` for the same request.

## Gotchas

- The body is Hono's default text, not wrangler's or Cloudflare's error page. A Cloudflare/HTML 404 means you hit the wrong server.
- Hono answers an unrouted method with 404, not 405. If a change adds `app.notFound`, `app.all` or method handlers, update this file in the same diff.
- The 404 content-type has a space before `charset` (`text/plain; charset=UTF-8`).
