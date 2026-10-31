#!/usr/bin/env bash
# Smoke test for CI: start the Worker under wrangler dev and check /, an unmatched path, POST /sum and POST /multiply.
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
sum() { curl -s -X POST -H 'content-type: application/json' --data-binary "$@" "$URL/sum"; }
check "POST /sum status" 200 "$(sum '{"a":2,"b":3}' -o /dev/null -w '%{http_code}')"
check "POST /sum body" '{"sum":5}' "$(sum '{"a":2,"b":3}')"
multiply() { curl -s -X POST -H 'content-type: application/json' --data-binary "$@" "$URL/multiply"; }
check "POST /multiply status" 200 "$(multiply '{"a":2,"b":3}' -o /dev/null -w '%{http_code}')"
check "POST /multiply body" '{"product":6}' "$(multiply '{"a":2,"b":3}')"
for bad in '{"a":2}' '{"a":"2","b":3}' '{"a":' 'null'; do
  check "POST /sum $bad status" 400 "$(sum "$bad" -o /dev/null -w '%{http_code}')"
  check "POST /sum $bad error body" yes "$(sum "$bad" | grep -q '"error":"[^"]' && echo yes || echo no)"
  check "POST /multiply $bad status matches /sum" "$(sum "$bad" -o /dev/null -w '%{http_code}')" "$(multiply "$bad" -o /dev/null -w '%{http_code}')"
  check "POST /multiply $bad body matches /sum" "$(sum "$bad")" "$(multiply "$bad")"
done
