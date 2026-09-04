#!/bin/bash
# PreToolUse hook. Enforces the founder hard line: no commit or push to main
# without his approval at the moment it happens. Wired to the Bash tool and to
# the GitHub file-write tools (push_files, create_or_update_file, delete_file).
# On main it also denies a merge, rebase, cherry-pick, revert, am, and a pull
# that is not --ff-only, since each is a commit on main. Work that does not
# target main is not blocked by design; a form the wall cannot read is denied
# with a reason. Fires inside subagents too.
# Must stay instant: a hook that hits its timeout renders no decision, which
# would fail open. A parse failure fails closed: the hook denies and says why;
# it never allows in silence. Needs bash, git, sed and grep; jq is used when
# present.
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
# Each segment is read as shell TOKENS, quotes honored and nothing executed, so
# a quoted value with a space ("Claude Code") is one token, the git verb is
# found by position rather than by pattern, and a segment whose quoting cannot
# be parsed fails closed if it mentions git.
#
# Directory tracking fails closed. A "cd", "pushd" or "popd" whose target the
# wall cannot resolve at hook time (a $variable, a $(subshell), a backtick, "-",
# or a path that does not exist yet), a "cd" inside a nested shell or eval, a
# working directory the input did not carry, or a directory that is not a git
# repository, denies a later commit, push or merge-family call in that chain.
# A git write inside a nested shell string is denied outright: the wall cannot
# read it. Read-only git after any of these is not affected.
#
# The branch rule is one-way. The live branch is read before the command runs,
# so a "git checkout main", "git switch main", a return to the previous branch,
# or a HEAD moved onto main earlier in the same command counts as main for the
# later segments in that repository, keyed on the repository's real top-level
# path. Nothing inside a command can argue the wall OFF main: a switch away is
# honored only by the next tool call, which reads the real branch. So a checkout
# that merely looks like a switch can never hide main. The cost is a
# safe-direction deny when one command both leaves main and commits.
# Shell-style tokens in pure bash: single and double quotes and backslashes are
# honored, nothing is expanded or executed. Returns 1 on an unbalanced quote.
tokenize() {
  local s="$1"; local n=${#s}; local i c q="" cur="" have=0; T=()
  for ((i=0; i<n; i++)); do
    c="${s:i:1}"
    if [ -n "$q" ]; then
      if [ "$c" = "$q" ]; then q=""
      elif [ "$q" = '"' ] && [ "$c" = '\' ]; then i=$((i+1)); cur+="${s:i:1}"
      else cur+="$c"; fi
    else
      case "$c" in
        "'"|'"') q="$c"; have=1 ;;
        '\') i=$((i+1)); cur+="${s:i:1}"; have=1 ;;
        ' '|$'\t') if [ "$have" = 1 ]; then T+=("$cur"); cur=""; have=0; fi ;;
        *) cur+="$c"; have=1 ;;
      esac
    fi
  done
  [ -n "$q" ] && return 1
  [ "$have" = 1 ] && T+=("$cur")
  return 0
}

dir="$cwd"; dir_unknown=0; [ -z "$dir" ] && dir_unknown=1
on_main_tops="|"
while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:](]+//')"
  [ -z "$seg" ] && continue
  if ! tokenize "$seg"; then
    case "$seg" in *git*) deny "this command's quoting cannot be parsed, so its git call cannot be checked (fail closed). $GUIDE" ;; esac
    dir=""; dir_unknown=1; continue
  fi
  [ ${#T[@]} -eq 0 ] && continue
  first="${T[0]}"

  case "$first" in
    cd|pushd|popd)
      tgt="${T[1]:-}"; [ "$first" = popd ] && tgt="-"
      case "$tgt" in
        *'$'*|*'`'*|*'('*|-|--) dir=""; dir_unknown=1 ;;
        ""|"~") dir="$HOME"; dir_unknown=0 ;;
        *) tgt="${tgt/#\~\//$HOME/}"
           case "$tgt" in /*) dir="$tgt" ;; *) if [ "$dir_unknown" = 1 ]; then dir=""; else dir="$dir/$tgt"; fi ;; esac
           if [ -n "$dir" ] && [ -d "$dir" ]; then dir_unknown=0; else dir=""; dir_unknown=1; fi ;;
      esac
      continue ;;
    bash|sh|zsh|dash|eval)
      nested=0
      if [ "$first" = eval ]; then nested=1; else for t in "${T[@]:1}"; do [[ "$t" =~ ^-[a-zA-Z]*c ]] && nested=1; done; fi
      if [ "$nested" = 1 ]; then
        printf '%s' "$seg" | grep -qE '(^|[^[:alnum:]_])(cd|pushd|popd)([^[:alnum:]_]|$)' && { dir=""; dir_unknown=1; }
        if printf '%s' "$seg" | grep -qE '(^|[^[:alnum:]_/])git([^[:alnum:]_]|$)' && printf '%s' "$seg" | grep -qE '(^|[^[:alnum:]_-])(commit|push|merge|cherry-pick|revert|rebase|am|pull)([^[:alnum:]_-]|$)'; then
          deny "a git write inside a nested shell ($first) cannot be checked (fail closed). Run the git call directly. $GUIDE"
        fi
      fi
      continue ;;
  esac

  # The git token: exactly "git", or a path ending in /git. Anything before it
  # that looks like VAR=value is an environment prefix.
  gi=-1; for k in "${!T[@]}"; do t="${T[$k]}"; if [ "${t##*/}" = git ]; then gi=$k; break; fi; done
  [ $gi -lt 0 ] && continue
  envwt=""; envgd=""
  if [ $gi -gt 0 ]; then for t in "${T[@]:0:$gi}"; do case "$t" in GIT_WORK_TREE=*) envwt="${t#GIT_WORK_TREE=}" ;; GIT_DIR=*) envgd="${t#GIT_DIR=}" ;; esac; done; fi

  # Walk git's global options; the first token that is not an option is the
  # subcommand. Options that take a value consume the next token.
  i=$((gi+1)); repo_opt=""; gd_opt=""
  while [ $i -lt ${#T[@]} ]; do
    t="${T[$i]}"
    case "$t" in
      -C) repo_opt="${T[$((i+1))]:-}"; i=$((i+2)) ;;
      -C?*) repo_opt="${t#-C}"; i=$((i+1)) ;;
      --work-tree=*) repo_opt="${t#--work-tree=}"; i=$((i+1)) ;;
      --work-tree) repo_opt="${T[$((i+1))]:-}"; i=$((i+2)) ;;
      --git-dir=*) gd_opt="${t#--git-dir=}"; i=$((i+1)) ;;
      --git-dir) gd_opt="${T[$((i+1))]:-}"; i=$((i+2)) ;;
      -c|--namespace|--super-prefix|--config-env|--attr-source|--list-cmds) i=$((i+2)) ;;
      --) i=$((i+1)); break ;;
      -*) i=$((i+1)) ;;
      *) break ;;
    esac
  done
  sub="${T[$i]:-}"; args=()
  [ $((i+1)) -lt ${#T[@]} ] && args=("${T[@]:$((i+1))}")
  if [ "$sub" = subtree ] && [ ${#args[@]} -gt 0 ]; then
    case "${args[0]}" in push|pull) sub="${args[0]}"; args=("${args[@]:1}") ;; esac
  fi

  # Explicit, from any branch: a push whose destination is main in any refspec
  # form, push --all or --mirror, and main moved by branch -f/-M/-m or update-ref.
  if [ "$sub" = push ]; then
    for a in "${args[@]}"; do
      case "$a" in --all|--mirror) deny "push --all or --mirror reaches main. $GUIDE" ;; esac
      [[ "$a" =~ ^:(refs/heads/)?main$ ]] && deny "deleting main. $GUIDE"
      [[ "$a" =~ ^\+?([^:]+:)?(refs/heads/)?main$ ]] && deny "push targeting main. $GUIDE"
    done
  fi
  if [ "$sub" = branch ]; then
    mv=0; for a in "${args[@]}"; do case "$a" in -f|--force|-M|-m) mv=1 ;; esac; done
    if [ "$mv" = 1 ]; then for a in "${args[@]}"; do [ "$a" = main ] && deny "moving main with git branch. $GUIDE"; done; fi
  fi
  if [ "$sub" = update-ref ]; then for a in "${args[@]}"; do [ "$a" = refs/heads/main ] && deny "moving main with git update-ref. $GUIDE"; done; fi

  # The repository this segment acts on: -C, else --work-tree, else --git-dir,
  # else the environment prefixes, else the tracked directory. Then its real
  # top-level path.
  repo="$repo_opt"
  [ -z "$repo" ] && [ -n "$gd_opt" ] && repo="$(printf '%s' "$gd_opt" | sed -E 's#/?\.git/?$##')"
  [ -z "$repo" ] && repo="$envwt"
  [ -z "$repo" ] && [ -n "$envgd" ] && repo="$(printf '%s' "$envgd" | sed -E 's#/?\.git/?$##')"
  repo="${repo/#\~\//$HOME/}"
  case "$repo" in
    "") repo="$dir" ;;
    /*) ;;
    *'$'*|*'`'*|*'('*) repo="" ;;
    *) if [ "$dir_unknown" = 1 ]; then repo=""; else repo="$dir/$repo"; fi ;;
  esac
  guarded=0
  case "$sub" in
    commit|push|merge|cherry-pick|revert|rebase|am) guarded=1 ;;
    pull) guarded=1; for a in "${args[@]}"; do [ "$a" = --ff-only ] && guarded=0; done ;;
  esac
  top=""
  [ -n "$repo" ] && [ -d "$repo" ] && top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$top" ]; then
    [ "$guarded" = 1 ] && deny "the repository this command acts on cannot be identified at hook time (the working directory is missing, was changed to a target the wall cannot resolve, or is not a git repository), so its branch cannot be checked (fail closed). $GUIDE $SPLIT"
    continue
  fi

  # Implicit: a write while HEAD is main. symbolic-ref reads the branch even
  # before the first commit (unborn HEAD).
  branch="$(git -C "$top" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  case "$on_main_tops" in *"|$top|"*) branch=main ;; esac
  if [ "$branch" = main ]; then
    case "$sub" in
      commit) deny "commit on main. $GUIDE $SPLIT" ;;
      push) deny "push from main. $GUIDE $SPLIT" ;;
      merge|cherry-pick|revert|rebase|am) deny "$sub on main is a commit on main. $GUIDE $SPLIT" ;;
      pull) [ "$guarded" = 1 ] && deny "pull on main can create a merge commit or rewrite main; use git pull --ff-only, which cannot. $GUIDE" ;;
    esac
  fi

  # Raise only: "checkout main", "switch main", a return to the previous branch
  # ("-", "@{-1}"), or HEAD moved onto main by symbolic-ref.
  raise=0
  case "$sub" in
    checkout|switch) for a in "${args[@]}"; do case "$a" in main|-|'@{-1}') raise=1 ;; esac; done ;;
    symbolic-ref) [ "${args[0]:-}" = HEAD ] && [ "${args[1]:-}" = refs/heads/main ] && raise=1 ;;
  esac
  [ "$raise" = 1 ] && on_main_tops="$on_main_tops$top|"
done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||;|\|)/\n/g')
exit 0
