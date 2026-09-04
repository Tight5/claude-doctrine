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
# it never allows in silence. Needs bash, git, sed and grep; jq when present.
set -u

deny() { echo "DENIED by founder doctrine: $1" >&2; exit 2; }
GUIDE="Main takes founder approval at the moment it happens: a pull request he tells you to merge, or a command he runs himself. Work on a feature branch and open a PR."
SPLIT="If this command leaves main first, or changes directory first, run that step as its own call: the wall reads the real branch and the real directory at each call, and nothing inside one command can argue it off main."
QUOTE="Pass a message with -F <file>, or run the git call as its own command, so the wall can read it."

input="$(cat)"

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

[ -z "$cmd" ] && deny "this hook could not read the command from its input (fail closed)."
case "$cmd" in *git*) ;; *) exit 0 ;; esac

# The reader walks the command one character at a time, so its cost rises faster
# than the length. A hook that hits its timeout renders no decision and the call
# proceeds, which is the one failure that fails OPEN, so a command too long to
# read inside the budget is denied instead of ground through. 64KB reads in
# about seven seconds here; a git command that size is not a real one.
if [ ${#cmd} -gt 65536 ]; then
  deny "this command is ${#cmd} characters, too long for the wall to read inside its time budget, so its git call cannot be checked (fail closed). Split it, or pass the large part with -F <file>."
fi

# Read the WHOLE command as shell tokens in pure bash: quotes and backslashes
# honored, nothing expanded or executed. Segment separators (; & | newline
# ( ) and an unquoted # comment) are emitted as SEP, so a separator inside a
# quoted commit message is just text.
#
# A heredoc body is DATA, not command structure: the shell hands it to the
# command and never parses it. So "<<EOF", "<<-EOF", "<<'EOF'" and the quoted
# forms park their delimiter, and at the next real newline the body is skipped
# whole, up to and including its terminator line. Without that, an apostrophe
# in a heredoc body ("the founder's word", any prose, most Python) reads as an
# unbalanced quote and fails the whole command closed. A herestring, "<<<", is
# not a heredoc and is left alone.
#
# Returns 1 on unbalanced quoting.
SEP=$'\001'
tokenize_all() {
  local s="$1"; local n=${#s}; local i=0; local c q="" cur="" have=0
  local hd=() j k ls line ch dq d
  TOK=()
  while [ $i -lt $n ]; do
    c="${s:i:1}"
    if [ "$q" = "'" ]; then
      if [ "$c" = "'" ]; then q=""; else cur+="$c"; fi
    elif [ "$q" = '"' ]; then
      if [ "$c" = '"' ]; then q=""
      elif [ "$c" = '\' ]; then i=$((i+1)); cur+="${s:i:1}"
      else cur+="$c"; fi
    else
      case "$c" in
        "'"|'"') q="$c"; have=1 ;;
        '\') i=$((i+1)); c="${s:i:1}"; if [ "$c" != $'\n' ]; then cur+="$c"; have=1; fi ;;
        '<')
          if [ "${s:$((i+1)):1}" = '<' ] && [ "${s:$((i+2)):1}" = '<' ]; then
            # A herestring. Consume all three so the second "<" is never read
            # as a heredoc opener and its word never parked as a delimiter.
            cur+='<<<'; i=$((i+2)); have=1
          elif [ "${s:$((i+1)):1}" = '<' ]; then
            j=$((i+2))
            [ "${s:j:1}" = '-' ] && j=$((j+1))
            while [ "${s:j:1}" = ' ' ] || [ "${s:j:1}" = $'\t' ]; do j=$((j+1)); done
            dq=""
            case "${s:j:1}" in "'"|'"') dq="${s:j:1}"; j=$((j+1)) ;; esac
            d=""
            while [ $j -lt $n ]; do
              ch="${s:j:1}"
              if [ -n "$dq" ]; then
                [ "$ch" = "$dq" ] && { j=$((j+1)); break; }
                d+="$ch"
              else
                # Bash ends the delimiter word at a redirect too, and a
                # backslash quotes the next character rather than joining it.
                case "$ch" in ' '|$'\t'|$'\n'|';'|'&'|'|'|'('|')'|'<'|'>') break ;; esac
                if [ "$ch" = '\' ]; then
                  j=$((j+1)); ch="${s:j:1}"
                  [ -z "$ch" ] && break
                fi
                d+="$ch"
              fi
              j=$((j+1))
            done
            [ -n "$d" ] && hd+=("$d")
            if [ "$have" = 1 ]; then TOK+=("$cur"); cur=""; have=0; fi
            i=$((j-1))
          else
            cur+="$c"; have=1
          fi ;;
        ' '|$'\t') if [ "$have" = 1 ]; then TOK+=("$cur"); cur=""; have=0; fi ;;
        ';'|'&'|'|'|$'\n'|'('|')')
          if [ "$have" = 1 ]; then TOK+=("$cur"); cur=""; have=0; fi
          TOK+=("$SEP")
          if [ "$c" = $'\n' ] && [ ${#hd[@]} -gt 0 ]; then
            k=$((i+1))
            for d in "${hd[@]}"; do
              while [ $k -lt $n ]; do
                ls=$k
                while [ $k -lt $n ] && [ "${s:k:1}" != $'\n' ]; do k=$((k+1)); done
                line="${s:ls:$((k-ls))}"
                line="${line#"${line%%[![:space:]]*}"}"
                line="${line%"${line##*[![:space:]]}"}"
                k=$((k+1))
                [ "$line" = "$d" ] && break
              done
            done
            hd=()
            i=$((k-1))
          fi ;;
        '#')
          if [ "$have" = 1 ]; then cur+="$c"
          else
            while [ $i -lt $n ] && [ "${s:i:1}" != $'\n' ]; do i=$((i+1)); done
            i=$((i-1))
          fi ;;
        *) cur+="$c"; have=1 ;;
      esac
    fi
    i=$((i+1))
  done
  [ -n "$q" ] && return 1
  if [ "$have" = 1 ]; then TOK+=("$cur"); fi
  return 0
}

if ! tokenize_all "$cmd"; then
  deny "this command's quoting is unbalanced, so its git call cannot be read (fail closed). $QUOTE"
fi

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
dir="$cwd"; dir_unknown=0; [ -z "$dir" ] && dir_unknown=1
on_main_tops="|"

process_segment() {
  [ ${#T[@]} -eq 0 ] && return 0
  local joined="${T[*]}" t k i

  # A nested shell or eval anywhere in the segment, named bare or by path and
  # reached behind sudo, env, timeout, nohup or nice.
  local nested=0 sh_seen=0
  for t in "${T[@]}"; do
    case "${t##*/}" in
      bash|sh|zsh|dash|ksh) sh_seen=1 ;;
      eval) nested=1 ;;
      -*c*) [ "$sh_seen" = 1 ] && [ "${t:0:1}" = "-" ] && [ "${t:0:2}" != "--" ] && nested=1 ;;
    esac
  done
  if [ "$nested" = 1 ]; then
    printf '%s' "$joined" | grep -qE '(^|[^[:alnum:]_])(cd|pushd|popd)([^[:alnum:]_]|$)' && { dir=""; dir_unknown=1; }
    if printf '%s' "$joined" | grep -qE '(^|[^[:alnum:]_/])git([^[:alnum:]_]|$)' \
       && printf '%s' "$joined" | grep -qE '(^|[^[:alnum:]_-])(commit|push|merge|cherry-pick|revert|rebase|am|pull)([^[:alnum:]_-]|$)'; then
      deny "a git write inside a nested shell cannot be read by the wall (fail closed). Run the git call directly. $GUIDE"
    fi
    return 0
  fi

  case "${T[0]}" in
    cd|pushd|popd)
      local tgt="${T[1]:-}"; [ "${T[0]}" = popd ] && tgt="-"
      case "$tgt" in
        *'$'*|*'`'*|-|--) dir=""; dir_unknown=1 ;;
        ""|"~") dir="$HOME"; dir_unknown=0 ;;
        *) tgt="${tgt/#\~\//$HOME/}"
           case "$tgt" in /*) dir="$tgt" ;; *) if [ "$dir_unknown" = 1 ]; then dir=""; else dir="$dir/$tgt"; fi ;; esac
           if [ -n "$dir" ] && [ -d "$dir" ]; then dir_unknown=0; else dir=""; dir_unknown=1; fi ;;
      esac
      return 0 ;;
  esac

  # The git token: exactly "git", or a path ending in /git. Tokens before it of
  # the form VAR=value are environment prefixes.
  local gi=-1
  for k in "${!T[@]}"; do [ "${T[$k]##*/}" = git ] && { gi=$k; break; }; done
  [ $gi -lt 0 ] && return 0
  local envwt="" envgd=""
  if [ $gi -gt 0 ]; then
    for t in "${T[@]:0:$gi}"; do
      case "$t" in GIT_WORK_TREE=*) envwt="${t#GIT_WORK_TREE=}" ;; GIT_DIR=*) envgd="${t#GIT_DIR=}" ;; esac
    done
  fi

  # Walk git's global options; the first non-option token is the subcommand.
  i=$((gi+1)); local repo_opt="" gd_opt=""
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
  local sub="${T[$i]:-}"; local args=()
  [ $((i+1)) -lt ${#T[@]} ] && args=("${T[@]:$((i+1))}")
  if [ "$sub" = subtree ] && [ ${#args[@]} -gt 0 ]; then
    case "${args[0]}" in push|pull) sub="${args[0]}"; args=("${args[@]:1}") ;; esac
  fi

  # Explicit, from any branch: a push whose destination is main in any refspec
  # form, push --all or --mirror, and main moved or deleted by branch or update-ref.
  local a
  if [ "$sub" = push ]; then
    for a in ${args[@]+"${args[@]}"}; do
      case "$a" in --all|--mirror) deny "push --all or --mirror reaches main. $GUIDE" ;; esac
      [[ "$a" =~ ^:(refs/heads/)?main$ ]] && deny "deleting main. $GUIDE"
      [[ "$a" =~ ^\+?([^:]+:)?(refs/heads/)?main$ ]] && deny "push targeting main. $GUIDE"
    done
  fi
  if [ "$sub" = branch ]; then
    local mv=0
    for a in ${args[@]+"${args[@]}"}; do case "$a" in -f|--force|-M|-m|-D|--delete) mv=1 ;; esac; done
    if [ "$mv" = 1 ]; then for a in ${args[@]+"${args[@]}"}; do [ "$a" = main ] && deny "moving or deleting main with git branch. $GUIDE"; done; fi
  fi
  if [ "$sub" = update-ref ]; then
    for a in ${args[@]+"${args[@]}"}; do [ "$a" = refs/heads/main ] && deny "moving main with git update-ref. $GUIDE"; done
  fi

  # The repository this segment acts on, then its real top-level path.
  local repo="$repo_opt"
  [ -z "$repo" ] && [ -n "$gd_opt" ] && repo="$(printf '%s' "$gd_opt" | sed -E 's#/?\.git/?$##')"
  [ -z "$repo" ] && repo="$envwt"
  [ -z "$repo" ] && [ -n "$envgd" ] && repo="$(printf '%s' "$envgd" | sed -E 's#/?\.git/?$##')"
  repo="${repo/#\~\//$HOME/}"
  case "$repo" in
    "") repo="$dir" ;;
    /*) ;;
    *'$'*|*'`'*) repo="" ;;
    *) if [ "$dir_unknown" = 1 ]; then repo=""; else repo="$dir/$repo"; fi ;;
  esac
  local guarded=0
  case "$sub" in
    commit|push|merge|cherry-pick|revert|rebase|am) guarded=1 ;;
    pull) guarded=1; for a in ${args[@]+"${args[@]}"}; do [ "$a" = --ff-only ] && guarded=0; done ;;
  esac
  local top=""
  [ -n "$repo" ] && [ -d "$repo" ] && top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$top" ]; then
    [ "$guarded" = 1 ] && deny "the repository this command acts on cannot be identified at hook time (the working directory is missing, was changed to a target the wall cannot resolve, or is not a git repository), so its branch cannot be checked (fail closed). $GUIDE $SPLIT"
    return 0
  fi

  # Implicit: a write while HEAD is main. symbolic-ref reads the branch even
  # before the first commit (unborn HEAD).
  local branch; branch="$(git -C "$top" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  case "$on_main_tops" in *"|$top|"*) branch=main ;; esac
  if [ "$branch" = main ]; then
    case "$sub" in
      commit) deny "commit on main. $GUIDE $SPLIT" ;;
      push) deny "push from main. $GUIDE $SPLIT" ;;
      merge|cherry-pick|revert|rebase|am) deny "$sub on main is a commit on main. $GUIDE $SPLIT" ;;
      pull) [ "$guarded" = 1 ] && deny "pull on main can create a merge commit or rewrite main; use git pull --ff-only, which cannot. $GUIDE" ;;
      update-ref) [ "${args[0]:-}" = HEAD ] && deny "update-ref HEAD on main moves main. $GUIDE" ;;
    esac
  fi

  # Raise only: a checkout or switch to main or to the previous branch, or HEAD
  # moved onto main by symbolic-ref.
  local raise=0
  case "$sub" in
    checkout|switch) for a in ${args[@]+"${args[@]}"}; do case "$a" in main|-|'@{-1}') raise=1 ;; esac; done ;;
    symbolic-ref) [ "${args[0]:-}" = HEAD ] && [ "${args[1]:-}" = refs/heads/main ] && raise=1 ;;
  esac
  [ "$raise" = 1 ] && on_main_tops="$on_main_tops$top|"
  return 0
}

T=()
n=${#TOK[@]}
for ((k=0; k<=n; k++)); do
  if [ $k -eq $n ] || [ "${TOK[$k]}" = "$SEP" ]; then
    process_segment
    T=()
  else
    T+=("${TOK[$k]}")
  fi
done
exit 0
