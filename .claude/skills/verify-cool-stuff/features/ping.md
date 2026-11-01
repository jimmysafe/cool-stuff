# Ping

A client GETs `/ping` and gets `{"pong": true}` back with status `200`. It is a liveness check with no inputs and no state. `scripts/smoke.sh` asserts it on every CI run.

## Sub-features

- `ping-get` `GET /ping` returns `200` with `{"pong":true}`.
- `ping-post` a non-GET method on `/ping` returns `404` (Hono doesn't send 405).
- `ping-sub` a deeper path such as `/ping/extra` returns `404`, so the route does not over-match.

## How to get to it (user POV)

- `curl <worker-url>/ping`.

## Driving it with verify.sh

Preconditions:

- Baseline from the [index](./README.md).

- **Ping.** Run `$V drive ping-get GET /ping`. `result.txt` shows `status: 200`, `content-type: application/json`, `body: {"pong":true}`; `server-log.txt` contains `GET /ping 200 OK`.
- **Negative.** Run `$V drive ping-post POST /ping x` and `$V drive ping-sub GET /ping/extra`. Both show `status: 404`, `body: 404 Not Found`.

## Gotchas

- `c.json` writes compact JSON, so the exact body string is `{"pong":true}` with no spaces. `scripts/smoke.sh` compares that exact string.
