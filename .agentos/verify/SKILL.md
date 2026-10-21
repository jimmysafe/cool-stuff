---
name: verify-cool-stuff
description: Launch, drive and prove the HTTP behavior of cool-stuff, a Hono app on Cloudflare Workers (single Worker, `src/index.ts`, no bindings). Reach for it whenever a change to routes, responses or wrangler config needs proof that the Worker answers HTTP requests correctly; works inside the AgentOS sandbox (no TCP listen) via the in-process mode.
---

# verify-cool-stuff

cool-stuff is one Cloudflare Worker (`wrangler.jsonc`: `main: src/index.ts`, no KV/R2/D1/vars)
built with Hono. Its only user surface is **HTTP**: a client sends a request, the Worker answers.
There is no UI, CLI or database. Today the routes are `GET /` → `200 text/plain "Hello Hono!"` and
Hono's default `404 Not Found` for everything else. The feature map is in [`features/`](features/README.md).

All commands run from the repo root (the worktree). The only helper is `.agentos/verify/scripts/verify.sh`;
call it as `V=.agentos/verify/scripts/verify.sh` and then `$V <subcommand>`.

| Path | What | Removed by cleanup |
|---|---|---|
| `$TMPDIR/verify-cool-stuff/` (`VERIFY_RUN_DIR`) | source export, node_modules, wrangler home/logs, bundle, pid/port/mode files | yes |
| `$TMPDIR/verify-cool-stuff-evidence/` (`VERIFY_EVIDENCE_DIR`) | proof artifacts, one dir per drive, plus `_logs/` | **never** |
| `$TMPDIR/verify-tools/` (`VERIFY_TOOLS_DIR`) | pnpm bootstrap, pnpm store, npm cache, reused across runs | no (cache) |

`$V paths` prints the three resolved paths. Nothing is written to the worktree or the real `$HOME`.

## Modes: why there are two

The AgentOS sandbox refuses **every** TCP `listen()` (any port, any interface, even port 0: `EPERM`),
so `wrangler dev` cannot serve there. `verify.sh launch` probes a loopback listen and picks:

- **`http`**: `wrangler dev` (real workerd runtime) on `127.0.0.1:<free port>`, driven with `curl`.
  This is the faithful path; use it whenever the host allows it.
- **`inproc`**: `wrangler deploy --dry-run --outdir` builds the **exact bundle wrangler would upload**
  (no upload, no auth, no network needed: verified with proxies pointed at a dead port), then
  `scripts/inproc-fetch.mjs` imports it on Node and calls `default.fetch(new Request(...), env={}, ctx)`,
  the same entry point workerd invokes per request. It's the same code and the same Request/Response objects, on Node instead of workerd.

**Status of `http` mode: written but never executed.** The host where this skill was generated refused loopback listen
even outside the sandbox, so `wrangler dev` startup, the `Ready on` detection, the doctor's lsof/pgid check and
process-group cleanup are unproven. The first agent on a host that allows listen should run
`VERIFY_MODE=http $V launch && $V doctor && $V drive root-get GET /` and then `$V cleanup`, fix what breaks, and delete this paragraph.
Forced `http` on a no-listen host fails fast with `http mode: loopback TCP listen refused`.

Force a mode with `VERIFY_MODE=http` or `VERIFY_MODE=inproc`. Every artifact records its mode
(`request.txt` → `mode:`). **Report the mode in the proof.** An `inproc` proof does not cover workerd-only
behavior (compatibility_date semantics, wire-level header normalisation, HEAD body stripping on the wire,
`cloudflare:` imports, bindings). If a change touches those, say they are unverified, or rerun in `http` mode outside the sandbox.

## Launch

```sh
V=.agentos/verify/scripts/verify.sh
$V launch            # export HEAD with `git archive` (committed code only)
$V launch <rev>      # any commit/branch
$V launch --worktree # tracked + untracked non-ignored files, to check an uncommitted change
```

What it does: wipes and recreates `$VERIFY_RUN_DIR`, exports the source into `src/`, points `HOME`,
`XDG_*`, `WRANGLER_LOG_PATH`, the npm cache and the pnpm store under `$TMPDIR`, bootstraps `pnpm@10` into
`$VERIFY_TOOLS_DIR` if none is on PATH (needs the npm registry once), then runs `pnpm install` (log: `logs/install.log`).

- `http` mode: starts `wrangler dev --ip 127.0.0.1 --port <free> --inspector-port <free> --persist-to <run>/state`
  in its own process group (log: `logs/wrangler.log`). **Ready** = the log contains `Ready on http://127.0.0.1:<port>`
  **and** `GET /` gets an HTTP answer. Prints `READY mode=http url=... pid=...`.
- `inproc` mode: builds `bundle/index.js` (log: `logs/build.log`, must contain `--dry-run: exiting now`),
  writes `bundle/package.json` = `{"type":"module"}`, and calls the handler once. **Ready** = that probe returns
  JSON. Prints `READY mode=inproc bundle=... probe={"status":200,...}`.

There is no seed data or migration: the Worker is stateless. A launch takes ~15 s (install dominates).
Launch refuses to start if an `http` instance from the same `VERIFY_RUN_DIR` is still alive. To run
two side by side, give each its own `VERIFY_RUN_DIR` (ports are picked free automatically; `VERIFY_PORT`
pins one). Never drive a `wrangler dev` you didn't start: the user's own one is usually on `:8787`.

## Doctor

```sh
$V doctor   # read-only; exit 0 + "DOCTOR OK" when worth driving
```

Always prints `mode` and `revision` (serving vs worktree HEAD; if they differ you're testing a different
commit than you think). `http`: pid alive, port listened by **our** process group (lsof + pgid), `GET /`
answers, `Ready on` logged. `inproc`: bundle present and newer than the source export, handler answers `GET /`.
Run it first whenever anything looks off.

## Drive

```sh
$V drive <evidence-name> <METHOD> <path> [body]
$V drive root-get GET /
$V drive root-head HEAD /
$V drive nf-path GET /does-not-exist
$V drive nf-post POST / 'hello'
```

Same command in both modes. `http` uses `curl` against the instance; `inproc` uses
`node .agentos/verify/scripts/inproc-fetch.mjs <run>/bundle/index.js <METHOD> <path> [body]`
(you can call it directly for ad-hoc checks; it prints `{status,statusText,headers,body}` JSON).
The handles are **route paths and methods**. Routes are defined in `src/index.ts` (`app.get(...)`, etc.).
When a route is added, drive it the same way and add it to the feature map.

Prints and saves `result.txt`:

```
status: 200
content-type: text/plain;charset=UTF-8
body-bytes: 11
body: Hello Hono!
```

## Evidence

Every drive writes `$VERIFY_EVIDENCE_DIR/<evidence-name>/`:

- `request.txt`: revision, mode, UTC time, method and path, the exact command run
- `response.json`: status, all headers, full body
- `result.txt`: the summary above (what you assert on)
- `server-log-tail.txt` (`http` only): wrangler's request log line (e.g. `[wrangler:info] GET / 200 OK`), the server-side view of the same request

Cleanup copies `install.log`, `build.log` / `wrangler.log` into `$VERIFY_EVIDENCE_DIR/_logs/`.

Proof standards:
- Drive the real request path (the Worker's `fetch` entry point via HTTP or the built bundle). Never import `src/index.ts`
  and call Hono internals, never add a test-only route.
- Capture the request and the response together (request.txt + response.json), and assert on status, content-type **and** body,
  not just the status code.
- A negative check (404, wrong method) is part of a route's proof: show the route doesn't also match what it shouldn't.
- The Worker has no side effects today (no bindings). If a change adds KV/D1/R2, prove the write with a second
  read request, and note that `inproc` passes `env = {}` (bindings absent). Such a feature must be proven in `http` mode.
- `wrangler deploy` without `--dry-run` publishes to Cloudflare. **Never run it.** `--dry-run` was observed to
  produce `bundle/` and exit with no upload or auth.
- State the mode and revision in your report.

## Cleanup

```sh
$V cleanup
```

Kills only the process group recorded in `<run>/pid` (wrangler + its workerd), TERM then KILL. It never kills by name.
It copies logs into the evidence dir, then deletes `$VERIFY_RUN_DIR`. Evidence and the tools cache stay.
Run it after every attempt, failed ones too; it's safe when nothing is running. Afterwards check
`ls $TMPDIR/verify-cool-stuff-evidence/<name>/result.txt` still exists.

## Helpers

- `scripts/verify.sh`: `launch [<rev>|--worktree] | doctor | drive <name> <METHOD> <path> [body] | cleanup | paths`.
  Env: `VERIFY_MODE` (auto|http|inproc), `VERIFY_RUN_DIR`, `VERIFY_EVIDENCE_DIR`, `VERIFY_TOOLS_DIR`, `VERIFY_PORT`.
- `scripts/inproc-fetch.mjs <bundle/index.js> <METHOD> <path> [body]`: calls the bundle's fetch handler and prints JSON.

## Sandbox notes

- TCP listen refused → `inproc` (auto). Real `$HOME` unreadable/unwritable → all homes under `$TMPDIR`.
  Node's package-scope lookup walks up to `$HOME` → `bundle/package.json` stops it.
- `pnpm` may be absent from the host. Launch bootstraps it via `npm install -g --prefix $VERIFY_TOOLS_DIR pnpm@10`, so the npm registry is needed on first run.
- Shell heredocs fail in the sandbox (`can't create temp file`); write files with tools instead.
- Apple `git` prints harmless `xcrun_db ... Operation not permitted` warnings. Ignore them.
- wrangler warns `Proxy environment variables detected`. That's harmless.
