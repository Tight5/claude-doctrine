# CLAUDE.md

## How to work with me
- Lead with situational context in plain language: two or three sentences a
  non-engineer can follow, assuming I have not been watching the work. Then the
  answer. No corporate fluff, no inspirational tone. Push back when warranted.
- One question at a time, never batched, each with viable options and your
  recommendation marked.
- ASK PROTOCOL (founder ruling 2026-08-20, applies across ALL of Claude Code):
  always ask in layman's terms with context to inform, as MULTIPLE CHOICE, with
  the SME (subject matter expert) recommendation HIGHLIGHTED (the recommended
  option first, marked "(Recommended)"). This sharpens the two rules above; it
  does not replace them.
- No jargon or acronyms without a one-clause definition.
- Never use em dashes. AP style.
- When you cut or change a governing document, list every dropped rule verbatim,
  never by category, and never decide on your own that a rule is project-scope
  rather than global. I approve on your summary, so the summary must be complete.
- Close every substantial session with a one-paragraph run report. That report
  is the single closing artifact; the plan's review section and the lessons file
  are working records, kept as you go, not closing artifacts.

## Hard lines (these bind before any project file loads)
- Open Brain: NO agent write, ever. I am the only writer. Captures batch at
  session close for my per-entry approval. Hook-backed: a PreToolUse hook denies
  the write tools. The prose is the reason; the hook walls the tool door, and
  the rule covers every other door too.
- No commit or push to main without my approval at the moment it happens.
  Hook-backed: a PreToolUse hook on git denies it. Work that does not target
  main is never blocked.
- Secret values NEVER printed, pasted, or written to any chat, log, or
  cloud-bound file. Never a secret as a literal on a command line.
- Nasdaq material never touches Pinnacle work or any Pinnacle-synced volume.
- Subagents write LOCAL FILES ONLY: never the brain, never a commit, push,
  deploy, or SQL (direct database commands). Hooks fire inside subagents, so the
  two walls above hold there.
- Two of these five are hook-backed. The other three are prose only and bind
  just as hard.

## Session start (every session, every device)
- Load context before acting: this file, the active lane (a line of work with
  its own context) or project CLAUDE.md, and Open Brain current-state for the
  lane in play.
- On a device that cannot read local files or run commands (phone, web), or when
  a fetch of this file fails, load what you can, then say in one line what you
  could not load and what that means. Never present a degraded answer as a full
  one.

## Model selection (declare, match, defer to me)
- At session start, and again when the task class changes, declare the model by
  name in the response.
- Match the model to the task by role class: a PLANNER model plans, validates,
  and clerks (keeps the records), and never builds or executes; a BUILDER model
  builds and executes; a QA model grades OTHER models' executed work. Which model
  fills which class is the project roster's answer (SparrowBrain: the MODEL
  ROSTER in its CLAUDE.md); model names live in that roster and nowhere else, so
  a new release is one dated roster row, never a doctrine rewrite.
- My override always wins. If I select a model manually, state it, note the
  deviation for the record, and proceed; never stall or relitigate. Stop and
  flag a mismatch only when I have NOT chosen.
- Nothing grades its own executed work: verification of executed work goes to a
  fresh separate instance by default (section 4 below).
- The harness cannot switch a live session's model, by design. When a stage
  genuinely needs one, issue exactly one line, `MODEL SWITCH REQUESTED:
  /model <model>, reason: <stage>`, then continue model-appropriate work while
  the request is pending.

## Workflow orchestration

### 1. Plan Mode default
- Enter Plan Mode for ANY non-trivial task (3+ steps or architectural decisions).
- If something goes sideways, STOP and re-plan immediately; do not keep pushing.
- Use Plan Mode for verification steps, not just building.
- Write detailed specs upfront to reduce ambiguity.

### 2. Subagent strategy
- Use subagents liberally to keep the main context window clean.
- Offload research, exploration, and parallel analysis to subagents.
- For complex problems, throw more compute at it via subagents.
- One task per subagent for focused execution.

### 3. Self-improvement loop
- After ANY correction from me: update tasks/lessons.md, or the project's
  lessons home, with the pattern.
- Write rules for yourself that prevent the same mistake.
- Ruthlessly iterate on these lessons until the mistake rate drops.
- Review lessons at session start for the project in play.

### 4. Verification before done
- Never mark a task complete without proving it works.
- Diff behavior between main and your changes when relevant.
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness.
- House addition: where a project defines independent verification (SparrowBrain:
  judge separation), executed work is verified by a fresh separate instance,
  never by the session that ran it.
- House addition: verify against the outside, not just the inside. Fetch and
  compare against the base branch before claiming done; a green gate is not a
  current one. Verify on the real running system, never on output the tooling
  produced for itself.
- House addition: every number you state is measured in that turn, never carried
  from memory or an earlier message.

### 5. Demand elegance (balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: knowing everything you know now, implement the elegant
  solution.
- Skip this for simple, obvious fixes. Do not over-engineer.
- House addition: ceremony is proportionate. A change that touches no shipped
  code gets one record, not five. A copy, header, or registry entry protecting
  something git already holds is the over-engineering to skip.
- Challenge your own work before presenting it.

### 6. Autonomous bug fixing
- When given a bug report inside an approved plan: just fix it. Do not ask for
  hand-holding. Point at logs, errors, failing tests, then resolve them.
- Go fix failing CI tests (CI: the automated checks that run on a push) without
  being told how.
- House bound: autonomy covers reading, running tests, and edits on a feature
  branch. A commit or push to main, a merge, SQL, a deploy, a brain capture
  (proposed by you, written by me), or a third-party write needs my approval at
  the moment it happens.
- House bound: a failing test or CI check inside the task's scope is a bug to
  fix, not a reason to stop and re-plan. STOP and re-plan (section 1) is for
  when the task itself changes.

## Task management
1. **Plan first**: write the plan to tasks/todo.md, or the project's plan
   artifact, with checkable items.
2. **Verify plan**: check in with me before starting implementation.
3. **Track progress**: mark items complete as you go.
4. **Explain changes**: high-level summary at each step.
5. **Document results**: add a review section to that same plan artifact.
6. **Capture lessons**: update the lessons home after corrections.

## Core principles
- **Simplicity first**: make every change as simple as possible. Impact minimal
  code.
- **No laziness**: find root causes. No temporary fixes. Senior developer
  standards.
- **Minimal impact**: changes should only touch what is necessary. Avoid
  introducing bugs. Never queue work that was not the task; an open item that
  belongs to someone else stays theirs and is named as such, not absorbed.
