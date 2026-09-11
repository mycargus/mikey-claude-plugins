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
