# Claude Code Remote

## What This Is

This repo contains scripts to set up remote access to Claude Code CLI from a phone (or any device) over a Tailscale VPN connection. The user has cloned this repo and wants help getting it running on their Mac or Linux machine.

## Architecture

```
iPhone (Browser) → Tailscale VPN → Mac/Linux → tmux → Claude Code
                                       |
                                 ┌─────┴─────┐
                                 Port 8080    Port 7681
                                 Voice UI     Raw Terminal
```

## Helping the User Set Up

When the user asks for help installing or setting up this project, walk them through these steps in order. **Verify each step before moving to the next.**

### 1. Check prerequisites

Run these checks and report what's missing:

```bash
ttyd --version          # ttyd installed?
tmux -V                 # tmux installed?
python3 -c "import fastapi; import uvicorn; import multipart; print('ok')"  # Python packages?
tailscale ip -4         # Tailscale running and connected?
claude --version        # Claude Code CLI installed?
```

Install anything missing:
- macOS: `brew install ttyd tmux`
- Linux (Debian/Ubuntu): `sudo apt install ttyd tmux`
- `pip3 install fastapi uvicorn python-multipart` for Python packages
- Tailscale and Claude Code CLI must be installed manually by the user

### 2. Verify Tailscale

- Confirm `tailscale ip -4` returns an IP (like `100.x.y.z`)
- Remind the user to install Tailscale on their phone too and sign in with the same account

### 3. Test the setup

- Run `./scripts/start-remote-cli.sh` and verify it starts without errors
- Confirm the output shows the Tailscale IP and both port URLs
- Tell the user to open the Voice UI URL on their phone

### 4. Set up auto-start (if the user wants it)

**macOS (launchd):**

- Get the user's macOS username: `whoami`
- Replace every `YOUR_USERNAME` in `scripts/remote-cli.plist` with their actual username
- Copy scripts to `~/.local/bin/remote-cli/` (launchd can't access `~/Documents/` due to macOS TCC restrictions)
- Copy the plist to `~/Library/LaunchAgents/com.user.remote-cli.plist`
- Load it with `launchctl load`

**Linux (systemd):**

- Get the user's username: `whoami`
- Replace every `YOUR_USERNAME` in `scripts/remote-cli.service` with their actual username
- Copy scripts to `~/.local/bin/remote-cli/`
- Copy the service to `~/.config/systemd/user/remote-cli.service`
- Enable with `systemctl --user daemon-reload && systemctl --user enable --now remote-cli`

## Important Gotchas

- **TCC restriction (macOS only):** launchd agents cannot access `~/Documents/`, `~/Desktop/`, or `~/Downloads/` without Full Disk Access. Scripts must be copied to a location like `~/.local/bin/remote-cli/` for auto-start to work.
- **tmux env vars:** The `tmux-attach.sh` script unsets Claude Code environment variables before creating the tmux session. This prevents conflicts when Claude Code tries to launch inside an existing Claude Code session.
- **ttyd auth:** The `--credential` flag for ttyd basic auth is not currently enabled. It was causing connection failures. Tailscale network-level security is the primary access control.
- **Binary detection:** All scripts use `command -v` / `shutil.which` to find binaries first, then fall back to OS-specific paths (macOS: `/opt/homebrew/bin/`, Linux: `/usr/bin/`).
- **Sleep inhibitor:** macOS uses `caffeinate`, Linux uses `systemd-inhibit`. If neither is available, the script continues without it.
- **Services bind to Tailscale IP only.** If Tailscale isn't running, the start script will fail. This is intentional — never bind to `0.0.0.0`.

## File Overview

| File | Purpose |
|------|---------|
| `scripts/start-remote-cli.sh` | Starts ttyd, voice wrapper, and sleep inhibitor. Includes watchdog for auto-restart. |
| `scripts/stop-remote-cli.sh` | Stops all services (including watchdog). Preserves the tmux session. |
| `scripts/tmux-attach.sh` | Wrapper that clears env vars and attaches to (or creates) the tmux session. |
| `scripts/voice-wrapper.py` | FastAPI app serving the mobile-optimized UI with dictation support. |
| `scripts/remote-cli.plist` | launchd plist for macOS auto-start on boot. Requires `YOUR_USERNAME` replacement. |
| `scripts/remote-cli.service` | systemd unit for Linux auto-start on boot. Requires `YOUR_USERNAME` replacement. |
