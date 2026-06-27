# Code Critter (Claude Code plugin)

Records live Claude Code **session state** to `~/.claude/deck-state/<session_id>.json` so
**Code Critter for Claude Code** (the [Stream Deck plugin](../README.md) and the macOS/Windows/Linux
desktop app) can show **Fleet**, **Session Status**, **Session** and the **companion's mood**.

- **100% local.** Writes only under `~/.claude/deck-state/`. No network, no telemetry.
- **Zero dependency.** The hook is a single Bash script (`bin/claude-state-hook.sh`), run by the
  shell Claude Code already uses for hooks. No Node, no Python, no jq. Works on macOS, Linux and
  Windows (the Git Bash that Claude Code ships).
- **Optional.** Tokens, cost, project cost and activity work without it; this adds the live view.

## Install

```bash
/plugin marketplace add https://github.com/denisvinciguerra/code-critter-hooks
/plugin install code-critter@code-critter
```

> Canonical public repo: https://github.com/denisvinciguerra/code-critter-hooks
> (this `claude-code-plugin/` folder is the dev source mirrored there).

Enabling the plugin activates the hooks automatically (via `hooks/hooks.json`); there is nothing
to run. To check it, use the `companion-setup` skill.

## What it records

On each turn/tool event the hook writes `{ status, pid, ts, turn_ts, cwd, transcript }`:
`status` is `working` / `waiting` / `done`, mapped from the hook event. `SessionEnd` deletes the
file. Two counters (`permissions.log`, `runs.log`) get one epoch per line.

## Known follow-up

`sessionPid()` walks the process tree via `ps` on macOS/Linux; on Windows it falls back to the
parent pid. Precise Windows liveness should lean on `ts` freshness in the core rather than the
pid (tracked separately).
