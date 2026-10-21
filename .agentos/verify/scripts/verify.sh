#!/usr/bin/env bash
# verify-cool-stuff helper: launch / doctor / drive / cleanup for the cool-stuff Worker
# (Hono on Cloudflare Workers).
#
# Two modes, recorded at launch in $RUN_DIR/mode:
#   http   - `wrangler dev` (workerd) on 127.0.0.1:<free port>, driven with curl. The real runtime.
#   inproc - for sandboxes that refuse every TCP listen: `wrangler deploy --dry-run` builds the
#            exact upload bundle, and scripts/inproc-fetch.mjs calls its fetch handler on Node.
# VERIFY_MODE=auto (default) picks http when a loopback listen succeeds, else inproc.
#
# Everything launch creates lives under $VERIFY_RUN_DIR (default $TMPDIR/verify-cool-stuff).
# Evidence lives under $VERIFY_EVIDENCE_DIR (default $TMPDIR/verify-cool-stuff-evidence) and
# cleanup never removes it.
set -euo pipefail

TMP_ROOT="${TMPDIR:-/tmp}"; TMP_ROOT="${TMP_ROOT%/}"
RUN_DIR="${VERIFY_RUN_DIR:-$TMP_ROOT/verify-cool-stuff}"
EVIDENCE_DIR="${VERIFY_EVIDENCE_DIR:-$TMP_ROOT/verify-cool-stuff-evidence}"
TOOLS_DIR="${VERIFY_TOOLS_DIR:-$TMP_ROOT/verify-tools}"   # reused across runs: pnpm bootstrap + store
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$SCRIPTS" rev-parse --show-toplevel 2>/dev/null)"

die() { echo "verify: $*" >&2; exit 1; }
log() { echo "verify: $*" >&2; }

sandbox_env() {
  # Keep wrangler/npm/pnpm away from the real $HOME (read-only in the sandbox).
  export HOME="$RUN_DIR/home" XDG_CONFIG_HOME="$RUN_DIR/home/.config" XDG_DATA_HOME="$RUN_DIR/home/.local/share"
  export XDG_CACHE_HOME="$TOOLS_DIR/cache" NPM_CONFIG_CACHE="$TOOLS_DIR/npm-cache"
  export WRANGLER_LOG_PATH="$RUN_DIR/logs" WRANGLER_SEND_METRICS=false CI=1 NO_COLOR=1 FORCE_COLOR=0
  export PATH="$TOOLS_DIR/bin:$PATH"
}

ensure_pnpm() {
  [ -x "$TOOLS_DIR/bin/pnpm" ] && return
  mkdir -p "$TOOLS_DIR/bin"
  if command -v pnpm >/dev/null 2>&1 && pnpm --version >/dev/null 2>&1; then
    ln -sf "$(command -v pnpm)" "$TOOLS_DIR/bin/pnpm"; return
  fi
  log "bootstrapping pnpm@10 into $TOOLS_DIR"
  npm install -g --prefix "$TOOLS_DIR" pnpm@10 >"$TOOLS_DIR/pnpm-bootstrap.log" 2>&1 \
    || die "pnpm bootstrap failed, see $TOOLS_DIR/pnpm-bootstrap.log"
}

free_port() { node -e 'const s=require("net").createServer();s.on("error",()=>process.exit(1));s.listen(0,"127.0.0.1",()=>{console.log(s.address().port);s.close()})' 2>/dev/null; }

state() { cat "$RUN_DIR/$1" 2>/dev/null || true; }

inproc() { node "$SCRIPTS/inproc-fetch.mjs" "$RUN_DIR/bundle/index.js" "$@"; }

cmd_launch() {
  local rev="${1:-HEAD}" mode="${VERIFY_MODE:-auto}"
  if [ "$(state mode)" = http ] && kill -0 "$(state pid)" 2>/dev/null; then
    die "an instance is already running from $RUN_DIR (pid $(state pid)); run cleanup or set another VERIFY_RUN_DIR"
  fi
  rm -rf "$RUN_DIR"; mkdir -p "$RUN_DIR"/{src,home,logs,state} "$TOOLS_DIR"
  if [ "$mode" = auto ]; then
    if free_port >/dev/null; then mode=http; else mode=inproc; log "loopback listen refused (sandbox): using inproc mode"; fi
  fi
  echo "$mode" >"$RUN_DIR/mode"
  sandbox_env
  if [ "$rev" = "--worktree" ]; then
    # Uncommitted working tree (tracked + untracked, not ignored): check a change before committing it.
    (cd "$REPO" && git ls-files -z --cached --others --exclude-standard \
      | while IFS= read -r -d '' f; do [ -e "$f" ] && printf '%s\0' "$f"; done \
      | xargs -0 tar -cf -) | tar -xf - -C "$RUN_DIR/src"
    echo "worktree@$(git -C "$REPO" rev-parse --short HEAD)+dirty" >"$RUN_DIR/revision"
  else
    git -C "$REPO" archive "$rev" | tar -xf - -C "$RUN_DIR/src"
    git -C "$REPO" rev-parse --short "$rev" >"$RUN_DIR/revision"
  fi
  ensure_pnpm
  log "installing deps for $(state revision) (log: $RUN_DIR/logs/install.log)"
  (cd "$RUN_DIR/src" && pnpm install --store-dir "$TOOLS_DIR/pnpm-store" >"$RUN_DIR/logs/install.log" 2>&1) \
    || die "pnpm install failed, see $RUN_DIR/logs/install.log"

  if [ "$mode" = inproc ]; then
    log "building the deploy bundle (wrangler deploy --dry-run, no upload)"
    (cd "$RUN_DIR/src" && ./node_modules/.bin/wrangler deploy --dry-run --outdir "$RUN_DIR/bundle" \
      >"$RUN_DIR/logs/build.log" 2>&1) || { tail -30 "$RUN_DIR/logs/build.log" >&2; die "bundle build failed"; }
    grep -q -- "--dry-run: exiting now" "$RUN_DIR/logs/build.log" || die "dry-run did not finish, see $RUN_DIR/logs/build.log"
    # Without this, Node walks up to $HOME looking for a package scope (EPERM in the sandbox).
    echo '{"type":"module"}' >"$RUN_DIR/bundle/package.json"
    local probe; probe="$(inproc GET /)" || die "bundle fetch handler failed"
    echo "READY mode=inproc bundle=$RUN_DIR/bundle/index.js revision=$(state revision) probe=$probe"
    return 0
  fi

  local port iport
  iport="$(free_port)" || die "http mode: loopback TCP listen refused on this host (sandbox?); use VERIFY_MODE=inproc"
  port="${VERIFY_PORT:-$(free_port)}"
  echo "$port" >"$RUN_DIR/port"
  log "starting wrangler dev on 127.0.0.1:$port"
  # perl setpgrp: own process group, so cleanup kills wrangler + workerd and nothing else.
  (cd "$RUN_DIR/src" && nohup perl -e 'setpgrp(0,0); exec @ARGV' -- \
      ./node_modules/.bin/wrangler dev --ip 127.0.0.1 --port "$port" --inspector-port "$iport" \
      --persist-to "$RUN_DIR/state" --show-interactive-dev-session=false \
      >"$RUN_DIR/logs/wrangler.log" 2>&1 </dev/null & echo $! >"$RUN_DIR/pid")
  local i
  for i in $(seq 1 120); do
    kill -0 "$(state pid)" 2>/dev/null || { tail -40 "$RUN_DIR/logs/wrangler.log" >&2; die "wrangler exited during startup"; }
    if grep -q "Ready on" "$RUN_DIR/logs/wrangler.log" && curl -sS -o /dev/null "http://127.0.0.1:$port/" 2>/dev/null; then
      echo "READY mode=http url=http://127.0.0.1:$port revision=$(state revision) pid=$(state pid) run_dir=$RUN_DIR"
      return 0
    fi
    sleep 0.5
  done
  tail -40 "$RUN_DIR/logs/wrangler.log" >&2; die "not ready after 60s"
}

cmd_doctor() {
  local bad=0 mode; mode="$(state mode)"
  [ -n "$mode" ] || die "no instance recorded in $RUN_DIR (run launch)"
  echo "mode      info $mode"
  echo "revision  info serving $(state revision); worktree HEAD is $(git -C "$REPO" rev-parse --short HEAD)"
  if [ "$mode" = inproc ]; then
    if [ -s "$RUN_DIR/bundle/index.js" ]; then echo "bundle    ok   $RUN_DIR/bundle/index.js ($(wc -c <"$RUN_DIR/bundle/index.js" | tr -d ' ') bytes)"; else echo "bundle    FAIL missing"; bad=1; fi
    if [ "$RUN_DIR/bundle/index.js" -nt "$RUN_DIR/src/package.json" ]; then echo "fresh     ok   bundle built after source export"; else echo "fresh     FAIL bundle older than source"; bad=1; fi
    local r; if r="$(inproc GET / 2>&1)"; then echo "handler   ok   GET / -> $r"; else echo "handler   FAIL $r"; bad=1; fi
  else
    local pid port owners mine=0 o
    pid="$(state pid)"; port="$(state port)"
    if kill -0 "$pid" 2>/dev/null; then echo "process   ok   pid=$pid (own process group)"; else echo "process   FAIL pid=$pid not running"; bad=1; fi
    owners="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | tr '\n' ' ' || true)"
    for o in $owners; do [ "$(ps -o pgid= -p "$o" | tr -d ' ')" = "$pid" ] && mine=1; done
    if [ "$mine" = 1 ]; then echo "port      ok   127.0.0.1:$port listened by our process group"; else echo "port      FAIL 127.0.0.1:$port listeners=[$owners] not in pgid $pid"; bad=1; fi
    local code; code="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/" 2>/dev/null || true)"
    if [ -n "$code" ] && [ "$code" != 000 ]; then echo "http      ok   GET / -> $code"; else echo "http      FAIL no HTTP answer"; bad=1; fi
    if grep -q "Ready on http://127.0.0.1:$port" "$RUN_DIR/logs/wrangler.log"; then echo "wrangler  ok   'Ready on' logged"; else echo "wrangler  FAIL no 'Ready on' line"; bad=1; fi
  fi
  if [ "$bad" = 0 ]; then echo "DOCTOR OK"; else echo "DOCTOR FAIL"; return 1; fi
}

# drive <name> <METHOD> <path> [body]
# Writes $EVIDENCE_DIR/<name>/{request.txt,response.json,result.txt[,server-log-tail.txt]}; prints result.txt.
cmd_drive() {
  [ $# -ge 3 ] || die "usage: drive <name> <METHOD> <path> [body]"
  local name="$1" method="$2" path="$3" body="${4-}" mode; mode="$(state mode)"
  [ -n "$mode" ] || die "no instance (run launch)"
  local out="$EVIDENCE_DIR/$name"; mkdir -p "$out"
  { echo "revision: $(state revision)"; echo "mode: $mode"; echo "time: $(date -u +%FT%TZ)"; echo "request: $method $path"
    [ $# -ge 4 ] && echo "body: $body"; } >"$out/request.txt"
  if [ "$mode" = inproc ]; then
    echo "command: node $SCRIPTS/inproc-fetch.mjs $RUN_DIR/bundle/index.js $method '$path'${4+ '$body'}" >>"$out/request.txt"
    inproc "$method" "$path" ${4+"$body"} >"$out/response.json"
  else
    local url="http://127.0.0.1:$(state port)$path" args=(-sS -D "$out/response.headers" -o "$out/response.body" -w '%{http_code}')
    if [ "$method" = HEAD ]; then args+=(-I); else args+=(-X "$method"); fi
    [ $# -ge 4 ] && args+=(--data-binary "$body")
    echo "command: curl ${args[*]} $url" >>"$out/request.txt"
    local code; code="$(curl "${args[@]}" "$url")"
    STATUS="$code" node -e '
      const fs=require("fs"),[h,b]=process.argv.slice(1);
      const headers={};for(const l of fs.readFileSync(h,"utf8").split(/\r?\n/).slice(1)){const i=l.indexOf(":");if(i>0)headers[l.slice(0,i).toLowerCase()]=l.slice(i+1).trim()}
      console.log(JSON.stringify({status:+process.env.STATUS,headers,body:fs.readFileSync(b,"utf8")}))' \
      "$out/response.headers" "$out/response.body" >"$out/response.json"
    sleep 0.5; tail -5 "$RUN_DIR/logs/wrangler.log" >"$out/server-log-tail.txt" || true   # server-side view
  fi
  node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
    console.log("status: "+r.status+"\ncontent-type: "+(r.headers["content-type"]||"")+"\nbody-bytes: "+Buffer.byteLength(r.body)+"\nbody: "+r.body)' \
    "$out/response.json" >"$out/result.txt"
  cat "$out/result.txt"
}

cmd_cleanup() {
  local pid; pid="$(state pid)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM -- "-$pid" 2>/dev/null || true
    for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.25; done
    kill -KILL -- "-$pid" 2>/dev/null || true
    log "stopped process group $pid"
  fi
  if [ -d "$RUN_DIR" ]; then
    if [ -d "$EVIDENCE_DIR" ]; then mkdir -p "$EVIDENCE_DIR/_logs"; cp "$RUN_DIR"/logs/*.log "$EVIDENCE_DIR/_logs/" 2>/dev/null || true; fi
    rm -rf "$RUN_DIR"; log "removed $RUN_DIR"
  fi
  log "evidence kept at $EVIDENCE_DIR"
}

case "${1:-}" in
  launch)  shift; cmd_launch "$@";;
  doctor)  shift; cmd_doctor "$@";;
  drive)   shift; cmd_drive "$@";;
  cleanup) shift; cmd_cleanup "$@";;
  paths)   echo "run_dir=$RUN_DIR"; echo "evidence_dir=$EVIDENCE_DIR"; echo "tools_dir=$TOOLS_DIR";;
  *) echo "usage: $0 launch [<rev>|--worktree] | doctor | drive <name> <METHOD> <path> [body] | cleanup | paths" >&2; exit 2;;
esac
