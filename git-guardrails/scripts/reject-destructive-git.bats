#!/usr/bin/env bats
# Tests for reject-destructive-git.sh. Invokes the script as a subprocess
# via its real PreToolUse stdin contract (JSON on stdin) and asserts on
# $output, since the script's exit code is always 0 by design (deny is
# signaled via hookSpecificOutput JSON, not a nonzero exit).

SCRIPT="$BATS_TEST_DIRNAME/reject-destructive-git.sh"

# Builds the {"tool_input":{"command":"..."}} JSON payload for a given
# command string and runs the hook script against it.
run_hook() {
  local command="$1"
  local json
  json=$(printf '{"tool_input":{"command":"%s"}}' "$command")
  run bash "$SCRIPT" <<< "$json"
}

# Runs the hook against a raw, already-JSON-encoded payload. Used for cases
# where the command itself contains double quotes, so the JSON encoding
# (and its escaping) needs to be controlled precisely.
run_hook_json() {
  run bash "$SCRIPT" <<< "$1"
}

# --- Regression: safe commands still pass through untouched ---

@test "safe command (git status) passes through with no output" {
  run_hook "git status"
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

@test "safe command (git log) passes through with no output" {
  run_hook "git log"
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

@test "safe command (git diff) passes through with no output" {
  run_hook "git diff"
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

# --- Regression: plain destructive commands are still denied ---

@test "plain git reset --hard is denied" {
  run_hook "git reset --hard"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "plain git push --force is denied" {
  run_hook "git push origin main --force"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "plain git branch -D is denied" {
  run_hook "git branch -D some-branch"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "plain git clean -f is denied" {
  run_hook "git clean -f"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "plain git checkout . is denied" {
  run_hook "git checkout ."
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# --- New: top-level chain splitting ---

@test "; chain: destructive command as second segment is denied" {
  run_hook "git status; git reset --hard"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "&& chain: destructive command as second segment is denied" {
  run_hook "git status && git reset --hard"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "|| chain: destructive command after a failed guard is denied" {
  run_hook "true || git branch -D some-branch"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "pipe chain: destructive command downstream of a pipe is denied" {
  run_hook "git status | xargs -I {} git reset --hard"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "chain of entirely safe commands still passes through" {
  run_hook "git status && git log"
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

# --- New: command substitution ---

@test '$(...) command substitution containing a destructive command is denied' {
  run_hook '$(echo git reset --hard)'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "backtick command substitution containing a destructive command is denied" {
  run_hook '`git clean -f`'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# --- New: nested shell invocation ---

@test "bash -c wrapping a destructive command is denied" {
  run_hook "bash -c 'git reset --hard'"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "sh -c wrapping a destructive command is denied" {
  run_hook "sh -c 'git branch -D foo'"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "bash -c wrapping a safe command still passes through" {
  run_hook "bash -c 'git status'"
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

# These two use a raw JSON payload with the inner command's double quotes
# escaped as \", which is how Claude Code actually encodes a `bash -c
# "..."` command on the wire. This is the realistic shape of the bug: the
# original script's naive extraction stops at the first literal quote
# character it sees, escaped or not, and truncates before ever reaching
# the destructive payload.
@test "bash -c with a double-quoted destructive command is denied" {
  run_hook_json '{"tool_input":{"command":"bash -c \"git reset --hard\""}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "sh -c with a double-quoted destructive command is denied" {
  run_hook_json '{"tool_input":{"command":"sh -c \"git branch -D foo\""}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# --- Finding 3: alternate flag spellings and global options must be caught ---

@test "git -C . reset --hard (global option before subcommand) is denied" {
  run_hook "git -C . reset --hard"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "git --no-pager reset --hard (global option before subcommand) is denied" {
  run_hook "git --no-pager reset --hard"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "git clean -xdf (clustered short flags) is denied" {
  run_hook "git clean -xdf"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "git clean -d -f (separate short flags) is denied" {
  run_hook "git clean -d -f"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "git clean --force (long flag spelling) is denied" {
  run_hook "git clean --force"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "git reset -q --hard HEAD~1 (flag before positional arg) is denied" {
  run_hook "git reset -q --hard HEAD~1"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "git reset HEAD~1 --hard (flag after positional arg) is denied" {
  run_hook "git reset HEAD~1 --hard"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "git branch --delete --force foo (long flag spelling) is denied" {
  run_hook "git branch --delete --force foo"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "git checkout -- . (double-dash before dot) is denied" {
  run_hook "git checkout -- ."
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# --- Finding 5: --force belonging to an unrelated command in a different
# chain segment must not cause a false positive ---

@test "; chain: --force on an unrelated command in a later segment is allowed" {
  run_hook "git push origin main; npm install --force"
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

@test "&& chain: --force-rm on an unrelated command in a later segment is allowed" {
  run_hook "git push origin main && docker build --force-rm ."
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

# --- Finding 6: a git phrase embedded inside someone else's quoted string
# argument must not be mistaken for an actual git invocation ---

@test 'git commit -m with "git reset --hard" inside the message is allowed' {
  run_hook_json '{"tool_input":{"command":"git commit -m \"cleanup: git reset --hard was too aggressive\""}}'
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

@test 'grep for the literal string "git clean -f" is allowed' {
  run_hook_json '{"tool_input":{"command":"grep -rn \"git clean -f\" README.md"}}'
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

@test 'echo of the literal string "git reset --hard" is allowed' {
  run_hook_json '{"tool_input":{"command":"echo \"git reset --hard\" >> docs/dangerous.md"}}'
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

@test 'gh pr comment body mentioning "git push --force" is allowed' {
  run_hook_json '{"tool_input":{"command":"gh pr comment 12 -b \"do not git push --force here\""}}'
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

# --- Finding 8: substitution/nested-shell structural cases ---

@test 'multiple $(...) substitutions in one segment: the second, destructive one is denied' {
  run_hook '$(echo hi) $(git reset --hard)'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test 'one level of nested $(...) containing a destructive command is denied' {
  run_hook '$(echo $(git reset --hard))'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "bash/sh must be their own word: mybash -c is not treated as a nested shell" {
  run_hook "mybash -c 'git reset --hard'"
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

@test "bash/sh must be their own word: flash -c is not treated as a nested shell" {
  run_hook "flash -c 'git reset --hard'"
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

# A mismatched quote pair (opens with ", closes with ') must not be
# accepted as a valid bash -c/sh -c invocation -- it isn't valid shell
# syntax in the first place, and treating it as one would mean trusting an
# unbalanced string as if it were the whole quoted payload.
@test "bash -c with a mismatched quote pair is not treated as a valid nested shell" {
  run_hook_json '{"tool_input":{"command":"bash -c \"git reset --hard'"'"'"}}'
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

# bash -lc / bash -xc (clustered short flags on the interpreter invocation
# itself) are intentionally out of scope -- see README Limitations. This
# documents the current (unsupported) behavior rather than asserting it
# should change.
@test "bash -lc (clustered flags) is NOT currently recognized as a nested shell" {
  run_hook "bash -lc 'git reset --hard'"
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

# --- Finding 10: extract_command edge cases (empty/missing command) ---

@test "empty command value is allowed" {
  run_hook_json '{"tool_input":{"command":""}}'
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

@test "missing command key is allowed" {
  run_hook_json '{"tool_input":{}}'
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}

# --- python3-based extraction: bug regressions and correctness ---
#
# The original extract_command() was a hand-rolled char-by-char bash
# scanner with three known bugs: (1) O(n^2) string concatenation that can
# blow past the hook's 5s timeout on large commands, (2) a whitespace-
# sensitive `"command":"` marker that misses `"command": "..."` (spaces
# around the colon/quotes), and (3) incomplete unescaping (\r \b \f decode
# to literal letters, \uXXXX isn't decoded at all). These tests pin down
# that the new python3-json-module-based implementation fixes all three,
# without changing any of the 43 tests above.

@test "escaped-quote nesting still extracts the full command (bash -c with inner double quotes)" {
  run_hook_json '{"tool_input":{"command":"bash -c \"git reset --hard\""}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# A ~100KB command must not hit the O(n^2) blowup of the old char-by-char
# bash scanner. 3s is comfortably below the hook's configured 5s timeout
# (.claude-plugin/plugin.json) but well above the sub-100ms this should
# actually take with a real (linear-time) JSON parser, so the bound is
# tight enough to catch a regression without being flaky on slower CI.
#
# NOTE: this filler is plain repeated text with no chain/substitution
# operators in it, so on today's implementation it's actually caught by
# the length half of the hard complexity guard (command_too_complex --
# see Finding 2) rather than by exercising the real per-segment check
# logic end to end. That's fine as a "doesn't hang" regression test, but
# it does NOT exercise the dimension that actually made the old
# implementation slow (operator/substitution *count*, not raw byte size)
# -- see the tests below this one for that.
@test "large (~100KB) command does not hang or time out" {
  local filler
  filler=$(head -c 100000 /dev/zero | tr '\0' 'a')
  local command="echo ${filler}; git reset --hard"
  local json
  json=$(printf '{"tool_input":{"command":"%s"}}' "$command")
  run timeout 3 bash "$SCRIPT" <<< "$json"
  [ "$status" -ne 124 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

# --- Finding 2: substitution/segment *count* (not raw byte size) is what
# used to blow past the hook's timeout, via one `awk`/`sed` subprocess
# fork per chain segment or substitution. These commands are small in
# byte size (a few KB) but operator-dense. ---

# 1000 $(...) substitutions is well over the hard complexity guard's
# COMPLEXITY_MAX_OPERATORS threshold (200), so this is expected to be
# denied by that guard almost instantly -- proving the guard itself works
# as a backstop, distinct from the test below which proves the underlying
# per-segment logic is also fast on its own, without relying on the guard.
@test "1000x \$(echo a) substitutions (large operator count) is denied via the complexity guard, well under 1s" {
  local subs
  subs=$(python3 -c "print(' '.join(['\$(echo a)'] * 1000))")
  local command="${subs}; git reset --hard"
  local json
  json=$(printf '{"tool_input":{"command":"%s"}}' "$command")
  run timeout 1 bash "$SCRIPT" <<< "$json"
  [ "$status" -ne 124 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"too large or complex"* ]]
}

# 150 substitutions is under COMPLEXITY_MAX_OPERATORS (200), so this
# exercises the real per-segment/quote-stripping logic end to end (not the
# guard) and proves that logic alone -- now pure bash parameter expansion
# and regex, no per-call awk/sed fork -- is fast well within 1s. Before
# the Finding 2 fix, 500 substitutions alone measured ~2.7s; 150 real
# substitutions processed through the actual check logic here in well
# under 1s is a direct demonstration that the fork-per-segment/
# substitution cost is gone, not just that the guard catches egregious
# cases.
@test "150x \$(echo a) substitutions (below the complexity guard) is still denied via the real check, well under 1s" {
  local subs
  subs=$(python3 -c "print(' '.join(['\$(echo a)'] * 150))")
  local command="${subs}; git reset --hard"
  local json
  json=$(printf '{"tool_input":{"command":"%s"}}' "$command")
  run timeout 1 bash "$SCRIPT" <<< "$json"
  [ "$status" -ne 124 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" != *"too large or complex"* ]]
}

@test "whitespace-formatted JSON (spaces around colons/braces) is still detected and denied" {
  run_hook_json '{"tool_input": {"command": "git reset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test "extra whitespace and newlines in the JSON payload don't hide the command" {
  run_hook_json '{
    "tool_input" : {
      "command" : "git   push origin main --force"
    }
  }'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test '\r escape decodes to a real carriage return, not the literal letter r (git\rreset --hard is denied)' {
  run_hook_json '{"tool_input":{"command":"git\rreset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test '\uXXXX escapes decode to their character (git reset --hard is denied)' {
  run_hook_json '{"tool_input":{"command":"\u0067it reset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

@test '\b and \f escapes round-trip through the real JSON decoder without corrupting the rest of the command' {
  # Sanity check that \b (backspace) and \f (form feed) don't throw off
  # extraction of a plain destructive command placed right after them --
  # the old catch-all `*)` case in the hand-rolled unescaper turned these
  # into the literal letters b/f instead of control characters, which
  # could shift or corrupt subsequent characters.
  run_hook_json '{"tool_input":{"command":"echo \b\f; git reset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# --- python3-based extraction: fail-closed policy ---

@test "python3 not resolvable (primary missing, PATH fallback disabled) denies fail-closed with a python3-related reason" {
  run env GIT_GUARDRAILS_PYTHON3_PRIMARY=/nonexistent/python3 GIT_GUARDRAILS_TEST_DISABLE_PYTHON3_FALLBACK=1 bash "$SCRIPT" <<< '{"tool_input":{"command":"git status"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"python3"* ]]
  [ "$status" -eq 0 ]
}

@test "malformed JSON on stdin denies fail-closed with a parse-failure reason" {
  run_hook_json 'this is not { valid json'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"pars"* ]]
  [ "$status" -eq 0 ]
}

@test "a tool_input.command that isn't a string denies fail-closed rather than risk misinterpreting it" {
  run_hook_json '{"tool_input":{"command":123}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# --- Finding 1: interpreter startup hijack (sitecustomize/usercustomize via
# PYTHONPATH, and a hijacked-but-exit-0 interpreter more generally) must not
# silently disable the hook. Isolated mode (-I) closes the real-world route;
# the sentinel marker is defense-in-depth for the class of "python3 ran and
# exited 0 but didn't actually do the extraction" more broadly. ---

# Reproduces the PYTHONPATH route from the review's verified repro (a
# sitecustomize.py that calls os._exit(0) before the -c payload runs) using
# a throwaway temp dir -- never touches a real site-packages directory.
# Before the -I fix, this made python3 exit 0 with empty stdout, which was
# indistinguishable from "valid JSON, no command field" and silently
# allowed the destructive command through.
@test "interpreter startup hijack via PYTHONPATH sitecustomize is neutralized (isolated mode + sentinel)" {
  local hijack_dir="$BATS_TEST_TMPDIR/hijack"
  mkdir -p "$hijack_dir"
  printf 'import os\nos._exit(0)\n' > "$hijack_dir/sitecustomize.py"
  run env PYTHONPATH="$hijack_dir" bash "$SCRIPT" <<< '{"tool_input":{"command":"git reset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# Same idea via a user site-packages usercustomize.py (the exact repro
# shape from the review), but resolved to a throwaway temp dir instead of
# the real ~/Library/Python (or platform equivalent) by pointing
# PYTHONPATH at it directly -- this exercises the same "site machinery
# imports and runs an attacker file before -c" mechanism -I disables,
# without ever writing to or reading from a real per-user site-packages
# directory.
@test "interpreter startup hijack via usercustomize-style file is neutralized (isolated mode + sentinel)" {
  local hijack_dir="$BATS_TEST_TMPDIR/hijack2"
  mkdir -p "$hijack_dir"
  printf 'import os\nos._exit(0)\n' > "$hijack_dir/usercustomize.py"
  run env PYTHONPATH="$hijack_dir" bash "$SCRIPT" <<< '{"tool_input":{"command":"git reset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# Proves the sentinel-marker defense specifically (independent of -I):
# a stub "interpreter" that satisfies resolve_python3's probe (so it isn't
# filtered out at resolution time -- it prints the exact probe marker when
# invoked with the probe's code) but silently exits 0 with no output for
# any other invocation, simulating a more deliberately-crafted hijack that
# passes the probe yet still doesn't do real extraction. Without the
# sentinel check, this would look identical to "valid JSON, no command
# field" and allow the destructive command through.
@test "a stub interpreter that passes the python3 probe but no-ops on real extraction is caught by the sentinel check" {
  local stub="$BATS_TEST_TMPDIR/fake_python3"
  cat > "$stub" <<'STUB'
#!/bin/sh
case "$*" in
  *GITGUARDRAILS_PROBE_OK*) echo GITGUARDRAILS_PROBE_OK ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$stub"
  run env GIT_GUARDRAILS_PYTHON3_PRIMARY="$stub" bash "$SCRIPT" <<< '{"tool_input":{"command":"git reset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"tamper"* ]]
  [ "$status" -eq 0 ]
}

# --- Finding 3: GIT_GUARDRAILS_PYTHON3_PRIMARY (and its fallback-disable
# sibling) must be inert unless actually running under bats -- not just
# "bats happens to always have its sentinel set", which would be true of
# every test in this file and would prove nothing about the gating itself.
# This test explicitly strips BATS_TEST_NAME from the child process before
# setting the override, so the override is exercised in an environment
# that does NOT look like a bats run even though we're physically inside
# one -- proving the gating condition itself, not an accident of always
# running under bats. ---

@test "GIT_GUARDRAILS_PYTHON3_PRIMARY=/usr/bin/true is inert once BATS_TEST_NAME is absent, and the hook still denies" {
  run env -u BATS_TEST_NAME GIT_GUARDRAILS_PYTHON3_PRIMARY=/usr/bin/true bash "$SCRIPT" <<< '{"tool_input":{"command":"git reset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# --- Finding 4: a broken-but-executable primary must not be trusted
# outright, and must not be indistinguishable from a JSON-parse failure. ---

@test "a broken-but-executable python3 primary is not trusted; the hook falls back to a working PATH python3" {
  local stub="$BATS_TEST_TMPDIR/broken_python3"
  cat > "$stub" <<'STUB'
#!/bin/sh
echo "xcrun: error: invalid active developer path" >&2
exit 1
STUB
  chmod +x "$stub"
  run env GIT_GUARDRAILS_PYTHON3_PRIMARY="$stub" bash "$SCRIPT" <<< '{"tool_input":{"command":"git reset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"Destructive git command blocked"* ]]
  [ "$status" -eq 0 ]
}

@test "when neither the primary nor any PATH python3 works, the hook denies with a distinct 'no working interpreter' reason" {
  local stub="$BATS_TEST_TMPDIR/broken_python3"
  cat > "$stub" <<'STUB'
#!/bin/sh
exit 1
STUB
  chmod +x "$stub"
  local bash_bin
  bash_bin=$(command -v bash)
  run env -i PATH="$BATS_TEST_TMPDIR" BATS_TEST_NAME="$BATS_TEST_NAME" GIT_GUARDRAILS_PYTHON3_PRIMARY="$stub" "$bash_bin" "$SCRIPT" <<< '{"tool_input":{"command":"git reset --hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"no working python3"* ]]
  [ "$status" -eq 0 ]
}

# --- Finding 5: an embedded NUL byte in the command must deny, not pass
# through to be silently truncated (bash $(...)) or fused (other
# consumers) differently than what the hook actually inspected. Uses a
# real \u0000 JSON escape (decoded to an actual NUL by python's json
# module), since a literal NUL byte can't easily survive bash test
# infrastructure. ---

@test "a command containing an embedded NUL byte (via \\u0000) denies rather than risk a truncation/fusion mismatch" {
  run_hook_json '{"tool_input":{"command":"git reset\u0000--hard"}}'
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [ "$status" -eq 0 ]
}

# --- Finding 6: deny()'s reason string must be escaped so a reason
# containing a double quote or backslash still produces valid JSON. All
# current call sites are hardcoded literals, so this sources the script
# (safe: see the BASH_SOURCE/$0 guard at the bottom of the script, which
# only runs main() when the file is executed directly) to call deny()
# directly with a crafted reason. ---

@test "deny() escapes a reason containing a double quote and a backslash into valid JSON" {
  run bash -c 'source "$1"; deny "$2"' _ "$SCRIPT" 'reason with a "quote" and a backslash \ in it'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json, sys; json.load(sys.stdin)'
}

# --- Finding 7: a non-ASCII character (e.g. an em dash in a commit
# message) must not falsely deny under a non-UTF-8 locale. json.loads on
# bytes read from stdin.buffer (rather than json.load on a text-mode
# sys.stdin, which goes through the locale's codec) removes the locale
# from the trust chain. ---

@test "a non-ASCII character in a safe command is still correctly allowed under a forced non-UTF-8 locale" {
  run env LC_ALL=C LANG=C PYTHONUTF8=0 bash "$SCRIPT" <<< '{"tool_input":{"command":"git commit -m \"em dash — test\""}}'
  [ -z "$output" ]
  [ "$status" -eq 0 ]
}
