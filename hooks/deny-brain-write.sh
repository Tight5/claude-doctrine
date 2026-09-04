#!/bin/bash
# PreToolUse hook, matched on the brain write tools and on the database door.
# Enforces the founder hard line as he corrected it on 2026-09-01: a brain write
# is gated on his word per record, not forbidden.
#
# The database door is the same door. The brain lives in a Supabase store, so
# execute_sql, apply_migration and deploy_edge_function reach it without
# touching a capture tool. His hard line bars SQL to a subagent "by any tool"
# and his section 6 bound puts SQL and a migration under his approval at the
# moment it happens. Every such call is gated, reads included: classifying SQL
# by matching its text is the mistake that broke the git wall five times, and a
# gated read costs one dismissed prompt while a misclassified write costs the
# rule.
#
# In the main session the call becomes a permission prompt that shows him the
# exact text; where the harness cannot prompt (plan mode, dontAsk, a
# non-interactive run) that prompt is a denial, so it fails closed. A subagent's
# call is denied outright: those calls are denied to a subagent, not escalated
# to a prompt. Fires inside subagents too.
set -u
input="$(cat)"
deny() { echo "DENIED by founder doctrine: $1" >&2; exit 2; }
case "$input" in *[![:space:]]*) ;; *) deny "this hook received no input, so it cannot check the call (fail closed)." ;; esac
if command -v jq >/dev/null 2>&1; then
  agent="$(printf '%s' "$input" | jq -r '.agent_id // empty | tostring' 2>/dev/null)"
  tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
else
  agent="$(printf '%s' "$input" | sed -nE 's/.*"agent_id":[[:space:]]*("([^"]*)"|([^,}[:space:]]*)).*/\2\3/p' | head -1)"
  [ "$agent" = null ] && agent=""
  tool="$(printf '%s' "$input" | sed -nE 's/.*"tool_name":[[:space:]]*"([^"]*)".*/\1/p' | head -1)"
fi
[ -z "$tool" ] && deny "this hook could not read the tool name from its input, so it cannot tell a main-session write from a subagent's (fail closed)."
[ -n "$agent" ] && deny "a subagent never writes to the brain and never runs SQL. Those calls are denied to a subagent, not escalated to a prompt. Hand the record to the main session for the founder's word."
case "$tool" in
  *execute_sql|*apply_migration|*deploy_edge_function)
    reason="FOUNDER GATE: $tool is a database command against the store the brain lives in, so it reaches the brain by another door. Read the statement shown here and give your word on this one call. Never per batch, never on standing authority." ;;
  *)
    reason="FOUNDER GATE, per record: ${tool:-this brain write} carries the text shown here. Approve only if you have read it in the exact words it will carry and give your word on this record; the lead then shows read-back proof. Never per batch, never on standing authority." ;;
esac
if command -v jq >/dev/null 2>&1; then
  jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
else
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$(printf '%s' "$reason" | sed 's/"/\\"/g')"
fi
exit 0
