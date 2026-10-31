# cool-stuff verification map

The maintained source for verifying cool-stuff's user-facing HTTP behavior. Read this index, then use the matching feature file as the recipe.

## Baseline preconditions

- `$V launch` printed `READY` and `$V doctor` printed `DOCTOR OK` (`V=.claude/skills/verify-cool-stuff/scripts/verify.sh`).
- The instance was started by this run. Never drive the user's own `wrangler dev` on `:8787`.

## Driving conventions

- Every action is `$V drive <evidence-name> <METHOD> <path> [body]`; evidence names are the sub-feature IDs below.
- Route handles are method + path as written in `src/index.ts`.

## Proof and skip reporting

- Assert on `result.txt`: status, content-type and body together.
- `server-log.txt` must show wrangler logging the same request.
- Report the revision from `request.txt`, including `+dirty`.
- An unreachable path is reported with the command run and the unmet precondition, never as verified via another route.

## Feature entry contract

Each feature file has an H1, one paragraph of user-visible behavior, then four H2s: `Sub-features`, `How to get to it (user POV)`, `Driving it with verify.sh`, `Gotchas`.

## Features

- [Root greeting](./root-greeting.md): `GET /` (and `HEAD /`) returns the plain-text greeting.
- [Not found](./not-found.md): any unmatched path or method gets Hono's plain-text 404.
- [Sum](./sum.md): `POST /sum` with `{"a", "b"}` returns their sum, bad input gets a JSON `400`.
- [Multiply](./multiply.md): `POST /multiply` with `{"a", "b"}` returns their product, bad input gets the same JSON `400` as `/sum`.
