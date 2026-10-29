# Root greeting

A client requesting the Worker's root URL gets a plain-text greeting, `Hello Hono!`.

## Sub-features

- `root-get` returns `200`, `text/plain;charset=UTF-8`, body `Hello Hono!`.
- `root-head` returns `200` with the same content-type and no body.

## How to get to it (user POV)

- Open the Worker URL in a browser or `curl` it with no path.

## Driving it with verify.sh

Preconditions:

- Baseline from the [index](./README.md).

- **GET.** Run `$V drive root-get GET /`. `result.txt` shows `status: 200`, `content-type: text/plain;charset=UTF-8`, `body-bytes: 11`, `body: Hello Hono!`; `server-log.txt` contains `GET / 200 OK`.
- **HEAD.** Run `$V drive root-head HEAD /`. `status: 200`, `body-bytes: 0`.
- **Negative.** Run the `nf-post` step from [Not found](./not-found.md) to show `/` only answers GET/HEAD.

## Gotchas

- `/` is matched exactly; `/?x=1` still hits it, `//` does not.
