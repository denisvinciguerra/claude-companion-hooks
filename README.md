# Code Critter for Claude Code — live-session hooks

A small **Claude Code plugin** that records your live session state to
`~/.claude/deck-state/`, so **Code Critter for Claude Code** can show **Fleet**, **Session
Status**, **Session** and the companion's mood across all of its surfaces:

- the **Code Critter Stream Deck plugin** (Elgato Stream Deck, macOS + Windows), and
- the standalone **Code Critter** desktop app (menu-bar on **macOS**, system-tray on **Windows**
  and **Linux**).

This repo is just the hooks; the apps are what render the tiles and the pixel companion (**Sprout**).

- **100% local.** Writes only under `~/.claude/deck-state/`. No network, no telemetry, no account.
- **Zero dependency.** A single Bash script, run by the shell Claude Code already uses for hooks.
  No Node, no Python, no jq. Works on macOS, Linux and Windows (the Git Bash Claude Code ships).
- **Optional.** Tokens, cost, project cost and activity work without it; this adds the live view.

## Install

```
/plugin marketplace add https://github.com/denisvinciguerra/code-critter-hooks
/plugin install code-critter@code-critter
```

Enabling the plugin activates the hooks automatically (via `code-critter/hooks/hooks.json`);
there is nothing to run. To check it, use the `companion-setup` skill.

## What it records

On each turn/tool event the hook writes `~/.claude/deck-state/<session_id>.json` with
`{ status, pid, ts, turn_ts, cwd, transcript }` (`status` = `working` / `waiting` / `done`), and
appends one epoch per line to `permissions.log` / `runs.log`. `SessionEnd` removes the file.

## License

[Apache-2.0](LICENSE). Independent project, not affiliated with Anthropic or Elgato. "Claude" and
"Claude Code" are trademarks of Anthropic; "Stream Deck" and "Elgato" are trademarks of Corsair /
Elgato. Used here only descriptively.
