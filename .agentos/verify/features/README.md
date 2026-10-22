# cool-stuff verification map

This directory is the maintained source for verifying the user-facing behavior of cool-stuff, a Hono Worker on
Cloudflare Workers that serves a server-rendered React app over HTTP. Read the index, then use the matching feature file as the recipe.
The harness is `.agentos/verify/scripts/verify.sh` (see `../SKILL.md`), called `$V` below.

## Baseline preconditions

- `V=.agentos/verify/scripts/verify.sh`, run from the repo root.
- `$V launch` printed `READY` for the revision under test, and `$V doctor` prints `DOCTOR OK`.
- No seed data is needed: the Worker is stateless and has no bindings. Its only static asset is `/client.js`.
- Never drive a `wrangler dev` this run did not start.

## Driving conventions

- Every request goes through `$V drive <evidence-name> <METHOD> <path> [body]`. Name evidence `<feature>-<sub-feature>`.
- Assert on the `status`, `content-type` and `body` lines of `result.txt`. Status alone is not proof.
- Treat paths and bodies as literal. Quote them in the shell.

## Proof and skip reporting

- Report the launch mode (`http` or `inproc`) and revision with every proof. They're in each `request.txt`.
- Proof is `request.txt` + `response.json` + `result.txt` per drive, kept under `$TMPDIR/verify-cool-stuff-evidence/`.
- In `inproc` mode, report wire-level behavior (HEAD body stripping, header casing, workerd compat flags) as unverified.
- Do not report a skipped sub-feature as verified through a different one.

## Feature entry contract

Each feature file starts with an H1 and one paragraph, then exactly four H2s in this order: `Sub-features`,
`How to get to it (user POV)`, `Driving it with verify.sh`, `Gotchas`.

## Features

- [Pages](./pages.md): `/` (Homepage) and `/about` (About), server-rendered React pages with client-side navigation between them.
- [Not found](./not-found.md): any other path gets the app's Not found page with 404; a method other than GET or HEAD gets Hono's plain-text 404.
