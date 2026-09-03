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
SPLIT="If this command leaves main first, or changes directory first, run that step as its own call: the wall reads the real branch and the real directory at each call, and nothing inside one command can argue it off main."

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

# Join backslash-newline continuations first, so "git \<newline>commit" is one
# segment and cannot split the verb away from "git".
cmd="$(printf '%s\n' "$cmd" | sed -E ':a;N;$!ba;s/\\\n[[:space:]]*/ /g')"

# Walk the command one shell segment at a time (split on newlines ; && || and |).
#
# Directory tracking fails closed. A "cd" or "pushd" whose target the wall
# cannot resolve at hook time (a $variable, a $(subshell), a backtick, "-", or a
# path that does not exist yet), a working directory the input did not carry,
# or a directory that is not a git repository, denies a later commit, push or
# merge-family call in that chain. Read-only git in the same command is not
# affected.
#
# The branch rule is one-way. The live branch is read before the command runs,
# so a "git checkout main", "git switch main", a return to the previous branch,
# or a HEAD moved onto main earlier in the same command counts as main for the
# later segments in that repository, keyed on the repository's real top-level
# path. Nothing inside a command can argue the wall OFF main: a switch away is
# honored only by the next tool call, which reads the real branch. So a checkout
# that merely looks like a switch can never hide main. The cost is a
# safe-direction deny when one command both leaves main and commits.
dir="$cwd"; dir_unknown=0; [ -z "$dir" ] && dir_unknown=1
on_main_tops="|"
while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:](]+//')"
  if printf '%s' "$seg" | grep -qE '^(cd|pushd|popd)([[:space:]]|$)'; then
    cdto="$(printf '%s' "$seg" | sed -nE 's/^(cd|pushd|popd)[[:space:]]*([^[:space:]]*).*/\2/p')"
    case "$seg" in popd*) cdto="-" ;; esac
    case "$cdto" in
      *'$'*|*'`'*|*'('*|-|--) dir=""; dir_unknown=1 ;;
      ""|"~") dir="$HOME"; dir_unknown=0 ;;
      *) cdto="${cdto//\"/}"; cdto="${cdto//\'/}"; cdto="${cdto/#\~/$HOME}"
         case "$cdto" in /*) dir="$cdto" ;; *) if [ "$dir_unknown" = 1 ]; then dir=""; else dir="$dir/$cdto"; fi ;; esac
         if [ -n "$dir" ] && [ -d "$dir" ]; then dir_unknown=0; else dir=""; dir_unknown=1; fi ;;
    esac
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

  # The repository this segment acts on: -C <dir>, else --work-tree, else
  # --git-dir, else the tracked directory. Then its real top-level path.
  repo="$(printf '%s' "$seg" | sed -nE 's/.*git[[:space:]]+(-[^C][^[:space:]]*[[:space:]]+([^-][^[:space:]]*[[:space:]]+)?)*-C[[:space:]]*([^[:space:]]+).*/\3/p')"
  [ -z "$repo" ] && repo="$(printf '%s' "$seg" | sed -nE 's/.*--work-tree[= ]([^[:space:]]+).*/\1/p')"
  [ -z "$repo" ] && repo="$(printf '%s' "$seg" | sed -nE 's/.*--git-dir[= ]([^[:space:]]+).*/\1/p' | sed -E 's#/?\.git/?$##')"
  repo="${repo//\"/}"; repo="${repo//\'/}"; repo="${repo/#\~/$HOME}"
  case "$repo" in
    "") repo="$dir" ;;
    /*) ;;
    *'$'*|*'`'*|*'('*) repo="" ;;
    *) if [ "$dir_unknown" = 1 ]; then repo=""; else repo="$dir/$repo"; fi ;;
  esac
  guarded=0
  printf '%s' "$norm" | grep -qE 'git[[:space:]]+(commit|push|merge|cherry-pick|revert|rebase|am)([[:space:]]|$)' && guarded=1
  top=""
  [ -n "$repo" ] && [ -d "$repo" ] && top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$top" ]; then
    [ "$guarded" = 1 ] && deny "the repository this command acts on cannot be identified at hook time (the working directory is missing, was changed to a target the wall cannot resolve, or is not a git repository), so its branch cannot be checked (fail closed). $GUIDE $SPLIT"
    continue
  fi

  # Implicit: a commit, a bare push, or a merge-family call while HEAD is main.
  # symbolic-ref reads the branch even before the first commit (unborn HEAD).
  branch="$(git -C "$top" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  case "$on_main_tops" in *"|$top|"*) branch=main ;; esac
  if [ "$branch" = "main" ]; then
    printf '%s' "$norm" | grep -qE 'git[[:space:]]+commit([[:space:]]|$)' && deny "commit on main. $GUIDE $SPLIT"
    printf '%s' "$norm" | grep -qE 'git[[:space:]]+push([[:space:]]|$)' && deny "push from main. $GUIDE $SPLIT"
    printf '%s' "$norm" | grep -qE 'git[[:space:]]+(merge|cherry-pick|revert|rebase|am)([[:space:]]|$)' && deny "merge, cherry-pick, revert, rebase or am on main is a commit on main. $GUIDE $SPLIT"
  fi

  # Raise only: "checkout main", "switch main", a return to the previous branch
  # ("-", "@{-1}"), or HEAD moved onto main by symbolic-ref or branch -m/-M.
  if printf '%s' "$norm" | grep -qE 'git[[:space:]]+(checkout|switch)([[:space:]]+-[^[:space:]]*)*[[:space:]]+(main|-|@\{-1\})([[:space:]]|$)' \
     || printf '%s' "$norm" | grep -qE 'git[[:space:]]+symbolic-ref[[:space:]]+HEAD[[:space:]]+refs/heads/main([[:space:]]|$)' \
     || printf '%s' "$norm" | grep -qE 'git[[:space:]]+branch[[:space:]]+-[mM][[:space:]]+([^[:space:]]+[[:space:]]+)?main([[:space:]]|$)'; then
    on_main_tops="$on_main_tops$top|"
  fi
done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||;|\|)/\n/g')
exit 0
