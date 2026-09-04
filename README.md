# claude-doctrine

The global operating rules for Clint Phillips's Claude Code sessions, and the two
hooks that enforce the rules prose alone cannot.

| File | What it is |
|---|---|
| `CLAUDE.md` | The doctrine. Loaded into every session as `~/.claude/CLAUDE.md`. |
| `settings.json` | Hooks block installed into `~/.claude/settings.json`. Wires each wall so a missing script denies the call instead of allowing it. |
| `hooks/deny-founder-gates.sh` | Denies, on `main`: a commit, a merge, cherry-pick, revert, rebase or applied patch, a pull that is not `--ff-only` (a pull that cannot fast-forward creates a merge commit), and a bare push; anywhere: a push whose refspec names `main`, `push --all`, `push --mirror`, `branch -f/-D main`, `update-ref refs/heads/main`, and the GitHub file-write tools when their branch is `main`. The branch rule is one-way: a `git checkout main` earlier in the same command counts as `main`, and nothing inside one command can argue the wall off `main`; a switch away is honored by the next call. Work that does not target `main` is not blocked by design; a form the wall cannot read is denied with a reason. Reads the whole command as shell tokens before splitting it into steps (quotes and backslashes honored, nothing executed, no dependency beyond bash), so a quoted value or a commit message containing a space, semicolon, pipe or heredoc is text, not structure. A nested shell (`bash -c`, `eval`, named by path or behind `sudo`, `env`, `timeout`, `nohup`) that carries a git write is denied; one that only builds or lints is not. Fails closed on a parse failure, unbalanced quoting around a git call, a missing script, a script that crashes, or a commit, push or merge whose repository it cannot identify at hook time (a `cd` to a `$variable` or `$(subshell)`, a directory that does not exist yet or is not a git repository, a `cd` inside `bash -c`, `sh -c` or `eval`, a working directory the input did not carry), and a git write inside such a nested shell string is denied outright. A new repository whose default branch is `main` has its first commit denied too: start the repository on a branch, or ask. A program that runs git internally (`npm version`, a deploy script) is prose-bound only; the wall reads git and the GitHub tools. Merging a pull request (`gh pr merge`, the GitHub merge tool) is not walled: on "merge it" that is the approved path, and prose is the instrument that tells "he told me to" from "I decided to". Known cost, by design: a one-liner that leaves `main` and then commits, merges or rebases, or that changes directory to an unresolvable target and then commits, is denied and told to split; the next call reads the real branch and directory. |
| `hooks/deny-brain-write.sh` | Turns a brain write into a per-record approval prompt that shows the founder the exact text; denies by itself where the harness cannot prompt (plan mode, `dontAsk`, a headless run; `bypassPermissions` is unmeasured), and denies a subagent outright. Covers six tools on any MCP server: `capture_thought`, `park_note`, `backfill_canonical_embeddings`, and the database door the brain's store sits behind, `execute_sql`, `apply_migration` and `deploy_edge_function`. Every SQL call is gated, reads included, because classifying SQL by matching its text is how a wall gets fooled. Read tools are not matched. The file name is historical: it denied every write before the founder's 2026-09-01 correction. |

**Why hooks.** Claude Code treats `CLAUDE.md` as context, not enforcement. To block
an action regardless of what the model decides, the docs say to use a hook. The
two hard lines that matter most are hooks here; the prose states the reason, the
hook is the wall: the main wall denies, the brain wall prompts the founder per record. The other three hard lines are prose only. Hooks fire inside
subagents as well, so the walls hold there. The walls have no bypass by design:
the approved paths to `main` are a pull request the founder tells the session
to merge, or a command he runs himself. A container that could not fetch the
scripts has no wall until it does; the session-start hook says so out loud and
never installs the settings without the scripts they call.

**Why this repo is public.** A Claude Code cloud container starts with an empty
`~/.claude/`, and its network proxy reaches only the repositories attached to
that session. A private repo cannot serve an arbitrary session; public
`raw.githubusercontent.com` can, with no credentials. It contains operating rules
only: no secrets, keys, paths, client or business detail.

**Mirror, not master.** The editing master is `SparrowBrain/config/global-CLAUDE.md`,
deployed to `~/.claude/` by `config/sync.sh`. Change the master and re-publish
here; do not hand-edit this copy. Exception on record: v4 was drafted here first,
so until the master is updated to match, this copy leads and the master follows.

**How a session picks it up.** A `SessionStart` hook fetches these files into
`~/.claude/`. Reference implementation: `Tight5/pinnacleapproach-website`,
`.claude/hooks/session-start.sh`.
