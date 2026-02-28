#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
OS="$(uname -s)"

mkdir -p "$LOG_DIR"

# Find tailscale binary with OS-specific fallback
if TAILSCALE=$(command -v tailscale 2>/dev/null); then
    : # found
elif [ "$OS" = "Darwin" ]; then
    TAILSCALE="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
else
    TAILSCALE="/usr/bin/tailscale"
fi

# Get Tailscale IP
TAILSCALE_IP=$("$TAILSCALE" ip -4 2>/dev/null)
if [ -z "$TAILSCALE_IP" ]; then
    echo "ERROR: Tailscale not running or no IPv4 address" >&2
    exit 1
fi

# tmux session name: first argument or default "claude"
export TMUX_SESSION="${1:-claude}"

echo "Tailscale IP: $TAILSCALE_IP"
echo "tmux session: $TMUX_SESSION"

# Kill any existing ttyd processes
pkill -f "ttyd" 2>/dev/null || true
sleep 1

# Keep machine awake: caffeinate on macOS, systemd-inhibit on Linux
if [ "$OS" = "Darwin" ]; then
    pkill -f "caffeinate" 2>/dev/null || true
    caffeinate -d -i -s &
    INHIBIT_PID=$!
    echo "caffeinate running (PID: $INHIBIT_PID)"
else
    if command -v systemd-inhibit >/dev/null 2>&1; then
        systemd-inhibit --what=idle --who="remote-cli" --why="Keeping machine awake for remote CLI" sleep infinity &
        INHIBIT_PID=$!
        echo "systemd-inhibit running (PID: $INHIBIT_PID)"
    else
        echo "WARNING: No sleep inhibitor available (caffeinate/systemd-inhibit not found), skipping"
        INHIBIT_PID=""
    fi
fi

# Start ttyd bound to Tailscale IP only
# Uses tmux-attach.sh wrapper for clean argument handling
ttyd \
    --port 7681 \
    --interface "$TAILSCALE_IP" \
    --writable \
    -t fontSize=14 \
    -t lineHeight=1.2 \
    -t cursorBlink=true \
    -t cursorStyle=block \
    -t scrollback=10000 \
    -t scrollSensitivity=3 \
    -t fastScrollSensitivity=10 \
    -t smoothScrollDuration=100 \
    -t 'fontFamily="Menlo, Monaco, Consolas, monospace, Apple Color Emoji, Segoe UI Emoji"' \
    "$SCRIPT_DIR/tmux-attach.sh" \
    >> "$LOG_DIR/ttyd.log" 2>&1 &

TTYD_PID=$!
echo "ttyd running (PID: $TTYD_PID) on http://$TAILSCALE_IP:7681"

# Start voice dictation wrapper
pkill -f "voice-wrapper" 2>/dev/null || true
python3 "$SCRIPT_DIR/voice-wrapper.py" >> "$LOG_DIR/voice-wrapper.log" 2>&1 &
WRAPPER_PID=$!
echo "voice wrapper running (PID: $WRAPPER_PID) on http://$TAILSCALE_IP:8080"

echo ""
echo "=== Remote CLI Ready ==="
echo "Terminal:  http://$TAILSCALE_IP:7681"
echo "Voice UI:  http://$TAILSCALE_IP:8080"
echo ""
echo "Open the Voice UI URL in Chrome on your iPhone (Tailscale must be active)."
echo "To stop: $SCRIPT_DIR/stop-remote-cli.sh"

# Save PIDs for stop script (including this watchdog parent)
echo "$$" > "$LOG_DIR/watchdog.pid"
echo "$TTYD_PID" > "$LOG_DIR/ttyd.pid"
[ -n "$INHIBIT_PID" ] && echo "$INHIBIT_PID" > "$LOG_DIR/inhibit.pid"
echo "$WRAPPER_PID" > "$LOG_DIR/voice-wrapper.pid"

# Watchdog: restart ttyd if it crashes, exit cleanly on SIGTERM
KEEP_RUNNING=true
trap 'KEEP_RUNNING=false; kill $TTYD_PID 2>/dev/null' TERM INT

while $KEEP_RUNNING; do
    wait $TTYD_PID 2>/dev/null || true
    if ! $KEEP_RUNNING; then
        break
    fi
    echo "[$(date)] ttyd exited, restarting in 5s..." >> "$LOG_DIR/ttyd.log"
    sleep 5
    ttyd \
        --port 7681 \
        --interface "$TAILSCALE_IP" \
        --writable \
        -t fontSize=14 \
        -t lineHeight=1.2 \
        -t cursorBlink=true \
        -t cursorStyle=block \
        -t scrollback=10000 \
        -t scrollSensitivity=3 \
        -t fastScrollSensitivity=10 \
        -t smoothScrollDuration=100 \
        -t 'fontFamily="Menlo, Monaco, Consolas, monospace, Apple Color Emoji, Segoe UI Emoji"' \
        "$SCRIPT_DIR/tmux-attach.sh" \
        >> "$LOG_DIR/ttyd.log" 2>&1 &
    TTYD_PID=$!
    echo "$TTYD_PID" > "$LOG_DIR/ttyd.pid"
    echo "[$(date)] ttyd restarted (PID: $TTYD_PID)" >> "$LOG_DIR/ttyd.log"
done
