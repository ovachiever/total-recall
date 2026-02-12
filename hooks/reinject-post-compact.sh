#!/bin/bash
# SessionStart (compact) hook: Re-injects captured TUI after compaction
#
# stdout from SessionStart hooks is added directly to Claude's context,
# so the captured conversation flows back in automatically.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
SNAPSHOT_DIR="$HOME/.claude/compact-snapshots"
SNAPSHOT_FILE="$SNAPSHOT_DIR/${SESSION_ID}.txt"

if [ -f "$SNAPSHOT_FILE" ] && [ -s "$SNAPSHOT_FILE" ]; then
    # Truncate to ~60K chars to avoid filling the new context window
    # (typical TUI capture is 5-20K chars, but safety limit)
    CONTENT=$(head -c 60000 "$SNAPSHOT_FILE")

    CONTEXT="## Pre-Compaction Conversation History
The following is the conversation from before compaction was triggered.
Use this to maintain full context of what was discussed and decided.
---
${CONTENT}
---"

    ESCAPED=$(echo "$CONTEXT" | jq -Rs .)
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":${ESCAPED}}}"

    # Clean up after injection
    rm -f "$SNAPSHOT_FILE"
fi

exit 0
