# claude-doctrine

The global operating rules for Clint Phillips's Claude Code sessions, and the two
hooks that enforce the rules prose alone cannot.

| File | What it is |
|---|---|
| `CLAUDE.md` | The doctrine. Loaded into every session as `~/.claude/CLAUDE.md`. |
| `settings.json` | Hooks block installed into `~/.claude/settings.json`. Wires each wall so a missing script denies the call instead of allowing it. |
| `hooks/deny-founder-gates.sh` | Denies, on `main`: a commit, a merge, cherry-pick, revert, rebase or applied patch, and a bare push; anywhere: a push whose refspec names `main`, `push --all`, `push --mirror`, and the GitHub file-write tools when their branch is `main`. The branch rule is one-way: a `git checkout main` earlier in the same command counts as `main`, and nothing inside one command can argue the wall off `main`; a switch away is honored by the next call. Work that does not target `main` is not blocked by design; a form the wall cannot read is denied with a reason. Fails closed on a parse failure, a missing script, a script that crashes, or a commit, push or merge whose repository it cannot identify at hook time (a `cd` to a `$variable` or `$(subshell)`, a directory that does not exist yet, a working directory the input did not carry). Known cost, by design: a one-liner that leaves `main` and then commits, merges or rebases, or that changes directory to an unresolvable target and then commits, is denied and told to split; the next call reads the real branch and directory. |
| `hooks/deny-brain-write.sh` | Turns an Open Brain write into a per-record approval prompt that shows the founder the exact text; denies by itself where the harness cannot prompt, and denies a subagent outright. The file name is historical: it denied every write before the founder's 2026-09-01 correction. |

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
