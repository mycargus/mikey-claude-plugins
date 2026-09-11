#!/usr/bin/env bash
# Blocks destructive git commands before they run.
#
# Extraction of tool_input.command from the hook's JSON stdin shells out to
# python3's real `json` module (see mikey-claude-plugins docs/adr/adr-010).
# This departs from ADR-008 ("no jq / no dependencies that may only be
# reachable via asdf/mise shims") for python3 specifically -- the same
# shim-reachability risk applies, and is mitigated by preferring the
# hardcoded, non-shimmed /usr/bin/python3 before falling back to a PATH
# lookup (see resolve_python3()). If no working python3 can be resolved, or
# if it runs but the JSON can't be parsed, this hook fails CLOSED (denies)
# rather than silently letting an unverified command through.
#
# The python3 subprocess is invoked in isolated mode (-I) and its output is
# gated on a sentinel marker -- see extract_command() -- so a hijacked
# interpreter (malicious sitecustomize/usercustomize, PYTHONPATH injection,
# or a GIT_GUARDRAILS_PYTHON3_PRIMARY pointed at a non-python binary) can't
# silently produce empty output and be mistaken for the ordinary "no command
# field" case.
#
# Everything downstream of extraction (chain splitting, pattern matching)
# is regex/string-based, not a real shell parser. It does not defend
# against arbitrarily nested quoting, $IFS tricks, base64 or other encoded
# payloads, string concatenation, aliases, or eval/xargs indirection -- see
# README Limitations. It is also bounded by a hard complexity guard (see
# command_too_complex()) rather than an unbounded amount of work, so an
# extremely large or operator-dense command is denied outright instead of
# risking the hook's 5s timeout budget.

# A fixed marker the python3 subprocess writes as the very first line of
# its stdout, before doing anything else. extract_command() requires this
# marker to be present in the subprocess's output before trusting any of
# it. This defends against a hijacked or substituted interpreter (see
# Finding 1/3 in the review that drove this) exiting 0 with empty stdout,
# which would otherwise be indistinguishable from the legitimate "valid
# JSON, no command field" case. Change this string and the corresponding
# literal in the embedded python source together if it's ever changed.
GIT_GUARDRAILS_SENTINEL="GITGUARDRAILS_SENTINEL_7f3a2b1c9e"

# Hard complexity guard (defense-in-depth against Finding 2): a command
# this large, or with this many chain/substitution operators, is denied
# outright without attempting the check. Real one-liners essentially never
# approach either bound -- a handful of `;`/`&&`/`$(...)` is already an
# unusually elaborate command -- while a payload built from hundreds of
# chain or substitution operators is the shape that used to defeat the
# per-segment subprocess forking this script no longer does. These
# thresholds are a belt-and-suspenders backstop on top of that fix, not a
# replacement for it.
COMPLEXITY_MAX_LENGTH=100000
COMPLEXITY_MAX_OPERATORS=200

# Resolves a python3 binary to use for JSON extraction, per ADR-010's
# resolution strategy: try the hardcoded, non-shimmed /usr/bin/python3
# first (stable on macOS, not managed by asdf/pyenv/mise), then fall back
# to whatever `python3` resolves to on PATH (covers Linux/other systems
# where /usr/bin/python3 may not exist). A candidate is only accepted if it
# actually runs and behaves like python3 (see python3_probe_ok) -- an
# executable that merely exists at that path but errors out, or isn't
# python3 at all, is not enough. Prints the resolved path and returns 0, or
# returns 1 if no working candidate is found.
#
# GIT_GUARDRAILS_PYTHON3_PRIMARY and GIT_GUARDRAILS_TEST_DISABLE_PYTHON3_FALLBACK
# are test-only overrides (see reject-destructive-git.bats) that let tests
# deterministically simulate "no python3 resolvable" without depending on
# what's actually installed. They are only honored when BATS_TEST_NAME is
# set (i.e. we are actually running under bats) -- outside of a test run,
# both variables are inert, so a stray/leaked value (e.g. landing in
# .claude/settings.json's `env` block, or an unrelated shell profile)
# cannot influence which interpreter is used. Even if that gating were
# somehow bypassed, python3_probe_ok()'s behavioral check (not just
# executable-bit + exit-code-0) and extract_command()'s sentinel check
# mean pointing GIT_GUARDRAILS_PYTHON3_PRIMARY at a non-python executable
# (e.g. /usr/bin/true) still can't turn a deny into an allow -- it can only
# make the hook fail closed (deny) more often than it otherwise would.
resolve_python3() {
  local primary="/usr/bin/python3"
  if [[ -n "${BATS_TEST_NAME:-}" && -n "${GIT_GUARDRAILS_PYTHON3_PRIMARY:-}" ]]; then
    primary="$GIT_GUARDRAILS_PYTHON3_PRIMARY"
  fi

  if python3_probe_ok "$primary"; then
    printf '%s' "$primary"
    return 0
  fi

  if [[ -n "${BATS_TEST_NAME:-}" && -n "${GIT_GUARDRAILS_TEST_DISABLE_PYTHON3_FALLBACK:-}" ]]; then
    return 1
  fi

  local fallback
  fallback=$(command -v python3 2>/dev/null) || return 1
  [[ -n "$fallback" ]] || return 1

  if python3_probe_ok "$fallback"; then
    printf '%s' "$fallback"
    return 0
  fi

  return 1
}

# Cheaply verifies that a candidate binary is executable AND actually
# behaves like python3 -- not just that something exists at that path and
# exits 0. Runs in isolated mode (-I, see extract_command) and checks the
# resulting stdout for an exact, distinctive marker. This is what stops a
# broken-but-executable /usr/bin/python3 (e.g. macOS without Command Line
# Tools installed, which prints an error and exits nonzero) from being
# treated as "found" with no fallback attempted, and also stops a
# non-python executable (e.g. /usr/bin/true, which ignores its arguments
# and exits 0 with no output) from passing as a valid python3.
python3_probe_ok() {
  local py="$1" out
  [[ -n "$py" && -x "$py" ]] || return 1
  out=$("$py" -I -c 'print("GITGUARDRAILS_PROBE_OK")' 2>/dev/null)
  [[ "$out" == "GITGUARDRAILS_PROBE_OK" ]]
}

# Extracts tool_input.command from the hook's JSON stdin using python3's
# json module -- real, linear-time parsing instead of hand-rolled bash
# string scanning. Returns the command on stdout with status 0 on success
# (including the normal "no command field / not a Bash tool call" case,
# which yields an empty string, same as today).
#
# Return codes:
#   0 - success (command extracted, possibly empty)
#   2 - python3 ran but the input couldn't be parsed as the expected shape
#       (malformed JSON, tool_input.command present but not a string, an
#       embedded NUL byte in the command, etc)
#   3 - no working python3 binary could be resolved at all
#   4 - python3 (or whatever GIT_GUARDRAILS_PYTHON3_PRIMARY pointed at) ran
#       and exited 0, but its output didn't start with the expected
#       sentinel marker -- treated as interpreter tampering/substitution,
#       not a parse failure, and denied for that reason specifically
#
# python3 is invoked with -I (isolated mode: implies -E, ignore
# PYTHON*-prefixed env vars including PYTHONPATH, and -S, skip the `site`
# module's automatic sitecustomize/usercustomize import). This closes the
# interpreter-startup-hijack route where a file dropped in a user's
# site-packages (or pointed to via PYTHONPATH) runs arbitrary code before
# the `-c` payload does, and could otherwise exit early with no output.
extract_command() {
  local input="$1"
  local py
  py=$(resolve_python3) || return 3

  local out
  out=$("$py" -I -c '
import sys

SENTINEL = "'"$GIT_GUARDRAILS_SENTINEL"'"
sys.stdout.write(SENTINEL + "\n")

import json

try:
    data = json.loads(sys.stdin.buffer.read())
except Exception:
    sys.exit(1)

if not isinstance(data, dict):
    sys.exit(1)

tool_input = data.get("tool_input")
if tool_input is None:
    tool_input = {}
if not isinstance(tool_input, dict):
    sys.exit(1)

command = tool_input.get("command", "")
if command is None:
    command = ""
if not isinstance(command, str):
    sys.exit(1)

if "\x00" in command:
    sys.exit(1)

sys.stdout.write(command)
' <<< "$input" 2>/dev/null)
  local rc=$?

  if (( rc != 0 )); then
    return 2
  fi

  case "$out" in
    "$GIT_GUARDRAILS_SENTINEL"|"$GIT_GUARDRAILS_SENTINEL"$'\n'*) ;;
    *) return 4 ;;
  esac

  out="${out#"$GIT_GUARDRAILS_SENTINEL"}"
  out="${out#$'\n'}"

  printf '%s' "$out"
  return 0
}

# Denies the tool call, with an optional custom reason for the fail-closed
# paths (python3 not found / JSON couldn't be parsed / etc). Defaults to
# the original blocked-command message. The reason is escaped (backslash,
# then double quote) before being interpolated into the hand-rolled JSON
# output so a future caller passing dynamic content (not just today's
# hardcoded literals) can't produce invalid or injected JSON.
deny() {
  local reason="${1:-Destructive git command blocked by git-guardrails. If this is intentional, run it yourself from your terminal.}"
  reason="${reason//\\/\\\\}"
  reason="${reason//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
}

# Counts (non-overlapping) occurrences of a literal substring in a string,
# using pure bash parameter expansion (no subprocess). `${s//sub/}` uses
# shell glob-pattern matching, not regex, so this is only safe for
# substrings that contain no glob metacharacters (*, ?, [) -- true for all
# of the fixed operator tokens command_too_complex() checks.
count_occurrences() {
  local s="$1" sub="$2" replaced
  replaced="${s//$sub/}"
  echo $(( (${#s} - ${#replaced}) / ${#sub} ))
}

# Implements the hard complexity guard described above COMPLEXITY_MAX_*.
# Checked once, on the whole top-level command, before any recursive
# checking begins.
command_too_complex() {
  local cmd="$1"
  (( ${#cmd} > COMPLEXITY_MAX_LENGTH )) && return 0

  local total=0
  total=$(( total + $(count_occurrences "$cmd" '$(') ))
  total=$(( total + $(count_occurrences "$cmd" '`') ))
  total=$(( total + $(count_occurrences "$cmd" ';') ))
  total=$(( total + $(count_occurrences "$cmd" '&&') ))
  total=$(( total + $(count_occurrences "$cmd" '||') ))
  total=$(( total + $(count_occurrences "$cmd" '|') ))

  (( total > COMPLEXITY_MAX_OPERATORS ))
}

# Tests an already quote-stripped segment for one of the five blocked
# shapes. Each rule matches on the presence of its keyword/flag pair
# anywhere in the segment (not on adjacency to the git subcommand), so
# global options (`-C <path>`, `--no-pager`, ...) and flags appearing
# before or after other arguments don't evade detection.
is_blocked_git_segment() {
  local s="$1"

  # Require the literal word `git` to appear somewhere outside quotes --
  # this is what keeps an unrelated command that merely happens to use one
  # of the flag words (e.g. `docker build --force-rm .`) from matching.
  [[ "$s" =~ (^|[[:space:]])git([[:space:]]|$) ]] || return 1

  # git push ... --force / --force-with-lease
  if [[ "$s" =~ (^|[[:space:]])push([[:space:]]|$) ]] &&
     [[ "$s" =~ (^|[[:space:]])--force(-with-lease)?([[:space:]]|$) ]]; then
    return 0
  fi

  # git reset --hard (flags/args may surround --hard in either order)
  if [[ "$s" =~ (^|[[:space:]])reset([[:space:]]|$) ]] &&
     [[ "$s" =~ (^|[[:space:]])--hard([[:space:]]|$) ]]; then
    return 0
  fi

  # git branch -D, or --delete combined with --force/-f
  if [[ "$s" =~ (^|[[:space:]])branch([[:space:]]|$) ]]; then
    if [[ "$s" =~ (^|[[:space:]])-D([[:space:]]|$) ]]; then
      return 0
    fi
    if [[ "$s" =~ (^|[[:space:]])--delete([[:space:]]|$) ]] &&
       [[ "$s" =~ (^|[[:space:]])(--force|-f)([[:space:]]|$) ]]; then
      return 0
    fi
  fi

  # git clean -f / --force / clustered short flags containing f (-xdf, -df, -fd, ...)
  if [[ "$s" =~ (^|[[:space:]])clean([[:space:]]|$) ]]; then
    if [[ "$s" =~ (^|[[:space:]])--force([[:space:]]|$) ]]; then
      return 0
    fi
    if [[ "$s" =~ (^|[[:space:]])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$) ]]; then
      return 0
    fi
  fi

  # git checkout . / git checkout -- .
  if [[ "$s" =~ (^|[[:space:]])checkout([[:space:]]|$) ]] &&
     [[ "$s" =~ (^|[[:space:]])(--[[:space:]]+)?\.([[:space:]]|$) ]]; then
    return 0
  fi

  return 1
}

# Recursively checks a command string: splits it into top-level chain
# segments (on ; && || |) and checks each one via check_segment. Detection
# only ever runs on split segments, never on the raw unsplit string --
# otherwise the splitting below would be pure ceremony (a segment can only
# ever be a substring of the whole, so a whole-string check would always
# have already caught anything a segment check could catch, and would also
# blur segment boundaries -- see Finding 5/4 in the review that drove this).
#
# The chain split itself is pure bash parameter expansion (no subprocess
# fork per call) -- this used to shell out to `awk` once per invocation,
# which is what let a command built from hundreds of chain/substitution
# operators (each one recursing back into check_command) rack up enough
# forks to blow past the hook's 5s timeout (see Finding 2 in the review
# that drove this fix). `;` is replaced first, then the two-character
# operators `&&`/`||`, then any remaining single `|` -- matching the order
# the original awk regex alternation tried them in, so `||` isn't partially
# consumed by the single-`|` replacement before it runs.
check_command() {
  local cmd="$1"

  [[ -z "$cmd" ]] && return

  local transformed="$cmd"
  transformed="${transformed//;/$'\n'}"
  transformed="${transformed//&&/$'\n'}"
  transformed="${transformed//'||'/$'\n'}"
  transformed="${transformed//|/$'\n'}"

  local segment
  while IFS= read -r segment; do
    [[ -z "$segment" ]] && continue
    check_segment "$segment"
  done <<< "$transformed"
}

# Checks one chain segment: quoted spans (a commit message, a grep
# pattern, a gh comment body) are stripped out first, so a `git ...`
# phrase embedded inside someone else's quoted string argument (e.g. `git
# commit -m "cleanup: git reset --hard was too aggressive"`) isn't
# mistaken for an actual git invocation -- only text outside quotes is
# tested against the blocked shapes. Substitutions/nested shells are
# checked separately, on the original unstripped segment, since those need
# real quotes to find bash -c '...' and friends. Whatever is found inside
# a substitution or nested shell is fed back through check_command, so a
# nested shell containing its own chain or substitution is still caught.
#
# Quote-stripping is a pure bash regex loop (BASH_REMATCH), not a
# subprocess -- this used to shell out to `sed` twice per call, which (like
# the awk call in check_command) forked once per chain segment/
# substitution and was part of the same Finding 2 timeout/fail-open risk.
check_segment() {
  local segment="$1"

  local dq='"' sq="'"
  local quote_re="${dq}[^${dq}]*${dq}|${sq}[^${sq}]*${sq}"
  local stripped="" remainder="$segment" whole
  while [[ "$remainder" =~ $quote_re ]]; do
    whole="${BASH_REMATCH[0]}"
    stripped+="${remainder%%"$whole"*}"
    remainder="${remainder#*"$whole"}"
  done
  stripped+="$remainder"

  if is_blocked_git_segment "$stripped"; then
    deny
  fi

  # $(...), tolerating one level of nested parens (full paren balancing
  # isn't practical with plain bash/POSIX-ish regex -- see README).
  # NOTE: BASH_REMATCH is a global array that the recursive check_command
  # call below will overwrite, so each matched value must be copied into a
  # local variable *before* recursing -- otherwise the post-recursion
  # "advance past this match" step would read whatever check_command left
  # behind instead of the actual match, and the loop would never shrink
  # `remaining` (infinite loop on any input containing a substitution).
  local dollar_paren_re='\$\(([^()]*(\([^()]*\)[^()]*)*)\)'
  local remaining="$segment" inner
  while [[ "$remaining" =~ $dollar_paren_re ]]; do
    whole="${BASH_REMATCH[0]}"
    inner="${BASH_REMATCH[1]}"
    remaining="${remaining#*"$whole"}"
    check_command "$inner"
  done

  # `...` command substitution.
  local backtick_re='`([^`]*)`'
  remaining="$segment"
  while [[ "$remaining" =~ $backtick_re ]]; do
    whole="${BASH_REMATCH[0]}"
    inner="${BASH_REMATCH[1]}"
    remaining="${remaining#*"$whole"}"
    check_command "$inner"
  done

  # bash -c "..." / sh -c '...'. `bash`/`sh` must be its own word (a
  # preceding start-of-string or whitespace), so `mybash -c` or `flash -c`
  # don't match. The two quote alternatives are matched separately so an
  # opening and closing quote must be the same character -- no mismatched
  # "..' pairs are accepted as a valid nested-shell invocation.
  local nested_shell_re='(^|[[:space:]])(bash|sh)[[:space:]]+-c[[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"')'
  remaining="$segment"
  while [[ "$remaining" =~ $nested_shell_re ]]; do
    whole="${BASH_REMATCH[0]}"
    local quoted="${BASH_REMATCH[3]}"
    remaining="${remaining#*"$whole"}"
    check_command "${quoted:1:-1}"
  done
}

# Wraps the actual hook entry point so this file can be safely `source`d
# (e.g. by tests that want to call deny() or another function in isolation)
# without also running the whole stdin-reading hook flow -- see the
# BASH_SOURCE/$0 guard at the bottom of this file.
main() {
  local input
  input=$(cat)

  local command extract_status
  command=$(extract_command "$input")
  extract_status=$?

  if (( extract_status == 3 )); then
    deny "git-guardrails couldn't verify this command because no working python3 interpreter could be resolved (neither /usr/bin/python3 nor a python3 on PATH ran successfully). Denying to fail closed -- see docs/adr/adr-010-python3-for-json-extraction.md."
  elif (( extract_status == 2 )); then
    deny "git-guardrails couldn't verify this command because its JSON input could not be parsed. Denying to fail closed."
  elif (( extract_status == 4 )); then
    deny "git-guardrails couldn't verify this command because the python3 interpreter did not behave as expected (possible interpreter tampering or substitution). Denying to fail closed."
  fi

  if command_too_complex "$command"; then
    deny "git-guardrails couldn't verify this command because it is too large or complex to check within the hook's time budget (over ${COMPLEXITY_MAX_LENGTH} bytes, or more than ${COMPLEXITY_MAX_OPERATORS} chain/substitution operators). Denying to fail closed."
  fi

  check_command "$command"

  exit 0
}

# Only run the hook when this file is executed directly (the real
# PreToolUse contract: `bash reject-destructive-git.sh` with JSON on
# stdin), not when it's `source`d -- e.g. by a bats test that wants to
# call a function like deny() directly without also consuming stdin and
# running the full flow.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
