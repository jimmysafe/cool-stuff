---
name: verify-cool-stuff
description: Launch, drive and prove the behavior of cool-stuff, a Hono app on Cloudflare Workers that server-renders React Router pages (single Worker, `src/index.ts`, static assets in `dist/client`, no bindings). Reach for it whenever a change to pages, routes, responses or wrangler config needs proof over HTTP and in a real headless browser; works inside the AgentOS sandbox (no TCP listen) via the in-process mode.
---

# verify-cool-stuff

cool-stuff is one Cloudflare Worker (`wrangler.jsonc`: `main: src/index.ts`, no KV/R2/D1/vars)
built with Hono. `app.get('*')` server-renders React Router pages (`src/app/routes.tsx`), and
`/assets/client.js` hydrates them. Workers Static Assets serves `dist/client/`, which `build.command`
(`pnpm run build:client`) writes before each wrangler build. The surfaces are **HTTP** and the pages in a **browser**.
There is no CLI or database. Today the routes are `GET /` (Home, 200 HTML), `GET /about` (About, 200 HTML),
`GET` on any other path (Not found, 404 HTML), and Hono's text `404 Not Found` for every non-GET request.
The feature map is in [`features/`](features/README.md).

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
`VERIFY_MODE=http $V launch && $V doctor && $V drive home-get GET /` and then `$V cleanup`, fix what breaks, and delete this paragraph.
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
$V drive home-get GET /
$V drive home-head HEAD /
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
status: 404
content-type: text/plain; charset=UTF-8
body-bytes: 13
body: 404 Not Found
```

`drive` reaches the Worker only. It never serves static assets, so `GET /assets/client.js` gets the 404 HTML page
in `inproc` mode. Rendering, hydration and client navigation need the browser check below.

## Browser

`scripts/browser-check.mjs <bundle/index.js> <assets-dir> <evidence-dir>` is a real headless Chromium run with no TCP server.
`page.route('**/*')` answers every request to the fake origin `http://cool-stuff.test` the way Cloudflare does:
a path that is a file under `<assets-dir>` comes from disk, anything else goes to the bundle's `default.fetch`.
It loads `/`, `/about` and `/nope`, waits for hydration (`window.__reactRouterVersion` set and React fibers on the links),
clicks the links, and asserts the heading, the URL, the status, that `window.__marker` survives a click and that no
document request happens. It also reloads `/about` and fails on page errors and console errors.
It writes `browser-result.txt` (one PASS/FAIL line per assertion) and a screenshot per page, and exits 1 on any FAIL.

It needs the inproc bundle, so launch with `VERIFY_MODE=inproc`. The setup commands and the run line are in
[`features/README.md`](features/README.md#browser-preconditions): `playwright-core@1.56.1` in `$TMPDIR/pw`
(env `PLAYWRIGHT_CORE`) and Playwright's Chromium headless shell build 1194 (env `HEADLESS_SHELL`), launched with
`--single-process`. Neither is a repo dependency. The assets dir is `<run>/src/dist/client`, which the dry-run's
`build.command` produces. Evidence goes to `$TMPDIR/verify-cool-stuff-evidence/browser-pages/`.

A run with an empty assets dir is the negative control: the hydration, marker and document-request lines fail.

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
- `scripts/browser-check.mjs <bundle/index.js> <assets-dir> <evidence-dir>`: headless browser check of the pages (see Browser).

## Sandbox notes

- TCP listen refused → `inproc` (auto). Real `$HOME` unreadable/unwritable → all homes under `$TMPDIR`.
  Node's package-scope lookup walks up to `$HOME` → `bundle/package.json` stops it.
- `pnpm` may be absent from the host. Launch bootstraps it via `npm install -g --prefix $VERIFY_TOOLS_DIR pnpm@10`, so the npm registry is needed on first run.
- Shell heredocs fail in the sandbox (`can't create temp file`); write files with tools instead.
- Apple `git` prints harmless `xcrun_db ... Operation not permitted` warnings. Ignore them.
- wrangler warns `Proxy environment variables detected`. That's harmless.
