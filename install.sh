#!/bin/bash
# total-recall installer
# Copies hooks into place and updates Claude Code settings

set -e

HOOKS_DIR="$HOME/.claude/hooks"
SNAPSHOT_DIR="$HOME/.claude/compact-snapshots"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing total-recall..."

# 1. Create directories
mkdir -p "$HOOKS_DIR" "$SNAPSHOT_DIR"

# 2. Copy hooks
cp "$SCRIPT_DIR/hooks/capture-pre-compact.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/reinject-post-compact.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/capture-pre-compact.sh" "$HOOKS_DIR/reinject-post-compact.sh"
echo "  Hooks installed to $HOOKS_DIR"

# 3. Check for jq (required by hooks)
if ! command -v jq &>/dev/null; then
    echo "  Warning: jq is not installed. Install it with: brew install jq"
fi

# 4. Check for tmux
if ! command -v tmux &>/dev/null; then
    echo "  Warning: tmux is not installed. Install it with: brew install tmux"
fi

# 5. Update settings.json
if [ -f "$SETTINGS" ]; then
    # Check if hooks are already configured
    if grep -q "capture-pre-compact" "$SETTINGS" 2>/dev/null; then
        echo "  Settings already configured (skipping)"
    else
        echo ""
        echo "  Add the following to your ~/.claude/settings.json hooks section:"
        echo ""
        cat <<'SNIPPET'
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/capture-pre-compact.sh",
            "timeout": 15
          }
        ]
      }
    ],

    // Add this entry to your existing "SessionStart" array:
    {
      "matcher": "compact",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/reinject-post-compact.sh",
          "timeout": 10
        }
      ]
    }
SNIPPET
        echo ""
        echo "  (Auto-patching settings.json is risky — please add manually)"
    fi
else
    echo "  No settings.json found at $SETTINGS"
    echo "  Run 'claude' once to create it, then re-run this installer"
fi

# 6. tmux config suggestion
if [ ! -f "$HOME/.tmux.conf" ]; then
    echo ""
    read -p "  No ~/.tmux.conf found. Copy the recommended config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$SCRIPT_DIR/example-tmux.conf" "$HOME/.tmux.conf"
        echo "  tmux config installed"
    fi
fi

echo ""
echo "Done! Usage:"
echo "  tmux          # Start tmux"
echo "  claude        # Run Claude Code inside it"
echo "  (compaction context is now automatic)"
