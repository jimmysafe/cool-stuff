---
name: verify-cool-stuff
description: Launch, drive and prove the HTTP behavior of cool-stuff, a Hono app on Cloudflare Workers (`src/index.ts`, no bindings), by running it under `wrangler dev` and hitting it with curl. Reach for it whenever a change to routes, responses or `wrangler.jsonc` needs proof that the Worker actually answers requests correctly.
---

# verify-cool-stuff

cool-stuff is one Cloudflare Worker (`wrangler.jsonc` → `main: src/index.ts`, no KV/R2/D1/vars) built with Hono.
Its only user surface is **HTTP**. There is no UI, CLI, database or seed data. Feature map: [`features/`](features/README.md).

Everything goes through one helper, run from the repo root:

```sh
V=.claude/skills/verify-cool-stuff/scripts/verify.sh
$V paths   # prints run dir, evidence dir, repo
```

| Path | Holds | Removed by cleanup |
|---|---|---|
| `$TMPDIR/verify-cool-stuff-run/` (`VERIFY_RUN_DIR`) | pid, url, revision, `wrangler.log`, `--persist-to` state | yes |
| `$TMPDIR/verify-cool-stuff-evidence/` (`VERIFY_EVIDENCE_DIR`) | one dir per drive + `_logs/` | **never** |

## Launch

```sh
$V launch
```

Runs `pnpm install` only if `node_modules/.bin/wrangler` is missing (creates an untracked `pnpm-lock.yaml`; the repo commits none), then starts
`wrangler dev --ip 127.0.0.1 --port <free> --inspector-port <free> --persist-to <run>/state` in its own process group.
**Ready** = `wrangler.log` contains `Ready on http://127.0.0.1:<port>` **and** `GET /` answers. Prints
`READY url=... pid=... revision=<sha>[+dirty]`. Startup takes ~3 s once deps exist.

It serves the **working tree** (wrangler bundles `src/` live and hot-reloads on save), so uncommitted changes are what you test;
`+dirty` in the revision flags that. The Worker is stateless: no migrations or seeds.

Isolation: launch refuses if an instance from the same `VERIFY_RUN_DIR` is alive. Two side by side → give each its own
`VERIFY_RUN_DIR` and `VERIFY_EVIDENCE_DIR` (ports are picked free; `VERIFY_PORT` pins one). Never drive a `wrangler dev`
you didn't start; the user's own `pnpm dev` usually sits on `:8787`.

## Doctor

```sh
$V doctor   # read-only; exit 0 + "DOCTOR OK"
```

Checks: our pid alive, the port's listener is in **our** process group (lsof + pgid), `GET /` answers. Prints the
serving revision next to the worktree HEAD. Run it first whenever anything looks off.

## Drive

```sh
$V drive <evidence-name> <METHOD> <path> [body]
$V drive root-get  GET  /
$V drive root-head HEAD /
$V drive nf-path   GET  /does-not-exist
$V drive nf-post   POST / 'hello'
```

Handles are **methods + route paths**; routes live in `src/index.ts` (`app.get('/', ...)`). New route → drive it the same way
and add it to the feature map. Output (also saved as `result.txt`):

```
status: 200
content-type: text/plain;charset=UTF-8
body-bytes: 11
body: Hello Hono!
```

## Evidence

Each drive writes `$VERIFY_EVIDENCE_DIR/<evidence-name>/`: `request.txt` (time, revision, method/path/body, exact curl),
`headers.txt`, `body.txt`, `result.txt` (what you assert on) and `server-log.txt` (wrangler's own line for the request, e.g.
`[wrangler:info] GET / 200 OK (2ms)`, the server-side view). Cleanup copies `wrangler.log` to `_logs/`.

Proof standards:
- Drive the real path: HTTP against `wrangler dev` (workerd). Never import `src/index.ts` and call Hono directly, never add a test-only route.
- Assert status, content-type **and** body, not just the status code.
- Include a negative check (unmatched path or method) so a route is shown not to over-match.
- No side effects exist today. If a change adds a binding (KV/D1/R2), prove the write with a second read request and check `<run>/state`.
- **Never run `pnpm deploy` / `wrangler deploy`**: it publishes to Cloudflare.
- Report the revision (and `+dirty`) in the proof.

## Cleanup

```sh
$V cleanup
```

TERM then KILL to the process group in `<run>/pid` only (wrangler + its workerd child), never by name. Copies logs into
evidence, deletes the run dir. Safe when nothing runs; run it after every attempt, failed ones too. Then confirm
`ls "$TMPDIR/verify-cool-stuff-evidence/<name>/result.txt"` still exists.

## Gotchas

- macOS has no `setsid`; the helper uses bash `set -m` to get a process group. Don't "simplify" that away or cleanup will orphan workerd.
- Hono's 404 has `content-type: text/plain; charset=UTF-8` (with a space); `c.text()` gives `text/plain;charset=UTF-8`. Don't treat that difference as a bug.
- HEAD on `/` returns 200 with empty body (Hono maps HEAD to GET handlers).
