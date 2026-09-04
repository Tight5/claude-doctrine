#!/bin/bash
# PreToolUse hook, matched on the Open Brain write tools. Enforces the founder
# hard line as he corrected it on 2026-09-01: a brain write is gated on his word
# per record, not forbidden. In the main session the write becomes a permission
# prompt that shows him the exact text; where the harness cannot prompt (plan
# mode, dontAsk, a non-interactive run) that prompt is a denial, so it fails
# closed. A subagent's brain write is denied outright: those calls are denied
# to a subagent, not escalated to a prompt. Fires inside subagents too.
set -u
input="$(cat)"
[ -z "$input" ] && { echo "DENIED by founder doctrine: this hook received no input, so it cannot check the call (fail closed)." >&2; exit 2; }
if command -v jq >/dev/null 2>&1; then
  agent="$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)"
  tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
else
  agent="$(printf '%s' "$input" | sed -nE 's/.*"agent_id":[[:space:]]*"([^"]*)".*/\1/p' | head -1)"
  tool="$(printf '%s' "$input" | sed -nE 's/.*"tool_name":[[:space:]]*"([^"]*)".*/\1/p' | head -1)"
fi
if [ -n "$agent" ]; then
  echo "DENIED by founder doctrine: a subagent never writes to Open Brain. Those calls are denied to a subagent, not escalated to a prompt. Hand the record to the main session for the founder's word." >&2
  exit 2
fi
reason="FOUNDER GATE, per record: ${tool:-this Open Brain write} carries the text shown here. Approve only if you have read it in the exact words it will carry and give your word on this record; the lead then shows read-back proof. Never per batch, never on standing authority."
if command -v jq >/dev/null 2>&1; then
  jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
else
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$(printf '%s' "$reason" | sed 's/"/\\"/g')"
fi
exit 0
