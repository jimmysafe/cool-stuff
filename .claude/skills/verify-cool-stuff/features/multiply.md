# Multiply

A client POSTs a JSON body `{"a": number, "b": number}` to `/multiply` and gets `{"product": a * b}` back. Malformed JSON, a missing field, a non-number value (such as the string `"2"`), or a non-object body gets a `400` with a JSON `{"error": "..."}` message instead of a crash, byte-identical (status and body) to `/sum` for the same input.

## Sub-features

- `multiply-ok` two numbers return `200` with their product.
- `multiply-missing` a missing field returns `400` with the numbers error.
- `multiply-string` a string value returns `400` with the numbers error.
- `multiply-malformed` a body that isn't valid JSON returns `400` with the JSON error.
- `multiply-null` a valid JSON body that isn't an object (`null`) returns `400` with the numbers error.

## How to get to it (user POV)

- `curl -X POST -H 'content-type: application/json' --data '{"a":2,"b":3}' <worker-url>/multiply`.

## Driving it with verify.sh

Preconditions:

- Baseline from the [index](./README.md).

- **Multiply.** Run `$V drive multiply-ok POST /multiply '{"a":2,"b":3}'`. `result.txt` shows `status: 200`, `content-type: application/json`, `body: {"product":6}`; `server-log.txt` contains `POST /multiply 200 OK`.
- **Missing field.** Run `$V drive multiply-missing POST /multiply '{"a":2}'`. `status: 400`, `content-type: application/json`, `body: {"error":"\"a\" and \"b\" must be numbers"}`.
- **String value.** Run `$V drive multiply-string POST /multiply '{"a":"2","b":3}'`. Same `400` and body as missing field.
- **Malformed JSON.** Run `$V drive multiply-malformed POST /multiply '{"a":'`. `status: 400`, `body: {"error":"body must be valid JSON"}`.
- **Non-object body.** Run `$V drive multiply-null POST /multiply 'null'`. Same `400` and body as missing field.
- **Negative.** Run `$V drive multiply-get GET /multiply`. `status: 404`, `body: 404 Not Found`, so `/multiply` only answers POST.

## Gotchas

- `drive` passes the body with `curl --data-binary` and no content-type header, so curl sends `application/x-www-form-urlencoded`. `c.req.json()` parses the body regardless of content-type, so the drives above still prove the JSON path. Real clients should still send `application/json`.
- Both routes share one handler factory in `src/index.ts`, so `/multiply` and `/sum` validation can't drift apart.
- Every `400` body is `application/json`. A `500` or a plain-text body means a parse error escaped the handler.
- `1e999` parses to `Infinity` and is rejected as not a number by design.
