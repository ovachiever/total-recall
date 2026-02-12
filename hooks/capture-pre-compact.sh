#!/bin/bash
# PreCompact hook: Captures the terminal TUI via tmux before compaction
# Requires running Claude Code inside tmux (just type "tmux" before "claude")
#
# The captured scrollback is saved to ~/.claude/compact-snapshots/{session_id}.txt
# and re-injected by reinject-post-compact.sh after compaction completes.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

# Only works inside tmux — silently exit if not
[ -z "$TMUX" ] && exit 0

SNAPSHOT_DIR="$HOME/.claude/compact-snapshots"
mkdir -p "$SNAPSHOT_DIR"

# Capture full scrollback buffer — this IS the TUI the user would manually copy
tmux capture-pane -p -S - > "$SNAPSHOT_DIR/${SESSION_ID}.txt" 2>/dev/null

exit 0
