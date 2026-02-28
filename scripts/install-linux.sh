#!/usr/bin/env bash
set -euo pipefail

# install-linux.sh — Install all prerequisites for Claude Code Remote on Linux

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Error: This script is for Linux only. Detected: $(uname -s)"
    exit 1
fi

echo "=== Claude Code Remote — Linux Installer ==="
echo

# Install system packages
echo "Installing system packages (tmux, curl)..."
sudo apt-get update
sudo apt-get install -y tmux curl
echo

# Install ttyd from GitHub releases (not available in many distros' apt repos)
if command -v ttyd &>/dev/null; then
    echo "ttyd is already installed: $(ttyd --version 2>/dev/null || echo 'unknown version')"
else
    echo "Installing ttyd from GitHub releases..."
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  TTYD_ARCH="x86_64" ;;
        aarch64) TTYD_ARCH="aarch64" ;;
        armv7l)  TTYD_ARCH="armhf" ;;
        *)
            echo "Error: Unsupported architecture: $ARCH"
            echo "Install ttyd manually: https://github.com/tsl0922/ttyd/releases"
            exit 1
            ;;
    esac
    sudo curl -fSL -o /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${TTYD_ARCH}"
    sudo chmod +x /usr/local/bin/ttyd
    echo "ttyd installed to /usr/local/bin/ttyd"
fi
echo

# Install Python packages
echo "Installing Python packages (fastapi, uvicorn, python-multipart)..."
if pip3 install --break-system-packages fastapi uvicorn python-multipart 2>/dev/null; then
    true
else
    echo "Retrying without --break-system-packages..."
    pip3 install fastapi uvicorn python-multipart
fi
echo

# Install Tailscale
if command -v tailscale &>/dev/null; then
    echo "Tailscale is already installed."
else
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi
echo

# Check Claude Code CLI
if command -v claude &>/dev/null; then
    echo "Claude Code CLI is installed: $(claude --version 2>/dev/null || echo 'unknown version')"
else
    echo "Claude Code CLI is NOT installed."
    echo "Install it with:  npm install -g @anthropic-ai/claude-code"
    echo "Then run:          claude"
fi
echo

echo "=== Summary ==="
echo "  ttyd:       $(command -v ttyd &>/dev/null && echo 'installed' || echo 'MISSING')"
echo "  tmux:       $(command -v tmux &>/dev/null && echo 'installed' || echo 'MISSING')"
echo "  tailscale:  $(command -v tailscale &>/dev/null && echo 'installed' || echo 'MISSING')"
echo "  claude:     $(command -v claude &>/dev/null && echo 'installed' || echo 'MISSING')"
echo
echo "=== Next Steps ==="
echo "  1. Connect Tailscale:    sudo tailscale up"
echo "  2. Install Tailscale on your phone and sign in with the same account"
echo "  3. Start the service:    ./scripts/start-remote-cli.sh"
