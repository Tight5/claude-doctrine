# claude-doctrine

The global operating rules for Clint Phillips's Claude Code sessions, in
[`CLAUDE.md`](CLAUDE.md).

**Why this repo is public.** A Claude Code cloud container starts with an empty
`~/.claude/`, and its network proxy will only reach GitHub repositories attached to
that session. A private repo therefore cannot serve an arbitrary session. Public
`raw.githubusercontent.com` can, with no credentials, from anywhere. This repo exists
for exactly that one property.

It contains operating rules only: no secrets, no keys, no paths, no client or
business detail.

**This is a mirror, not the master.** The editing master is
`SparrowBrain/config/global-CLAUDE.md`, deployed to `~/.claude/CLAUDE.md` by
`config/sync.sh`. Change the master and re-publish here; do not hand-edit this copy.

**How a session picks it up.** A `SessionStart` hook fetches this file into
`~/.claude/CLAUDE.md`, which Claude Code loads before any project instructions. A
reference implementation is in `Tight5/pinnacleapproach-website` at
`.claude/hooks/session-start.sh`.
