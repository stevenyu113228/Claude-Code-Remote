#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"

echo "Stopping remote CLI services..."

# Stop watchdog first so it doesn't respawn ttyd
if [ -f "$LOG_DIR/watchdog.pid" ]; then
    kill "$(cat "$LOG_DIR/watchdog.pid")" 2>/dev/null && echo "watchdog stopped" || echo "watchdog was not running"
    rm -f "$LOG_DIR/watchdog.pid"
else
    pkill -f "start-remote-cli" 2>/dev/null && echo "watchdog stopped" || true
fi

# Stop ttyd
if [ -f "$LOG_DIR/ttyd.pid" ]; then
    kill "$(cat "$LOG_DIR/ttyd.pid")" 2>/dev/null && echo "ttyd stopped" || echo "ttyd was not running"
    rm -f "$LOG_DIR/ttyd.pid"
else
    pkill -f "ttyd" 2>/dev/null && echo "ttyd stopped" || echo "ttyd was not running"
fi

# Stop voice wrapper
if [ -f "$LOG_DIR/voice-wrapper.pid" ]; then
    kill "$(cat "$LOG_DIR/voice-wrapper.pid")" 2>/dev/null && echo "voice wrapper stopped" || echo "voice wrapper was not running"
    rm -f "$LOG_DIR/voice-wrapper.pid"
else
    pkill -f "voice-wrapper" 2>/dev/null && echo "voice wrapper stopped" || echo "voice wrapper was not running"
fi

# Stop sleep inhibitor (caffeinate on macOS, systemd-inhibit on Linux)
if [ -f "$LOG_DIR/inhibit.pid" ]; then
    kill "$(cat "$LOG_DIR/inhibit.pid")" 2>/dev/null && echo "sleep inhibitor stopped" || echo "sleep inhibitor was not running"
    rm -f "$LOG_DIR/inhibit.pid"
else
    pkill -f "caffeinate" 2>/dev/null && echo "caffeinate stopped" || true
    pkill -f "systemd-inhibit.*remote-cli" 2>/dev/null && echo "systemd-inhibit stopped" || true
fi
# Clean up legacy PID file if present
rm -f "$LOG_DIR/caffeinate.pid"

echo ""
echo "Services stopped. tmux session(s) are still alive."
echo "To list sessions: tmux ls"
echo "To kill one:      tmux kill-session -t <name>"
