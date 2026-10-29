#!/usr/bin/env bash
# Smoke test for CI: start the Worker under wrangler dev and check / and an unmatched path.
set -euo pipefail
PORT=${PORT:-8799}
URL=http://127.0.0.1:$PORT
pnpm exec wrangler dev --ip 127.0.0.1 --port "$PORT" > wrangler-smoke.log 2>&1 &
trap 'kill $! 2>/dev/null || true' EXIT
for _ in $(seq 60); do curl -sf "$URL/" >/dev/null && break; sleep 1; done

check() { # <name> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; cat wrangler-smoke.log; exit 1; fi
}
check "GET / status" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/")"
check "GET / body" "Hello Hono!" "$(curl -s "$URL/")"
check "GET /does-not-exist status" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/does-not-exist")"
