# ADR-010: Use python3 for JSON Extraction in the git-guardrails Hook

**Status:** Accepted
**Date:** 2026-09-11

## Context

The `git-guardrails` `reject-destructive-git.sh` PreToolUse hook extracts `tool_input.command` from the hook's JSON stdin using a hand-rolled bash function, `extract_command()`, written per ADR-008 ("no jq / no dependencies that may only be reachable via asdf/mise shims in hook subprocesses"). An adversarial security review found three real bugs in that hand-rolled scanner:

1. **Quadratic time complexity.** The char-by-char `while` loop uses `out+=` string concatenation, which is O(n^2) in bash. On a ~50KB command this takes 5+ seconds. The hook's configured `timeout` in `.claude-plugin/plugin.json` is 5 seconds, so a large enough command causes the hook process to be killed before it can print its deny decision -- a silent fail-open bypass of the entire guardrail.
2. **Whitespace-sensitive field marker.** The marker `'"command":"'` requires exactly zero whitespace around the colon and quotes. A payload shaped like `{"tool_input": {"command": "git reset --hard"}}` (spaces after the colons) is not detected as containing a command at all, silently disabling the hook for that entire payload shape.
3. **Incomplete unescaping.** `\r`, `\b`, `\f` decoded to the literal letters `r`/`b`/`f` (via a `*)` catch-all case) instead of their control characters, and `\uXXXX` sequences were not decoded at all (became literal `uXXXX` text). This could corrupt the extracted command in ways that either mask a real match or create a spurious one.

These are correctness bugs in a from-scratch JSON parser, not bash-specific quirks -- the fundamental problem is that ADR-008 asked for bash string manipulation to stand in for a real JSON decoder, and a real JSON decoder is a nontrivial thing to hand-roll correctly.

The options considered were:

- **(A) Keep bash string manipulation, fix the three bugs in place.** Possible for bugs 2 and 3 (loosen the marker regex, complete the escape table and add `\uXXXX` decoding), but bug 1 is structural: bash string concatenation is inherently O(n^2), and there's no way to do single-pass linear-time string building in bash without an external tool.
- **(B) Shell out to `jq`.** Real JSON parsing, but ADR-008 already rejected `jq` specifically for the shim-reachability problem: hook subprocesses may run with a minimal PATH that doesn't include the shim directories where asdf/mise install `jq`, and a missing `jq` silently produces no output there today (a hook that just doesn't fire, rather than one that denies).
- **(C) Shell out to `python3` and use its `json` module.**
- **(D) Accept the bugs as documented limitations.** Bug 1 in particular is a security bypass (fail-open on a large enough payload), not a cosmetic gap; leaving it undocumented-as-acceptable was not viable.

## Decision

Option C -- replace `extract_command()` with a call to `python3 -c '...'` that reads stdin and parses it with the `json` module, extracting `tool_input.command`.

This departs from ADR-008 for `python3` specifically. `python3` has the exact same shim-reachability risk in principle that `jq` did: if PATH resolution alone is trusted, a hook subprocess with a minimal PATH could fail to find `python3` on a system where it's only installed via asdf/pyenv/mise shims. This is mitigated with an explicit two-step resolution strategy (`resolve_python3()` in `reject-destructive-git.sh`):

1. Try `/usr/bin/python3` first. On macOS this is Apple's stable system stub, not managed by asdf/pyenv/mise -- it doesn't have the shim-reachability problem `jq` had.
2. If that path doesn't exist, fall back to whatever `python3` resolves to via `command -v` on the subprocess's PATH. This covers Linux and other systems where `/usr/bin/python3` may not exist but a real, non-shimmed `python3` might still be reachable.
3. If neither resolves, extraction fails outright (see fail-closed policy below) rather than silently producing empty output.

Unlike ADR-008's original bash-only approach, `python3` is chosen here specifically because a real JSON decoder is the only way to fix bug 1 (linear-time parsing) and bug 3 (correct escape/`\uXXXX` decoding) without hand-rolling and re-hand-rolling parser logic that keeps having bugs. `python3` ships as part of the OS on macOS and is near-universal on Linux CI images, which keeps the practical portability of ADR-008's original goal (works without requiring the user to separately install a JSON tool) while getting a correct parser.

## Alternatives Considered

- **Fix the bash scanner in place (A):** Solves bugs 2 and 3 but not bug 1 -- bash string concatenation is inherently quadratic, so any fix that keeps building the output character-by-character in bash retains the timeout/fail-open risk on large commands. Rejected because the security bypass is the most serious of the three bugs and this path doesn't close it.
- **Shell out to jq (B):** Real, linear-time JSON parsing, but ADR-008 already evaluated and rejected `jq` for this exact hook for the shim-reachability reason. Revisiting that call for `jq` specifically wasn't warranted when `python3` solves the same problem with a more reliable hardcoded-path fallback (`/usr/bin/python3` is a stable OS-provided path on macOS in a way `jq` never is, since `jq` is not shipped with the OS).
- **Accept the bugs as documented limitations (D):** Bug 1 is a genuine security bypass (fail-open under a large payload within the hook's own timeout budget), not an edge case worth carrying forward. Rejected.

## Consequences

**Positive:**
- Real, linear-time JSON parsing eliminates the O(n^2) timeout/fail-open risk *in the extraction step itself*, correctly handles whitespace-formatted JSON, and correctly decodes all standard JSON escapes including `\uXXXX`.
- The shim-reachability risk ADR-008 raised for `jq` is addressed head-on for `python3` via the hardcoded-path-first resolution strategy, rather than re-litigated or ignored.
- Explicit fail-closed policy: if no working `python3` can be resolved at all, or if it runs but the JSON can't be parsed as the expected shape, the hook denies the tool call and explains why, instead of the old behavior of silently producing an empty (and therefore always-allowed) command string. The "no command field / not a Bash tool call" case (e.g. `tool_input` absent, or `tool_input.command` absent or empty) remains an explicit, tested ALLOW outcome, distinct from an extraction failure -- most hook invocations are simply not a Bash command, and treating that as a failure would make the hook deny far too broadly.

**Negative:**
- Introduces a runtime dependency on `python3` being resolvable in the hook subprocess's environment. If a user's system truly has no working `python3` anywhere (neither at `/usr/bin/python3` nor on PATH), the hook now denies every Bash command outright rather than falling through to an unchecked allow. This is an intentional trade-off (fail closed over fail open) but is a behavior change worth calling out to users -- see the git-guardrails README's Limitations section.
- The extraction logic itself (the JSON-parsing code) now lives in an embedded Python string inside a bash script, which is slightly less readable/greppable than a self-contained bash function, and requires care with quoting when embedding the Python source inside the shell script.

**Revisions from a follow-up adversarial review (post-acceptance):**

The original version of this ADR overstated what the python3 migration closed. It claimed the change "eliminates the O(n^2) timeout/fail-open risk" and that "a malformed or adversarial payload can no longer bypass the guardrail by breaking extraction." Both claims were too broad, and a subsequent review found concrete counterexamples:

- **The timeout/fail-open risk moved, it wasn't eliminated.** Fixing extraction's own quadratic behavior did nothing for the *downstream* chain-splitting and quote-stripping logic, which (at the time) forked `awk` once per `check_command` call and `sed` twice per `check_segment` call. A command built from hundreds of chain operators or `$(...)` substitutions -- each one recursing into another round of forking -- could still exhaust the hook's 5-second timeout budget well before extraction was ever the bottleneck. This has since been fixed by rewriting chain-splitting and quote-stripping as pure bash parameter-expansion/regex (no per-segment subprocess fork), plus a hard complexity guard (denies outright above a fixed length/operator-count threshold) as a backstop. See the git-guardrails bats suite for the regression tests that pin this down.
- **"Can no longer bypass by breaking extraction" was false as stated.** The `python3` subprocess itself could be silently redirected without "breaking" in any way this ADR anticipated: CPython's interpreter-startup machinery (a `sitecustomize.py`/`usercustomize.py` file reachable via `PYTHONPATH` or per-user site-packages) can run arbitrary code and exit before the `-c` payload ever executes, producing exit 0 with empty stdout -- indistinguishable, at the time, from the legitimate "no command field" case. Separately, the test-only `GIT_GUARDRAILS_PYTHON3_PRIMARY` override was honored unconditionally, so a real OS binary that isn't python3 at all (e.g. `/usr/bin/true`) pointed at via that variable produced the same silent-allow outcome, with no attacker-controlled file needed. Both are now closed: `python3` is invoked in isolated mode (`-I`, disabling `site` processing and ignoring `PYTHON*` env vars including `PYTHONPATH`), its output is gated on an explicit sentinel marker the extraction code writes before doing anything else (so a hijacked-but-exit-0 interpreter is caught even if isolation were somehow bypassed), the resolved candidate is behaviorally probed (not just checked for `-x`) before being trusted, and the test-only override variables are inert unless a bats-specific environment marker is present.

What this ADR can accurately claim today: real, linear-time, correctly-escaped JSON parsing for the extraction step; a resolution/probe strategy that only trusts an interpreter demonstrated to actually behave like python3; and an isolated, sentinel-verified invocation that closes the specific startup-hijack and interpreter-substitution routes identified above. It cannot claim that no payload can ever defeat the guardrail -- see the git-guardrails README's Limitations section, which is the accurate, current statement of residual risk (including the hard complexity guard's own bounds, and everything downstream of extraction still being regex/string-based rather than a real shell parser).
