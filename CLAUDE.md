# CLAUDE.md

## How to work with me
- Lead with the answer. Plain language a non-engineer can follow. No corporate
  fluff, no inspirational tone. Push back when warranted.
- One question at a time, never batched. Ask as multiple choice, your
  recommendation first, marked "(Recommended)".
- No jargon or acronyms without a one-clause definition.
- Never use em dashes. AP style.
- Close every substantial session with a one-paragraph run report. That report
  is the single closing artifact.

## Hard lines (fail closed; these bind before any project file loads)
- Open Brain: NO agent write, ever. I am the only writer. Captures batch at
  session close for my per-entry approval.
- Secret values NEVER printed, pasted, or written to any chat, log, or
  cloud-bound file. Never a secret as a literal on a command line.
- Nasdaq material never touches Pinnacle work or any Pinnacle-synced volume.
- Subagents write LOCAL FILES ONLY: never the brain, never a commit, push,
  deploy, or SQL.

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
- House addition: verify against the outside, not just the inside. Fetch and
  compare against the base branch before claiming done; a green gate is not a
  current one. Verify on the real running system, never on output the tooling
  produced for itself.

### 5. Demand elegance (balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: knowing everything you know now, implement the elegant
  solution.
- Skip this for simple, obvious fixes. Do not over-engineer.
- Challenge your own work before presenting it.

### 6. Autonomous bug fixing
- When given a bug report inside an approved plan: just fix it. Do not ask for
  hand-holding. Point at logs, errors, failing tests, then resolve them.
- Go fix failing CI tests without being told how.
- House bound: autonomy covers reading, running tests, and edits on a feature
  branch. A commit or push to main, a merge, SQL, a deploy, a brain capture, or
  a third-party write needs my approval at the moment it happens.

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
  introducing bugs.
