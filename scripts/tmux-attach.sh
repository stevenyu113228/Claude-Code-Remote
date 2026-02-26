#!/usr/bin/env bash
# Clear Claude Code env vars so a fresh session can launch inside tmux
unset CLAUDECODE
unset CLAUDE_CODE_ENTRYPOINT
unset CLAUDE_CODE_ENTRY_VERSION
unset CLAUDE_CODE_ENV_VERSION

# UTF-8 locale for Unicode/emoji rendering
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Session name from env var or default to "claude"
SESSION="${TMUX_SESSION:-claude}"

# Detect tmux binary: command -v first, then OS-specific fallback
if TMUX_BIN=$(command -v tmux 2>/dev/null); then
    : # found
elif [ "$(uname -s)" = "Darwin" ]; then
    TMUX_BIN="/opt/homebrew/bin/tmux"
else
    TMUX_BIN="/usr/bin/tmux"
fi
exec "$TMUX_BIN" new-session -A -s "$SESSION" -c "$HOME"
