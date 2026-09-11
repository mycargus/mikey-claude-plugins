#!/usr/bin/env bash
# Blocks destructive git commands before they run.
#
# NOTE: Uses pure bash (no jq) because hook subprocesses may not have
# asdf/mise shims in PATH. See mikey-claude-plugins docs/adr/adr-008.

INPUT=$(cat)

# Extract tool_input.command from the hook's JSON stdin using bash pattern
# matching (avoids a jq dependency). Good enough for substring matching
# even if it truncates early on an embedded quote.
COMMAND="${INPUT##*\"command\":\"}"
COMMAND="${COMMAND%%\"*}"

if echo "$COMMAND" | grep -qE '(git[[:space:]]+push[[:space:]]+.*--force|git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+branch[[:space:]]+-D|git[[:space:]]+clean[[:space:]]+-f|git[[:space:]]+checkout[[:space:]]+\.)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Destructive git command blocked by git-guardrails. If this is intentional, run it yourself from your terminal."}}'
  exit 0
fi

exit 0
