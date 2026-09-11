# git-guardrails

Blocks Claude Code from running a specific list of destructive git commands.

**This is not a complete safeguard against Claude destroying your work.** It's a narrow regex tripwire on five known-risky git invocations, nothing more. See [Limitations](#limitations) below before relying on it.

## What it blocks

A `PreToolUse` hook on the `Bash` tool denies commands matching:

- `git push ... --force` (or `--force-with-lease`, since it's substring-matched by `--force`)
- `git reset --hard`
- `git branch -D`
- `git clean -f`
- `git checkout .`

These commands can silently discard uncommitted or unpushed work with no undo. The hook denies the tool call outright — Claude sees a permission-denied result and the command never runs. It only applies to Claude; you can still run any of these yourself from your terminal.

## Why

Claude Code agents occasionally reach for these commands as a shortcut to "clean up" an unexpected state (merge conflicts, stray files, a dirty working tree) instead of investigating the root cause. Without a hard guardrail, that shortcut can destroy uncommitted work with no recovery path.

## Installation

```bash
claude plugin marketplace add https://github.com/mycargus/mikey-claude-plugins
claude plugin install git-guardrails@mikey-claude-plugins
```

## Local dev workflow

1. **Uninstall** the marketplace version to avoid conflicts:
   ```bash
   claude plugin uninstall git-guardrails@mikey-claude-plugins
   ```
2. **Load the local version** inline when starting Claude Code:
   ```bash
   claude --plugin-dir /path/to/mikey-claude-plugins/git-guardrails
   ```
3. Test the hook script directly:
   ```bash
   echo '{"tool_input":{"command":"git reset --hard"}}' | scripts/reject-destructive-git.sh
   ```
4. **Reinstall** from the marketplace when done:
   ```bash
   claude plugin install git-guardrails@mikey-claude-plugins
   ```

## Limitations

This plugin covers one narrow, known-bad set of commands. It is not a general defense against Claude destroying uncommitted or unpushed work. In particular, it does **not** catch:

- **Other ways to lose work through git itself**: `git checkout <file>`, `git restore`, `git stash drop`, `git reflog expire`, rewriting history and force-pushing under a different flag spelling than plain `--force`, or any git command not on the fixed blocklist.
- **Non-git destructive actions**: `rm -rf`, a shell redirect that truncates a file (`echo > file`), a script that deletes things, dropping a database table, killing a process — anything outside `git`.
- **Non-Bash tool calls**: this hook only matches on the `Bash` tool. Claude Code's `Write` and `Edit` tools can silently overwrite a file's contents outright; this plugin does not hook those.
- **Obfuscated or indirect invocations**: commands built via string concatenation, environment variables, aliases, wrapper scripts, or piped through `xargs`/`eval` may not match the regex even though they resolve to a blocked command at runtime.
- **Regex/parsing edge cases**: the hook extracts the command from JSON with bash string manipulation, not a real JSON parser (see [ADR-008](../docs/adr/adr-008-no-jq-in-hooks.md) for why). A command string containing an escaped quote can throw off extraction and cause a false negative — the guardrail fails silently open, not closed.
- **Non-Claude-Code actions**: this only governs what Claude Code itself runs. It does nothing for a human running the same commands, or for other tools/CI acting on the repo.

Treat this as one layer of defense-in-depth (alongside commits, backups, and `git reflog`), not a replacement for them.

Hooks are also loaded at session start — changes to this plugin require restarting Claude Code to take effect.
