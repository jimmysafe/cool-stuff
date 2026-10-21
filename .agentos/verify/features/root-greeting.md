# Root greeting

A client requesting the site root gets a plain-text greeting, `Hello Hono!`, with status 200, whatever query string it sends.

## Sub-features

- `root-get` returns `200`, `text/plain;charset=UTF-8`, body `Hello Hono!`.
- `root-query` returns the same response when a query string is present.
- `root-head` returns `200` with the same content-type and an empty body.

## How to get to it (user POV)

- Open `http://<host>/` in a browser or `curl http://<host>/`.
- Send `HEAD /` (e.g. `curl -I`), as uptime checkers do.

## Driving it with verify.sh

Preconditions:

- `$V doctor` prints `DOCTOR OK`.

- **GET root.** Request the root. Run `$V drive root-get GET /`. `result.txt` reads `status: 200`, `content-type: text/plain;charset=UTF-8`, `body-bytes: 11`, `body: Hello Hono!`.
- **Query string.** Request the root with a query. Run `$V drive root-query GET '/?utm_source=x&a=1'`. The output is identical to `root-get`.
- **HEAD root.** Run `$V drive root-head HEAD /`. `status: 200`, the same content-type, `body-bytes: 0`.
- **Negative.** Prove the greeting isn't served for neighbours. Run `$V drive root-neg GET /index.html`. `status: 404`, not the greeting (see [Not found](./not-found.md)).
- **Proof.** `ls $TMPDIR/verify-cool-stuff-evidence/root-{get,query,head,neg}/` shows `request.txt`, `response.json`, `result.txt` for each. In `http` mode, `server-log-tail.txt` in `root-get` shows `GET / 200 OK`.

## Gotchas

- The content-type has **no space** before `charset` (`text/plain;charset=UTF-8`, set by `c.text`), unlike the 404 (`text/plain; charset=UTF-8`). Compare exactly.
- In `inproc` mode the empty HEAD body is produced by `inproc-fetch.mjs`, not by workerd, so `root-head` proves only that HEAD routes to the GET handler. Its wire behavior needs `http` mode.
- `GET //` and `GET /?` are not part of the contract. Don't use them as proof.
