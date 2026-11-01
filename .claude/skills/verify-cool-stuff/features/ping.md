# Ping

A client GETs `/ping` and gets `{"pong": true}` back as JSON. It is a liveness check with no input and no state.

## Sub-features

- `ping-ok` `GET /ping` returns `200` with `{"pong":true}`.
- `ping-post` a non-GET method on `/ping` returns `404` (Hono doesn't send 405).

## How to get to it (user POV)

- `curl <worker-url>/ping`.

## Driving it with verify.sh

Preconditions:

- Baseline from the [index](./README.md).

- **Ping.** Run `$V drive ping-ok GET /ping`. `result.txt` shows `status: 200`, `content-type: application/json`, `body: {"pong":true}`; `server-log.txt` contains `GET /ping 200 OK`.
- **Negative.** Run `$V drive ping-post POST /ping`. `status: 404`, `body: 404 Not Found`, so `/ping` only answers GET (and HEAD).

## Gotchas

- `/ping` reports no version. Use `/health` or `/version` for that.
