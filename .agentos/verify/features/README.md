# cool-stuff verification map

This directory is the maintained source for verifying the user-facing behavior of cool-stuff, a Hono Worker on
Cloudflare Workers that server-renders React Router pages. Its surfaces are HTTP responses and the hydrated pages in a browser.
Read the index, then use the matching feature file as the recipe.
The harness is `.agentos/verify/scripts/verify.sh` (see `../SKILL.md`), called `$V` below.

## Baseline preconditions

- `V=.agentos/verify/scripts/verify.sh`, run from the repo root.
- `$V launch` printed `READY` for the revision under test, and `$V doctor` prints `DOCTOR OK`.
- No seed data is needed: the Worker is stateless and has no bindings.
- Never drive a `wrangler dev` this run did not start.

## Browser preconditions

The browser check needs the bundle, so launch in `inproc` mode. Setup, once per `$TMPDIR` (macOS arm64; on x86_64 use `chromium-headless-shell-mac.zip`):

```sh
(mkdir -p "$TMPDIR/pw" && cd "$TMPDIR/pw" && npm init -y && npm install --cache "$TMPDIR/verify-tools/npm-cache" playwright-core@1.56.1)
mkdir -p "$TMPDIR/shell" && curl -sSfL -o "$TMPDIR/shell/shell.zip" https://cdn.playwright.dev/builds/chromium/1194/chromium-headless-shell-mac-arm64.zip
ditto -x -k "$TMPDIR/shell/shell.zip" "$TMPDIR/shell"
```

`npm install` needs `--cache` because the sandbox cannot write `~/.npm` (`EPERM`). The headless shell is the
binary Playwright 1.56 pins (Chromium build 1194). Use it, not an installed Chrome, and keep `--single-process` (the script sets it).
Then, from the repo root:

```sh
VERIFY_MODE=inproc $V launch
RUN="$($V paths | sed -n 's/^run_dir=//p')"
PLAYWRIGHT_CORE="$TMPDIR/pw/node_modules/playwright-core" HEADLESS_SHELL="$TMPDIR/shell/chrome-mac/headless_shell" \
  node .agentos/verify/scripts/browser-check.mjs "$RUN/bundle/index.js" "$RUN/src/dist/client" "$TMPDIR/verify-cool-stuff-evidence/browser-pages"
```

## Driving conventions

- Every request goes through `$V drive <evidence-name> <METHOD> <path> [body]`. Name evidence `<feature>-<sub-feature>`.
- Assert on the `status`, `content-type` and `body` lines of `result.txt`. Status alone is not proof.
- Keep HTTP evidence (`$V drive` dirs) and browser evidence (`browser-pages/`) apart. Report each on its own.
- Treat paths and bodies as literal. Quote them in the shell.

## Proof and skip reporting

- Report the launch mode (`http` or `inproc`) and revision with every proof. They're in each `request.txt`.
- HTTP proof is `request.txt` + `response.json` + `result.txt` per drive, kept under `$TMPDIR/verify-cool-stuff-evidence/`.
- Browser proof is `browser-pages/browser-result.txt` plus one screenshot per page, in the same evidence dir.
- In `inproc` mode, report wire-level behavior (HEAD body stripping, header casing, workerd compat flags) as unverified.
- Do not report a skipped sub-feature as verified through a different one.

## Feature entry contract

Each feature file starts with an H1 and one paragraph, then exactly four H2s in this order: `Sub-features`,
`How to get to it (user POV)`, `Driving it with verify.sh`, `Gotchas`.

## Features

- [Homepage](./homepage.md): `GET /` renders Home with a link to About. In the browser it hydrates and navigates client-side.
- [About](./about.md): `GET /about` renders About with a link to Home, on a direct load and a refresh.
- [Not found](./not-found.md): `GET` on an unknown path renders the 404 HTML page. Any other method returns Hono's text 404.
