# git-guardrails

Blocks Claude Code from running a specific list of destructive git commands.

**This is not a complete safeguard against Claude destroying your work.** It's a narrow regex tripwire on five known-risky git invocations, nothing more. See [Limitations](#limitations) below before relying on it.

## What it blocks

A `PreToolUse` hook on the `Bash` tool denies commands matching:

- `git push ... --force` (or `--force-with-lease`)
- `git reset --hard`
- `git branch -D` (or `--delete` combined with `--force`/`-f`)
- `git clean -f` (or `--force`, or a clustered short-flag form like `-xdf`/`-df`)
- `git checkout .` (or `git checkout -- .`)

These match regardless of global git options before the subcommand (`git -C . reset --hard`, `git --no-pager reset --hard`) and regardless of whether the flag appears immediately after the subcommand or elsewhere in the command.

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
- **Obfuscated or indirect invocations**: commands built via string concatenation, environment variables, `$IFS` tricks, base64-encoded payloads, aliases, wrapper scripts, or piped through `xargs`/`eval` may not match the regex even though they resolve to a blocked command at runtime.
- **Regex/parsing edge cases**: the hook extracts the command from the JSON payload with a real JSON parser (`python3`'s `json` module — see [ADR-010](../docs/adr/adr-010-python3-for-json-extraction.md)), but everything *downstream* of extraction is still regex/string splitting, not a real shell parser. It checks top-level chain segments (`;`, `&&`, `||`, `|`), `$(...)`/backtick command substitution, and `bash -c "..."`/`sh -c '...'` nesting, but arbitrarily nested or mixed quoting can still defeat that splitting.
- **Depends on `python3` being resolvable**: extraction shells out to `python3` (hardcoded `/usr/bin/python3` first, falling back to `python3` on `PATH` — see [ADR-010](../docs/adr/adr-010-python3-for-json-extraction.md)). A candidate is only trusted after being verified to actually behave like python3 (not just present and executable), and is invoked in isolated mode with its output checked against a sentinel marker, so a hijacked or substituted interpreter can't silently produce the same output as "no command field." If no working `python3` can be found, or if it runs but the JSON can't be parsed, the hook **denies the command** rather than silently letting it through — so a missing `python3` blocks all Bash commands until it's installed, instead of quietly disabling the guardrail.
- **Bounded time budget**: the hook has a hard complexity guard — a command over a fixed length, or with more than a fixed number of chain (`;`/`&&`/`||`/`|`) or substitution (`$(...)`/backtick) operators, is **denied outright** as "too large or complex to verify" rather than being checked in full. This exists because each chain segment and substitution used to require its own subprocess (`awk`/`sed`) fork; a command built from hundreds of them could exhaust the hook's 5-second timeout before ever producing a decision. Chain-splitting and quote-stripping are now pure bash (no per-segment fork), which closes that route in the common case, but the guard remains as a backstop against exceptionally large or operator-dense input — see [ADR-010](../docs/adr/adr-010-python3-for-json-extraction.md) for the fuller history of this fix.
- **`$(...)` nesting depth**: only one level of nested parens inside a command substitution is tolerated (e.g. `$(echo $(git reset --hard))`). Deeper nesting isn't balanced correctly by the regex and may not be recursed into — full paren balancing isn't practical with plain bash/POSIX-ish regex.
- **`bash -lc`/`bash -xc` (clustered interpreter flags)**: only the exact `bash -c`/`sh -c` spelling is recognized as a nested shell. A clustered flag like `bash -lc '...'` or `bash -xc '...'` is not currently detected.
- **Non-Claude-Code actions**: this only governs what Claude Code itself runs. It does nothing for a human running the same commands, or for other tools/CI acting on the repo.

Treat this as one layer of defense-in-depth (alongside commits, backups, and `git reflog`), not a replacement for them.

Hooks are also loaded at session start — changes to this plugin require restarting Claude Code to take effect.
