# ADR-008: No External Dependencies in Hook Scripts

**Status:** Accepted
**Date:** 2026-03-27

## Context

The `allow-plugin-reads.sh` PreToolUse hook used `jq` to parse the JSON input from Claude Code. On systems where `jq` is installed via version managers (asdf, mise, nvm-style shims), hook subprocesses may run with a minimal PATH that does not include shim directories. When `jq` was not found, the script produced no output, causing Claude Code to fall through to the default permission prompt -- defeating the hook entirely.

Options were: (A) document that users must have `jq` on a non-shim PATH; (B) replace `jq` with pure bash string manipulation; (C) hardcode the full path to `jq` in the script.

## Decision

Option B -- hook scripts must use only POSIX/bash builtins and coreutils available at `/usr/bin` or `/bin`, with no dependency on tools that may be installed via version managers.

## Alternatives Considered

- **Document the jq requirement (A):** Pushes the burden onto users and is fragile -- different systems install jq in different ways, and the failure mode (silent no-op) is difficult to debug.
- **Hardcode jq path (C):** Non-portable across systems and breaks if jq is upgraded or relocated.

## Consequences

**Positive:**
- Hook works reliably regardless of how the user's shell tools are installed.
- No silent failures -- the script either matches and allows, or produces no output (fall-through), with no intermediate error state.
- Zero external dependencies makes the hook trivially portable.

**Negative:**
- Bash string manipulation for JSON parsing is less robust than `jq` -- it assumes a specific key ordering or structure. Acceptable here because the Claude Code hook input schema is stable and the extraction is simple (single field).
