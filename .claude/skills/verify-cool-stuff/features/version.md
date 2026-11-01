# Version

A client GETs `/version` and gets `{"name": "<n>", "version": "<v>"}` back, where `<n>` and `<v>` are exactly the `name` and `version` fields of `package.json` at build time. The version is the same value `/health` reports. `/health` does not report the name.

## Sub-features

- `version-ok` `GET /version` returns `200` with the package.json name and version.
- `version-post` a non-GET method on `/version` returns `404` (Hono doesn't send 405).

## How to get to it (user POV)

- `curl <worker-url>/version`.

## Driving it with verify.sh

Preconditions:

- Baseline from the [index](./README.md).

- **Version.** Run `$V drive version-ok GET /version`. `result.txt` shows `status: 200`, `content-type: application/json`, `body: {"name":"<n>","version":"<v>"}` with `<n>` and `<v>` equal to `node -p "require('./package.json').name"` and `node -p "require('./package.json').version"`; `server-log.txt` contains `GET /version 200 OK`.
- **Negative.** Run `$V drive version-post POST /version`. `status: 404`, `body: 404 Not Found`, so `/version` only answers GET (and HEAD).

## Gotchas

- The name and version are bundled from `package.json` by the `import { name, version } from '../package.json'` in `src/index.ts`. workerd has no filesystem, so a rename or version bump only shows after wrangler rebuilds.
- `/version` and `/health` read the same `version` import, so they can't disagree on it. `/health` still reports only `version`, not `name`.
