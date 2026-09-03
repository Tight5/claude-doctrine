#!/bin/bash
# PreToolUse hook, matched on the Open Brain write tools. Enforces the founder
# hard line: no agent write to the brain, ever. Fires inside subagents too.
echo "DENIED by founder doctrine: Open Brain has no agent writer. Captures batch at session close for the founder's per-entry approval, and he executes the write." >&2
exit 2
