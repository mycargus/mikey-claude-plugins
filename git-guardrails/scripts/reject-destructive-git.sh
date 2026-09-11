#!/usr/bin/env bash
# Blocks destructive git commands before they run.
#
# NOTE: Uses pure bash (no jq) because hook subprocesses may not have
# asdf/mise shims in PATH. See mikey-claude-plugins docs/adr/adr-008.
#
# This is regex/string-based splitting, not a real shell parser. It does
# not defend against arbitrarily nested quoting, $IFS tricks, base64 or
# other encoded payloads, string concatenation, aliases, or eval/xargs
# indirection -- see README Limitations.

INPUT=$(cat)

# Extract tool_input.command from the hook's JSON stdin by hand (avoids a
# jq dependency). Scans char-by-char from just after `"command":"` up to
# the closing, unescaped quote, unescaping \" \\ \n \t \/ along the way.
# Unlike a plain substring cut, this does not stop early just because the
# command contains an escaped quote (e.g. `bash -c "..."`, which Claude
# Code encodes on the wire as `bash -c \"...\"`).
extract_command() {
  local input="$1"
  local marker='"command":"'
  local prefix="${input%%"$marker"*}"

  # No command field present at all -- nothing to check.
  if [[ "$prefix" == "$input" ]]; then
    printf ''
    return
  fi

  local rest="${input:$(( ${#prefix} + ${#marker} ))}"
  local out=""
  local i=0
  local len="${#rest}"
  local ch next

  while (( i < len )); do
    ch="${rest:i:1}"
    if [[ "$ch" == '\' ]]; then
      next="${rest:i+1:1}"
      case "$next" in
        '"') out+='"' ;;
        '\') out+='\' ;;
        n) out+=$'\n' ;;
        t) out+=$'\t' ;;
        /) out+='/' ;;
        *) out+="$next" ;;
      esac
      i=$((i + 2))
      continue
    elif [[ "$ch" == '"' ]]; then
      break
    fi
    out+="$ch"
    i=$((i + 1))
  done

  printf '%s' "$out"
}

deny() {
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Destructive git command blocked by git-guardrails. If this is intentional, run it yourself from your terminal."}}'
  exit 0
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
check_command() {
  local cmd="$1"

  [[ -z "$cmd" ]] && return

  local segment
  while IFS= read -r segment; do
    [[ -z "$segment" ]] && continue
    check_segment "$segment"
  done < <(awk '{gsub(/;|&&|\|\||\|/, "\n"); print}' <<< "$cmd")
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
check_segment() {
  local segment="$1"

  local stripped
  stripped=$(sed -e 's/"[^"]*"//g' -e "s/'[^']*'//g" <<< "$segment")
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
  local remaining="$segment" whole inner
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

COMMAND=$(extract_command "$INPUT")

check_command "$COMMAND"

exit 0
