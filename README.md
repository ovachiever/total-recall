# total-recall

**Survive Claude Code compaction without losing your mind.**

When Claude Code runs out of context, it compacts — summarizing the conversation to free space. The summary is often good, but it's lossy. Specific decisions, file paths, exact error messages, the *feel* of what you were building together — gone.

The fix most people discover: copy the terminal output and paste it back as a prompt after compaction. It works surprisingly well, costs very little context, and Claude picks up right where it left off.

**total-recall automates that.** Two hooks, zero effort.

## How it works

```
You + Claude working on a feature
        │
        ▼
Context fills up → compaction triggered
        │
        ▼
PreCompact hook fires
  └─ tmux capture-pane grabs the full terminal scrollback
  └─ Saves to ~/.claude/compact-snapshots/{session_id}.txt
        │
        ▼
Claude Code compacts (normal behavior)
        │
        ▼
SessionStart hook fires (matcher: "compact")
  └─ Reads the saved snapshot
  └─ Outputs it as additionalContext
  └─ Claude sees the full pre-compaction conversation
        │
        ▼
Claude continues with real context, not just a summary
```

## Why this doesn't blow up your context

The terminal output (TUI) is naturally compressed. When Claude reads a file, the TUI shows:

```
⏺ Read 2 files (ctrl+o to expand)
```

Not the 500 lines of code that were actually read. Tool calls, diffs, search results — they're all collapsed in the TUI. A 500K conversation transcript becomes ~10-20K of terminal text. That's roughly 3-5% of a fresh context window.

You're trading 3-5% of your new context to retain the *entire* conversation history in a format Claude can parse. The compaction summary it replaces is often similar in size but lower fidelity.

## Requirements

- **tmux** — the hooks capture the terminal scrollback via `tmux capture-pane`
- **jq** — for parsing the hook input JSON
- **Claude Code** v2.1+ — needs `PreCompact` and `SessionStart` hook events

## Install

```bash
git clone https://github.com/ovachiever/total-recall.git
cd total-recall
chmod +x install.sh
./install.sh
```

The installer copies hooks to `~/.claude/hooks/` and prints the settings.json snippet to add. It won't auto-patch your settings (too risky), but tells you exactly what to add.

### Manual install

1. Copy the hooks:

```bash
cp hooks/capture-pre-compact.sh ~/.claude/hooks/
cp hooks/reinject-post-compact.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/capture-pre-compact.sh ~/.claude/hooks/reinject-post-compact.sh
mkdir -p ~/.claude/compact-snapshots
```

2. Add to `~/.claude/settings.json` in the `"hooks"` section:

```json
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
]
```

3. Add a new entry to your `"SessionStart"` array (keep your existing entries):

```json
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
```

4. Run Claude Code inside tmux:

```bash
tmux
claude
```

That's it. Compaction context is now automatic.

## tmux (if you're new to it)

tmux is a terminal multiplexer. For this project, you only need to know one thing: **type `tmux` before `claude`**. Everything else works the same.

An [example tmux config](example-tmux.conf) is included with sane defaults:
- **Tab titles that are actually better than without tmux.** Shows `⠂ claude — my-project` in your terminal tab: the status indicator (working/idle) from Claude Code, the AI harness name, and the project path. Ghostty-tested, but should work with any terminal that supports title escape sequences.
- 50K line scrollback (default 2K is too small for long Claude sessions)
- Mouse support (scroll, click, resize — all work naturally)
- True color (Claude Code's UI looks correct)
- Auto-kill sessions on tab close (no zombie tmux sessions eating RAM)
- Remapped prefix to `Ctrl+a` (default `Ctrl+b` is awkward)

```bash
cp example-tmux.conf ~/.tmux.conf
```

### tmux cheat sheet

| What | How |
|------|-----|
| Start | `tmux` |
| Detach (leave running) | `Ctrl+a` then `d` |
| Reattach | `tmux a` |
| Scroll | Mouse/trackpad (with the included config) |
| Kill pane | `Ctrl+a` then `k` |
| Exit | `exit` or `Ctrl+d` |

## How the hooks work

### capture-pre-compact.sh (PreCompact)

Fires before compaction. Checks for `$TMUX` environment variable. If present, runs `tmux capture-pane -p -S -` to grab the full scrollback buffer and saves it to `~/.claude/compact-snapshots/{session_id}.txt`.

If not in tmux, exits silently — no harm, no error.

### reinject-post-compact.sh (SessionStart, matcher: "compact")

Fires after compaction completes (Claude Code treats post-compaction as a session start with source "compact"). Reads the saved snapshot, wraps it in a header, and outputs it as `additionalContext` via the hook JSON protocol. Claude sees this as additional context in its fresh post-compaction window.

The snapshot is capped at 60K characters (safety limit — real captures are typically 10-20K) and deleted after injection.

## Limitations

- **Requires tmux.** Without it, there's no programmatic way to capture terminal scrollback from most terminal emulators (Ghostty, Terminal.app, etc.). iTerm2 has AppleScript APIs but they're fragile.
- **Scrollback has a limit.** The included tmux config sets 50K lines. Extremely long sessions might exceed this — increase `history-limit` in your tmux config if needed.

## License

MIT
