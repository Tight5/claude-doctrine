#!/bin/bash
# PreToolUse hook, matcher "Bash". Enforces the founder hard line: no commit or
# push to main without his approval at the moment it happens. A feature branch is
# never blocked. Fires inside subagents too. Must stay instant: a hook that hits
# its timeout renders no decision, which would fail open.
set -u
input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0
case "$cmd" in *git*) ;; *) exit 0 ;; esac

deny() {
  echo "DENIED by founder doctrine: $1. Main takes founder approval at the moment it happens. Work on a feature branch and open a PR." >&2
  exit 2
}

# Explicit: any push whose destination is main, in any refspec form.
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push[^;&|]*[[:space:]]([^[:space:]:]+:)?(refs/heads/)?main([[:space:]]|$)'; then
  deny "push targeting main"
fi
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push[^;&|]*[[:space:]]:(refs/heads/)?main([[:space:]]|$)'; then
  deny "deleting main"
fi

# Implicit: a commit, or a bare push, while HEAD is main.
branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi
if [ "$branch" = "main" ]; then
  printf '%s' "$cmd" | grep -qE 'git[[:space:]]+commit([[:space:]]|$)' && deny "commit on main"
  printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push([[:space:]]|$)' && deny "push from main"
fi
exit 0
