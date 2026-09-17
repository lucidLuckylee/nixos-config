# Plumbing for the Claude→Codex handoff skill.
PLANS_REPO='@plansRepo@'
PLANS_DIR='@plansDir@'
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND='ssh -o BatchMode=yes'

usage() {
  cat <<'USAGE'
handoff sync                 clone or fast-forward the plans repo
handoff push <file> [msg]    commit one plan file and push
handoff status               one line of Codex quota; exit 2 when Codex cannot run
handoff run <plan> [effort]  implement <plan> with Codex in the current repo
handoff dir                  print the plans directory
USAGE
  exit 64
}

# Quiet on success; one stdout line on failure, since a SessionStart hook
# feeds stdout to Claude and that is the right place for "plans may be stale".
cmd_sync() {
  if [ ! -d "$PLANS_DIR/.git" ]; then
    timeout 60 git clone --quiet "$PLANS_REPO" "$PLANS_DIR" 2>/dev/null \
      || echo "handoff: could not clone $PLANS_REPO into $PLANS_DIR"
    return 0
  fi
  timeout 30 git -C "$PLANS_DIR" pull --ff-only --quiet 2>/dev/null \
    || echo "handoff: plans repo not updated, it may be behind"
}

cmd_push() {
  local file=$1 msg
  msg=${2:-"Add $(basename "$file")"}
  git -C "$PLANS_DIR" add -- "$file"
  git -C "$PLANS_DIR" diff --cached --quiet \
    || git -C "$PLANS_DIR" commit --quiet -m "$msg"
  { git -C "$PLANS_DIR" pull --rebase --quiet && git -C "$PLANS_DIR" push --quiet; } \
    || echo "handoff: committed locally, push failed" >&2
}

# Codex has no CLI for quota, but its app-server answers over stdio.
cmd_status() {
  timeout 30 python3 - <<'PY'
import datetime, json, subprocess, sys

p = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

def send(msg):
    p.stdin.write(json.dumps(msg) + "\n")
    p.stdin.flush()

send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
      "params": {"clientInfo": {"name": "handoff", "version": "1"}}})
send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
send({"jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read",
      "params": {"excludeResetCreditDetails": True}})
reply = None
for line in p.stdout:
    try:
        msg = json.loads(line)
    except ValueError:
        continue
    if msg.get("id") == 2:
        reply = msg
        break
p.kill()
if not reply or "result" not in reply:
    print("codex: quota unknown")
    sys.exit(0)
r = reply["result"]
limits = r.get("rateLimits") or {}

def window(w):
    if not w:
        return "n/a"
    mins = w.get("windowDurationMins") or 0
    label = "week" if mins >= 10080 else f"{mins // 60}h"
    reset = w.get("resetsAt")
    when = datetime.datetime.fromtimestamp(reset).strftime("%a %H:%M") if reset else "?"
    return f"{label} {w['usedPercent']}% used (resets {when})"

blocked = r.get("ordinaryUsageAllowed") is False or bool(limits.get("rateLimitReachedType"))
print(f"codex ({limits.get('planType')}): {window(limits.get('primary'))}, "
      f"{window(limits.get('secondary'))}: {'BLOCKED' if blocked else 'ok'}")
sys.exit(2 if blocked else 0)
PY
}

cmd_run() {
  local plan=$1 effort=${2:-high} repo slug cache log result rc=0
  [ -f "$plan" ] || { echo "handoff: no plan at $plan" >&2; exit 66; }
  repo=$(git rev-parse --show-toplevel)
  slug=$(basename "${plan%.md}")
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/handoff"
  mkdir -p "$cache"
  log="$cache/$slug.jsonl"
  result="$cache/$slug.result.md"
  : > "$result"
  codex exec --cd "$repo" --profile implement \
    -c "model_reasoning_effort=\"$effort\"" \
    --approve-for-me --json --output-last-message "$result" - > "$log" <<PROMPT || rc=$?
Use \$implement-plan to implement the plan at $plan. Work in this repository. Do not stop at a partial implementation or to ask about decisions the plan already makes. Finish with the report format from the skill.
PROMPT
  if grep -q 'usage limit' "$log"; then
    echo "handoff: Codex is out of usage; implement the plan yourself"
    exit 2
  fi
  echo "codex exit $rc, events in $log"
  cat "$result"
  exit "$rc"
}

case ${1:-} in
  sync) cmd_sync ;;
  push) shift; [ $# -ge 1 ] || usage; cmd_push "$@" ;;
  status) cmd_status ;;
  run) shift; [ $# -ge 1 ] || usage; cmd_run "$@" ;;
  dir) echo "$PLANS_DIR" ;;
  *) usage ;;
esac
