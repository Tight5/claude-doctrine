#!/bin/bash
# PreToolUse hook, matcher "Bash". Enforces the founder hard line: no commit or
# push to main without his approval at the moment it happens. Work that does not
# target main is never blocked. Fires inside subagents too. Must stay instant: a
# hook that hits its timeout renders no decision, which would fail open. A parse
# failure fails closed: the hook denies and says why; it never allows in silence.
set -u
input="$(cat)"

deny() { echo "DENIED by founder doctrine: $1" >&2; exit 2; }
GUIDE="Main takes founder approval at the moment it happens. Work on a feature branch and open a PR."

# The command and cwd: jq when present, else a sed extraction of the JSON fields.
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
else
  unesc() { sed -e 's/\\"/"/g' -e 's/\\n/ /g' -e 's/\\\\/\\/g'; }
  cmd="$(printf '%s' "$input" | sed -nE 's/.*"command":[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' | head -1 | unesc)"
  cwd="$(printf '%s' "$input" | sed -nE 's/.*"cwd":[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' | head -1 | unesc)"
fi
[ -z "$input" ] && deny "this hook received no input, so it cannot check the command (fail closed)."
[ -z "$cmd" ] && deny "this hook could not read the command from its input (fail closed)."
case "$cmd" in *git*) ;; *) exit 0 ;; esac

# Walk the command one shell segment at a time (split on newlines ; && || and |),
# tracking a leading "cd <dir>" so a later git segment is checked in that repo.
dir="$cwd"
while IFS= read -r seg; do
  cdto="$(printf '%s' "$seg" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^[:space:]]+).*/\1/p')"
  if [ -n "$cdto" ]; then
    cdto="${cdto//\"/}"; cdto="${cdto//\'/}"; cdto="${cdto/#\~/$HOME}"
    case "$cdto" in /*) dir="$cdto" ;; *) dir="$dir/$cdto" ;; esac
    continue
  fi
  case "$seg" in *git*) ;; *) continue ;; esac

  # Strip git's global options (-C <dir>, -c k=v, --git-dir=, --work-tree=,
  # --no-pager and kin) so the subcommand follows "git" directly, then drop quotes.
  norm="$(printf '%s' "$seg" | sed -E 's/git([[:space:]]+(-C[[:space:]]*[^[:space:]]+|-c[[:space:]]*[^[:space:]]+|--git-dir=[^[:space:]]+|--work-tree=[^[:space:]]+|--no-pager|--no-optional-locks|--paginate|-p))+[[:space:]]+/git /g')"
  norm="${norm//\"/}"; norm="${norm//\'/}"

  # Explicit: any push whose destination is main, in any refspec form.
  printf '%s' "$norm" | grep -qE 'git[[:space:]]+push[^;&|]*[[:space:]][+]?([^[:space:]:]+:)?(refs/heads/)?main([[:space:]]|$)' && deny "push targeting main. $GUIDE"
  printf '%s' "$norm" | grep -qE 'git[[:space:]]+push[^;&|]*[[:space:]]:(refs/heads/)?main([[:space:]]|$)' && deny "deleting main. $GUIDE"

  # Implicit: a commit, or a bare push, while HEAD is main in the repository the
  # segment acts on: the git -C <dir> if given, else the tracked directory.
  repo="$(printf '%s' "$seg" | sed -nE 's/.*git[[:space:]]+(-[^C][^[:space:]]*[[:space:]]+([^-][^[:space:]]*[[:space:]]+)?)*-C[[:space:]]*([^[:space:]]+).*/\3/p')"
  repo="${repo//\"/}"; repo="${repo//\'/}"; repo="${repo/#\~/$HOME}"
  case "$repo" in "") repo="$dir" ;; /*) ;; *) repo="$dir/$repo" ;; esac
  branch=""
  [ -n "$repo" ] && [ -d "$repo" ] && branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ "$branch" = "main" ]; then
    printf '%s' "$norm" | grep -qE 'git[[:space:]]+commit([[:space:]]|$)' && deny "commit on main. $GUIDE"
    printf '%s' "$norm" | grep -qE 'git[[:space:]]+push([[:space:]]|$)' && deny "push from main. $GUIDE"
  fi
done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||;|\|)/\n/g')
exit 0
