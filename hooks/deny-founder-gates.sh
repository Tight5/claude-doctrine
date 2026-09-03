#!/bin/bash
# PreToolUse hook. Enforces the founder hard line: no commit or push to main
# without his approval at the moment it happens. Wired to the Bash tool and to
# the GitHub file-write tools (push_files, create_or_update_file, delete_file).
# Work that does not target main is not blocked by design; a form the wall
# cannot read is denied with a reason. Fires inside subagents too.
# Must stay instant: a hook that hits its timeout renders no decision, which
# would fail open. A parse failure fails closed: the hook denies and says why;
# it never allows in silence.
set -u
input="$(cat)"

deny() { echo "DENIED by founder doctrine: $1" >&2; exit 2; }
GUIDE="Main takes founder approval at the moment it happens: a pull request he tells you to merge, or a command he runs himself. Work on a feature branch and open a PR."
SPLIT="If this command leaves main first, run that switch as its own call: the wall reads the real branch at each call and nothing inside one command can argue it off main."

# Fields: jq when present, else a sed extraction of the JSON string fields.
if command -v jq >/dev/null 2>&1; then
  field() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }
  tool="$(field '.tool_name')"; cmd="$(field '.tool_input.command')"
  cwd="$(field '.cwd')";        br="$(field '.tool_input.branch')"
else
  field() { printf '%s' "$input" | sed -nE "s/.*\"$1\":[[:space:]]*\"((\\\\.|[^\"\\\\])*)\".*/\\1/p" | head -1 | sed -e 's/\\"/"/g' -e 's/\\n/ /g' -e 's/\\\\/\\/g'; }
  tool="$(field tool_name)"; cmd="$(field command)"; cwd="$(field cwd)"; br="$(field branch)"
fi
[ -z "$input" ] && deny "this hook received no input, so it cannot check the call (fail closed)."

# GitHub file-write tools: the branch named in the call decides.
case "$tool" in
  mcp__github__push_files|mcp__github__create_or_update_file|mcp__github__delete_file)
    case "$br" in
      "") deny "$tool names no branch, so the target cannot be checked (fail closed). $GUIDE" ;;
      main|refs/heads/main) deny "$tool targeting main. $GUIDE" ;;
    esac
    exit 0 ;;
  Bash|"") ;;
  *) deny "this wall is wired to a tool it does not know ($tool): the settings matcher and this script disagree (fail closed)." ;;
esac

# Bash: the command decides.
[ -z "$cmd" ] && deny "this hook could not read the command from its input (fail closed)."
case "$cmd" in *git*) ;; *) exit 0 ;; esac

# Walk the command one shell segment at a time (split on newlines ; && || and |),
# tracking a leading "cd <dir>" so a later git segment is checked in that repo.
#
# The branch rule is deliberately one-way. The live branch is read before the
# command runs, so a "git checkout main" or "git switch main" earlier in the
# same command counts as main for the later segments in that repository. But
# nothing in a command can argue the wall OFF main: a switch away from main is
# honored only by the next tool call, which reads the real branch. That means a
# checkout that merely looks like a switch (a branch name followed by a path,
# "-p", a tree-ish, a failed switch before ";") can never hide main. The cost is
# a safe-direction deny when one command both leaves main and commits; the deny
# says to split it.
dir="$cwd"; on_main_dir=""
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
  printf '%s' "$norm" | grep -qE 'git[[:space:]]+push([[:space:]][^;&|]*)?[[:space:]]--(all|mirror)([[:space:]]|$)' && deny "push --all or --mirror reaches main. $GUIDE"

  # Implicit: a commit, or a bare push, while HEAD is main in the repository the
  # segment acts on: the git -C <dir> if given, else the tracked directory.
  repo="$(printf '%s' "$seg" | sed -nE 's/.*git[[:space:]]+(-[^C][^[:space:]]*[[:space:]]+([^-][^[:space:]]*[[:space:]]+)?)*-C[[:space:]]*([^[:space:]]+).*/\3/p')"
  repo="${repo//\"/}"; repo="${repo//\'/}"; repo="${repo/#\~/$HOME}"
  case "$repo" in "") repo="$dir" ;; /*) ;; *) repo="$dir/$repo" ;; esac
  branch=""
  [ -n "$repo" ] && [ -d "$repo" ] && branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ -n "$on_main_dir" ] && [ "$repo" = "$on_main_dir" ] && branch=main
  if [ "$branch" = "main" ]; then
    printf '%s' "$norm" | grep -qE 'git[[:space:]]+commit([[:space:]]|$)' && deny "commit on main. $GUIDE $SPLIT"
    printf '%s' "$norm" | grep -qE 'git[[:space:]]+push([[:space:]]|$)' && deny "push from main. $GUIDE $SPLIT"
    printf '%s' "$norm" | grep -qE 'git[[:space:]]+(merge|cherry-pick|revert|rebase|am)([[:space:]]|$)' && deny "merge, cherry-pick, revert, rebase or am on main is a commit on main. $GUIDE $SPLIT"
  fi

  # Raise only: "checkout main", "switch main", or a return to the previous
  # branch ("-", "@{-1}"), which may be main, with any flags before the target.
  if printf '%s' "$norm" | grep -qE 'git[[:space:]]+(checkout|switch)([[:space:]]+-[^[:space:]]*)*[[:space:]]+(main|-|@\{-1\})([[:space:]]|$)'; then
    on_main_dir="$repo"
  fi
done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||;|\|)/\n/g')
exit 0
