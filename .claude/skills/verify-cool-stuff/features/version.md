# Version

A client GETs `/version` and gets `{"version": "<v>"}` back, where `<v>` is exactly the `version` field of `package.json` at build time. It is the same value `/health` reports, without the status field.

## Sub-features

- `version-ok` `GET /version` returns `200` with the package.json version.
- `version-post` a non-GET method on `/version` returns `404` (Hono doesn't send 405).

## How to get to it (user POV)

- `curl <worker-url>/version`.

## Driving it with verify.sh

Preconditions:

- Baseline from the [index](./README.md).

- **Version.** Run `$V drive version-ok GET /version`. `result.txt` shows `status: 200`, `content-type: application/json`, `body: {"version":"<v>"}` with `<v>` equal to `node -p "require('./package.json').version"`; `server-log.txt` contains `GET /version 200 OK`.
- **Negative.** Run `$V drive version-post POST /version`. `status: 404`, `body: 404 Not Found`, so `/version` only answers GET (and HEAD).

## Gotchas

- The version is bundled from `package.json` by the `import { version } from '../package.json'` in `src/index.ts`. workerd has no filesystem, so a version bump only shows after wrangler rebuilds.
- `/version` and `/health` read the same import, so they can't disagree.
