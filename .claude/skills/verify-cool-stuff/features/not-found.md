# Not found

Any request that matches no route gets Hono's default plain-text `404 Not Found`, not an error page or a crash.

## Sub-features

- `nf-path` an unknown path returns `404`.
- `nf-post` a known path with an unhandled method returns `404` (Hono doesn't send 405).

## How to get to it (user POV)

- Request any URL other than `/`, or send a non-GET method to `/`.

## Driving it with verify.sh

Preconditions:

- Baseline from the [index](./README.md).

- **Unknown path.** Run `$V drive nf-path GET /does-not-exist`. `result.txt` shows `status: 404`, `content-type: text/plain; charset=UTF-8`, `body: 404 Not Found`.
- **Wrong method.** Run `$V drive nf-post POST / 'hello'`. Same `404` result; `server-log.txt` contains `POST / 404 Not Found`.

## Gotchas

- The 404 content-type has a space before `charset`, unlike `c.text()` responses. That's Hono's default, not a regression.
- If a change adds `app.notFound(...)` or `app.all(...)`, update the expected body here.
