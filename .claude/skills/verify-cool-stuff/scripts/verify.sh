#!/usr/bin/env bash
# verify-cool-stuff: launch / doctor / drive / cleanup for the cool-stuff Worker via `wrangler dev`.
# Run state: $VERIFY_RUN_DIR (removed by cleanup). Evidence: $VERIFY_EVIDENCE_DIR (never removed).
set -euo pipefail

TMP_ROOT="${TMPDIR:-/tmp}"; TMP_ROOT="${TMP_ROOT%/}"
RUN_DIR="${VERIFY_RUN_DIR:-$TMP_ROOT/verify-cool-stuff-run}"
EVIDENCE_DIR="${VERIFY_EVIDENCE_DIR:-$TMP_ROOT/verify-cool-stuff-evidence}"
REPO="$(cd "$(dirname "$0")/../../../.." && pwd)"
export WRANGLER_SEND_METRICS=false CI=1 NO_COLOR=1

die() { echo "verify: $*" >&2; exit 1; }
st() { cat "$RUN_DIR/$1" 2>/dev/null || true; }
alive() { [ -n "$(st pid)" ] && kill -0 "$(st pid)" 2>/dev/null; }
free_port() { node -e 's=require("net").createServer().listen(0,"127.0.0.1",()=>{console.log(s.address().port);s.close()})'; }

launch() {
  alive && die "instance already running (pid $(st pid), $(st url)); run cleanup or set another VERIFY_RUN_DIR"
  rm -rf "$RUN_DIR"; mkdir -p "$RUN_DIR"
  cd "$REPO"
  [ -x node_modules/.bin/wrangler ] || pnpm install >"$RUN_DIR/install.log" 2>&1 || die "pnpm install failed: $RUN_DIR/install.log"
  local port="${VERIFY_PORT:-$(free_port)}" insp; insp="$(free_port)"
  git rev-parse --short HEAD >"$RUN_DIR/revision"
  git diff --quiet HEAD -- src wrangler.jsonc package.json || echo "+dirty" >>"$RUN_DIR/revision"
  # set -m: the background job gets its own process group, so cleanup can kill wrangler + workerd together.
  set -m
  node_modules/.bin/wrangler dev --ip 127.0.0.1 --port "$port" --inspector-port "$insp" \
    --persist-to "$RUN_DIR/state" >"$RUN_DIR/wrangler.log" 2>&1 &
  echo $! >"$RUN_DIR/pid"; set +m
  echo "http://127.0.0.1:$port" >"$RUN_DIR/url"
  for _ in $(seq 1 60); do
    alive || die "wrangler exited during startup, see $RUN_DIR/wrangler.log"
    if grep -q "Ready on http://127.0.0.1:$port" "$RUN_DIR/wrangler.log" && curl -s -o /dev/null "$(st url)/"; then
      echo "READY url=$(st url) pid=$(st pid) revision=$(st revision | tr -d '\n')"; return
    fi
    sleep 1
  done
  die "not ready after 60s, see $RUN_DIR/wrangler.log"
}

doctor() {
  local ok=1 url; url="$(st url)"
  echo "revision serving: $(st revision | tr -d '\n')   worktree HEAD: $(git -C "$REPO" rev-parse --short HEAD)"
  alive && echo "pid $(st pid) alive" || { echo "FAIL: no live instance from $RUN_DIR"; ok=0; }
  if [ -n "$url" ]; then
    local owner; owner="$(lsof -nP -t -iTCP:"${url##*:}" -sTCP:LISTEN 2>/dev/null | head -1)"
    if [ -n "$owner" ] && [ "$(ps -o pgid= -p "$owner" | tr -d ' ')" = "$(st pid)" ]; then echo "port ${url##*:} owned by our process group"
    else echo "FAIL: port ${url##*:} not owned by our process group (owner pid: ${owner:-none})"; ok=0; fi
    curl -s -o /dev/null -w "GET / -> %{http_code}\n" "$url/" || { echo "FAIL: $url not answering"; ok=0; }
  fi
  [ $ok = 1 ] && echo "DOCTOR OK" || { echo "DOCTOR FAIL"; exit 1; }
}

drive() {
  [ $# -ge 3 ] || die "usage: drive <evidence-name> <METHOD> <path> [body]"
  local name="$1" method="$2" path="$3" out="$EVIDENCE_DIR/$1"; shift 3
  alive || die "no live instance; run launch"
  mkdir -p "$out"
  local args=(-s -X "$method" -D "$out/headers.txt" -o "$out/body.txt" -w "%{http_code}" "$(st url)$path")
  [ "$method" = HEAD ] && args=(-s -I -o "$out/headers.txt" -w "%{http_code}" "$(st url)$path") && : >"$out/body.txt"
  [ $# -ge 1 ] && args=(--data-binary "$1" "${args[@]}")
  local before; before="$(wc -l <"$RUN_DIR/wrangler.log")"
  local code; code="$(curl "${args[@]}")"
  sleep 0.3
  tail -n +"$((before + 1))" "$RUN_DIR/wrangler.log" >"$out/server-log.txt"
  printf 'time: %s\nrevision: %s\nrequest: %s %s%s\ncommand: curl %s\n' "$(date -u +%FT%TZ)" "$(st revision | tr -d '\n')" \
    "$method" "$path" "${1:+ body=$1}" "${args[*]}" >"$out/request.txt"
  { echo "status: $code"
    echo "content-type: $(grep -i '^content-type:' "$out/headers.txt" | cut -d' ' -f2- | tr -d '\r')"
    echo "body-bytes: $(wc -c <"$out/body.txt" | tr -d ' ')"
    echo "body: $(cat "$out/body.txt")"; } | tee "$out/result.txt"
}

cleanup() {
  if alive; then
    kill -TERM -- "-$(st pid)" 2>/dev/null || true
    for _ in 1 2 3 4 5; do alive || break; sleep 1; done
    kill -KILL -- "-$(st pid)" 2>/dev/null || true
  fi
  if [ -d "$RUN_DIR" ]; then
    mkdir -p "$EVIDENCE_DIR/_logs"; cp "$RUN_DIR"/*.log "$EVIDENCE_DIR/_logs/" 2>/dev/null || true
    rm -rf "$RUN_DIR"
  fi
  echo "cleaned; evidence kept in $EVIDENCE_DIR"
}

case "${1:-}" in
  launch|doctor|cleanup) "$1" ;;
  drive) shift; drive "$@" ;;
  paths) echo "run: $RUN_DIR"; echo "evidence: $EVIDENCE_DIR"; echo "repo: $REPO" ;;
  *) die "usage: verify.sh launch|doctor|drive <name> <METHOD> <path> [body]|cleanup|paths" ;;
esac
