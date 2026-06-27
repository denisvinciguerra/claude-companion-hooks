#!/usr/bin/env bash
# claude-state-hook.sh — Claude Code hook with ZERO runtime dependency: pure bash, the very
# shell Claude Code already uses to run command hooks (and Git Bash it ships on Windows). No
# node, no python, no jq. Records local session state to ~/.claude/deck-state/<session_id>.json
# for the Code Critter Stream Deck plugin.
#
# Args (passed per event from hooks.json, so the event name is never parsed):
#   $1 = status  : working | waiting | done | del
#   $2 = counter : runs | perms | -     (append one epoch to the matching log)
#   $3 = turn    : new | -              ("new" resets the turn-start timestamp)
#
# Only ONE field is read from the stdin JSON: session_id (a UUID, trivial to grep). cwd comes
# from $PWD (Claude sets the hook's working dir to the session cwd). NEVER writes to stdout
# (it would be injected as context on UserPromptSubmit); always exits 0.

status="${1:-}"; counter="${2:--}"; turn="${3:--}"

# Windows-only: resolve the real claude.exe pid. Under the native Windows Claude Code, the hook
# runs in Git Bash whose parent (claude.exe) is NOT in the MSYS process table — so $PPID is 1 and
# `ps -o` is unsupported. We map this bash's WINPID to the nearest native ancestor whose image is
# the Claude executable (CLAUDE_CODE_EXECPATH, e.g. claude.exe) via PowerShell — a long-lived,
# real Windows pid Node's process.kill can verify. Targeting the claude image (rather than the
# first non-shell ancestor) skips any transient wrapper process between the hook and claude.
# The result is cached in the session's state file so PowerShell runs ~once per session, not per event.
win_session_pid() {
  local cached wp tgt resolved
  if [ -f "$file" ]; then
    cached="$(grep -o '"pid"[[:space:]]*:[[:space:]]*[0-9][0-9]*' "$file" 2>/dev/null | grep -o '[0-9][0-9]*$')"
    case "$cached" in '' | 0 | 1) ;; *) printf '%s' "$cached"; return 0 ;; esac
  fi
  wp="$(cat "/proc/$$/winpid" 2>/dev/null)"
  [ -n "$wp" ] || wp="$(ps -p "$$" 2>/dev/null | awk 'NR==2{print $4}')"
  case "$wp" in '' | *[!0-9]*) return 1 ;; esac
  tgt="claude.exe"
  [ -n "${CLAUDE_CODE_EXECPATH:-}" ] && tgt="$(basename "$CLAUDE_CODE_EXECPATH")"
  resolved="$(WP="$wp" TGT="$tgt" powershell.exe -NoProfile -NonInteractive -Command '
    $tgt = $env:TGT
    $p = Get-CimInstance Win32_Process -Filter ("ProcessId=" + [int]$env:WP) -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 16 -and $p; $i++) {
      if ($p.Name -ieq $tgt) { $p.ProcessId; break }
      $p = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $p.ParentProcessId) -ErrorAction SilentlyContinue
    }
  ' 2>/dev/null | tr -d '[:space:]')"
  case "$resolved" in '' | 0 | 1 | *[!0-9]*) return 1 ;; esac
  printf '%s' "$resolved"
}

# Walk up to the first non-shell ancestor = the real claude process, so the plugin's liveness
# GC sees a pid that stays alive while the session is open. `ps -o` works on macOS/Linux; on
# Windows Git Bash it does not (and $PPID is 1), so there we resolve the native pid instead.
session_pid() {
  # WSL bash (under native Windows Claude Code): our process ids live in the Linux namespace and
  # are meaningless to the Windows app that reads this state — it would judge a non-existent
  # Windows pid as dead and GC the session after 60s. Emit an "unknown" pid (0) so the core keeps
  # it on time-based staleness instead. wslpath exists only under WSL, so Git Bash / macOS / Linux
  # fall through to the real resolution below.
  if command -v wslpath >/dev/null 2>&1; then printf '0'; return; fi
  local pid="$PPID" n=0 line ppid comm base
  while [ "$n" -lt 10 ]; do
    n=$((n + 1))
    line="$(ps -o ppid=,comm= -p "$pid" 2>/dev/null)" || break
    [ -n "$line" ] || break
    ppid="$(printf '%s' "$line" | awk '{print $1}')"
    comm="$(printf '%s' "$line" | sed 's/^[[:space:]]*[0-9][0-9]*[[:space:]]*//')"
    base="$(basename "$comm" 2>/dev/null)"
    case "$base" in
      sh | bash | zsh | dash | fish | sh.exe | bash.exe) ;;
      *) printf '%s' "$pid"; return ;;
    esac
    case "$ppid" in '' | *[!0-9]*) break ;; esac
    [ "$ppid" -gt 1 ] || break
    pid="$ppid"
  done
  # Windows Git Bash falls through here ($PPID is 1); resolve claude.exe's real pid. Darwin/Linux
  # never reach this — the walk above returns first — and the guard double-ensures it.
  case "$(uname -s 2>/dev/null)" in
    MINGW* | MSYS* | CYGWIN*) win_session_pid && return ;;
  esac
  printf '%s' "$PPID"
}

input="$(cat 2>/dev/null)"
sid="$(printf '%s' "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')"
[ -n "$sid" ] || sid="unknown"

# Locate the enclosing ~/.claude from THIS script's own path rather than $HOME: under WSL bash
# $HOME is the Linux home (/home/<u>), not the Windows ~/.claude the app actually reads. The app
# self-installs the script directly in ~/.claude; the plugin runs it from ~/.claude/plugins/cache/
# …/bin. Both resolve here; anything else falls back to $HOME/.claude (Git Bash, where $HOME is the
# Windows profile).
self_dir="$(cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P 2>/dev/null)"
case "$self_dir" in
  */.claude)   base="$self_dir" ;;
  */.claude/*) base="${self_dir%%/.claude/*}/.claude" ;;
  *)           base="$HOME/.claude" ;;
esac
dir="$base/deck-state"
mkdir -p "$dir" 2>/dev/null
now="$(date +%s)"

case "$counter" in
  runs)  printf '%s\n' "$now" >> "$dir/runs.log" 2>/dev/null ;;
  perms) printf '%s\n' "$now" >> "$dir/permissions.log" 2>/dev/null ;;
esac

file="$dir/$sid.json"
if [ "$status" = "del" ]; then
  rm -f "$file" 2>/dev/null
  exit 0
fi

# turn_ts: start of the current turn; reset on a new prompt, preserved across the rest.
turn_ts="$now"
if [ "$turn" != "new" ] && [ -f "$file" ]; then
  prev="$(grep -o '"turn_ts"[[:space:]]*:[[:space:]]*[0-9][0-9]*' "$file" 2>/dev/null | grep -o '[0-9][0-9]*$')"
  [ -n "$prev" ] && turn_ts="$prev"
fi

# Under WSL bash $PWD is a /mnt/c/… path; convert it back to the Windows form the app and the
# transcript paths use so the session maps to the right project. wslpath exists only under WSL, so
# Git Bash / macOS / Linux keep $PWD unchanged.
pwd_native="$PWD"
if command -v wslpath >/dev/null 2>&1; then
  pwd_native="$(wslpath -w -- "$PWD" 2>/dev/null || printf '%s' "$PWD")"
fi
# Escape backslashes and double quotes in cwd for safe JSON embedding.
cwd="$(printf '%s' "$pwd_native" | sed 's/\\/\\\\/g; s/"/\\"/g')"

tmp="$file.$$.tmp"
printf '{"status":"%s","pid":%s,"ts":%s,"turn_ts":%s,"cwd":"%s","transcript":""}' \
  "$status" "$(session_pid)" "$now" "$turn_ts" "$cwd" > "$tmp" 2>/dev/null
mv "$tmp" "$file" 2>/dev/null
exit 0
