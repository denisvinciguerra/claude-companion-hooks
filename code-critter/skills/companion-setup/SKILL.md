---
name: companion-setup
description: Verify and troubleshoot Code Critter live-session hooks. Use when the Stream Deck Fleet / Session / Session Status tiles stay empty or the companion never wakes up.
disable-model-invocation: true
---

# Code Critter: live session check & manual setup

The Code Critter **Fleet**, **Session Status**, **Session** tiles and the **companion's
mood** are driven by `~/.claude/deck-state/<session_id>.json`, written by this plugin's hook.
Tokens, cost, project cost and activity work WITHOUT this hook; this only adds the live view.

When the user invokes this skill, do the following and report clearly:

1. **Is the hook active?** This plugin ships `hooks/hooks.json`, so enabling the plugin should
   make the hook fire on `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
   `PermissionRequest`, `Stop`, `SessionEnd`. Confirm the plugin is enabled.

2. **Is state being written?** Check `~/.claude/deck-state/` exists and holds a JSON file for
   the current session whose `ts` updates as the user works. If missing or stale, the hook is
   not running.

3. **Is Node reachable?** The hook runs `node`. Claude Code requires Node, so it is normally on
   PATH; if a bare `node` is not found, that is the cause.

4. **Manual fallback.** If the user prefers configuring it by hand (no plugin), show them how to
   MERGE the hooks into `~/.claude/settings.json` (do NOT clobber their existing hooks), mirroring
   this plugin's `hooks/hooks.json`: a `bash "<abs-path>/bin/claude-state-hook.sh" <status> <counter> <turn>`
   command under each of the seven events, where `<status>`/`<counter>`/`<turn>` are the per-event
   arguments shown in `hooks/hooks.json` (e.g. `working runs new` for UserPromptSubmit).

Never modify the user's `settings.json` without explicit confirmation. This tool is read-only
diagnostics by default.
