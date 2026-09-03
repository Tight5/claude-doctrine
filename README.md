# claude-doctrine

The global operating rules for Clint Phillips's Claude Code sessions, and the two
hooks that enforce the rules prose alone cannot.

| File | What it is |
|---|---|
| `CLAUDE.md` | The doctrine. Loaded into every session as `~/.claude/CLAUDE.md`. |
| `settings.json` | Hooks block installed into `~/.claude/settings.json`. |
| `hooks/deny-founder-gates.sh` | Denies any commit or push to `main`. Feature branches are never blocked. |
| `hooks/deny-brain-write.sh` | Denies the Open Brain write tools. |

**Why hooks.** Claude Code treats `CLAUDE.md` as context, not enforcement. To block
an action regardless of what the model decides, the docs say to use a hook. The
two hard lines that matter most are hooks here; the prose states the reason, the
hook is the wall. Hooks fire inside subagents as well, so the walls hold there.

**Why this repo is public.** A Claude Code cloud container starts with an empty
`~/.claude/`, and its network proxy reaches only the repositories attached to
that session. A private repo cannot serve an arbitrary session; public
`raw.githubusercontent.com` can, with no credentials. It contains operating rules
only: no secrets, keys, paths, client or business detail.

**Mirror, not master.** The editing master is `SparrowBrain/config/global-CLAUDE.md`,
deployed to `~/.claude/` by `config/sync.sh`. Change the master and re-publish
here; do not hand-edit this copy. `CLAUDE.md` is byte-identical to the master.

**How a session picks it up.** A `SessionStart` hook fetches these files into
`~/.claude/`. Reference implementation: `Tight5/pinnacleapproach-website`,
`.claude/hooks/session-start.sh`.
