# Claude Code Remote

Use Claude Code from your phone — or anywhere — over a secure VPN connection.

![Architecture](architecture.svg)

<p align="center">
  <img src="screenshot-mobile.jpg" alt="Claude Code running on iPhone" width="300">
  <br>
  <em>Claude Code running on an iPhone via the Voice Wrapper UI</em>
</p>

## What This Is

A set of scripts that give you full interactive Claude Code CLI access from your phone's browser. It uses [Tailscale](https://tailscale.com) to create a secure encrypted tunnel between your devices, [ttyd](https://github.com/tsl0922/ttyd) to serve your terminal as a web page, [tmux](https://github.com/tmux/tmux) to keep sessions alive across disconnects, and a FastAPI voice wrapper that adds a mobile-friendly UI with iOS dictation support and quick-action buttons. Everything binds exclusively to your Tailscale IP — nothing is exposed to the public internet. Works on **macOS and Linux**, from anywhere, not just your home WiFi, as long as your machine is awake.

## Cost

This entire setup is free. Every tool used is either open-source or has a free tier:

| Tool | Cost |
|------|------|
| [Tailscale](https://tailscale.com/pricing) | Free for personal use (up to 3 users, 100 devices). Paid plans start at $6/user/month for teams. |
| [ttyd](https://github.com/tsl0922/ttyd) | Free and open-source |
| [tmux](https://github.com/tmux/tmux) | Free and open-source |
| [FastAPI](https://fastapi.tiangolo.com) + [Uvicorn](https://www.uvicorn.org) | Free and open-source |
| Claude Code CLI | Requires an [Anthropic API plan](https://www.anthropic.com/pricing) (usage-based) |

The only ongoing cost is your existing Claude Code API usage — the remote access layer itself adds nothing.

## Prerequisites

- **macOS** (Apple Silicon or Intel) or **Linux** (x86_64 / arm64)
- [Homebrew](https://brew.sh) (macOS) or your distro's package manager (Linux)
- [Tailscale](https://tailscale.com) account + app installed on your machine and phone (free personal plan works)
- Python 3.9+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated

## Set Up with Claude Code

If you have [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed, you can have it walk you through the setup. Just clone the repo, open Claude Code in the directory, and ask:

```
Help me install and set up claude-code-remote
```

The included `CLAUDE.md` gives Claude Code all the context it needs to check your prerequisites, configure the scripts for your machine, and get everything running.

## Step-by-Step Setup

If you prefer to do it manually, follow these steps:

### 1. Install dependencies

**macOS:**

```bash
brew install ttyd tmux
pip3 install fastapi uvicorn python-multipart
```

**Linux (Debian/Ubuntu):**

```bash
sudo apt install ttyd tmux
pip3 install fastapi uvicorn python-multipart
```

### 2. Set up Tailscale

- Install Tailscale on your machine and phone
- Sign in on both devices with the same account
- Verify they can see each other:

```bash
tailscale ip -4
```

This prints your machine's Tailscale IP (like `100.x.y.z`). Save this — you'll need it.

### 3. Clone this repo

```bash
git clone https://github.com/buckle42/claude-code-remote.git
cd claude-code-remote
```

### 4. Test it

Start everything:

```bash
./scripts/start-remote-cli.sh
```

You should see output like:

```
Tailscale IP: 100.x.y.z
caffeinate running (PID: 12345)
ttyd running (PID: 12346) on http://100.x.y.z:7681
voice wrapper running (PID: 12347) on http://100.x.y.z:8080

=== Remote CLI Ready ===
Terminal:  http://100.x.y.z:7681
Voice UI:  http://100.x.y.z:8080
```

On your phone (with Tailscale active), open the Voice UI URL in your browser. You should see a terminal with Claude Code ready to go.

To stop:

```bash
./scripts/stop-remote-cli.sh
```

### 5. Set up auto-start (optional)

#### macOS (launchd)

If you want everything to start automatically when your Mac boots:

1. Edit `scripts/remote-cli.plist` — replace every `YOUR_USERNAME` with your macOS username
2. Copy scripts to a location outside `~/Documents/` (macOS restricts launchd access to `~/Documents/` due to TCC):

```bash
mkdir -p ~/.local/bin/remote-cli
cp scripts/* ~/.local/bin/remote-cli/
chmod +x ~/.local/bin/remote-cli/*.sh
```

3. Install the launch agent:

```bash
cp scripts/remote-cli.plist ~/Library/LaunchAgents/com.user.remote-cli.plist
launchctl load ~/Library/LaunchAgents/com.user.remote-cli.plist
```

To unload later:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.remote-cli.plist
```

#### Linux (systemd)

1. Edit `scripts/remote-cli.service` — replace every `YOUR_USERNAME` with your Linux username
2. Copy scripts:

```bash
mkdir -p ~/.local/bin/remote-cli
cp scripts/* ~/.local/bin/remote-cli/
chmod +x ~/.local/bin/remote-cli/*.sh
```

3. Install and enable the user service:

```bash
mkdir -p ~/.config/systemd/user
cp scripts/remote-cli.service ~/.config/systemd/user/remote-cli.service
systemctl --user daemon-reload
systemctl --user enable --now remote-cli
```

To stop and disable later:

```bash
systemctl --user disable --now remote-cli
```

## Usage Tips

| Action | How |
|--------|-----|
| **Voice dictation** | Use the text input field at the bottom of the Voice UI — iOS dictation works natively there. Avoid dictating directly into the terminal (the raw xterm.js terminal duplicates text due to IME handling). |
| **Quick keys** | The button bar gives you tap targets for arrow keys, Tab, Esc, Ctrl+C, Enter, and Clear — keys that are hard to hit on a phone keyboard. |
| **Switch to your desktop** | Open any terminal on your machine and run `tmux attach -t claude` to pick up the exact same session you were using on your phone. Both screens mirror each other. |
| **Resume on your phone** | Hit the **Resume** button in the Voice UI to reconnect to a previous Claude Code conversation. If the resume screen gets stuck, press **Ctrl+C** twice to exit the Claude session, then hit **New** to start fresh. |
| **New session** | Hit the **New** button to close the current Claude session and start a fresh one. |
| **Copy output** | Hit **Copy** to open a scrollable text view of the full terminal output. You can scroll all the way up and down through the response, then long-press to select and copy. |
| **Auto-reconnect** | When your phone wakes from sleep, the terminal iframe reloads automatically. No manual refresh needed. |

## Security

All services bind exclusively to the Tailscale interface IP — they are unreachable from the public internet and from your local network. Tailscale creates a peer-to-peer [WireGuard](https://www.wireguard.com/) encrypted tunnel between your devices, and every device on your tailnet must be authenticated via SSO. No ports are forwarded or exposed publicly.

**Trade-off to be aware of:** This setup gives full terminal access to your machine. Anyone with access to your Tailscale account could interact with your shell. If you want to limit access to just Claude Code (no raw shell), see the Future Ideas section below.

**Note on ttyd auth:** ttyd supports basic auth via the `--credential` flag, which would add another layer on top of Tailscale. We haven't gotten it working reliably yet (it was causing connection failures), but it's on the list to revisit.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| ttyd won't start | Check if port 7681 is already in use: `lsof -i :7681` |
| Can't connect from phone | Verify Tailscale is active on both devices: `tailscale status` |
| Voice dictation duplicates text | Use the Voice Wrapper UI (`:8080`), not the raw terminal (`:7681`) |
| launchd can't access ~/Documents/ (macOS) | Copy scripts to `~/.local/bin/remote-cli/` (outside TCC-protected paths) |
| systemd service won't start (Linux) | Check logs with `journalctl --user -u remote-cli` and ensure Tailscale is running |
| Claude Code env vars conflict | The `tmux-attach.sh` wrapper handles this automatically by unsetting them |
| Connection drops when phone sleeps | Just reopen the page — auto-reconnect reloads the terminal |

## How It Works

**Tailscale** creates an encrypted peer-to-peer tunnel between your phone and your machine using the WireGuard protocol. It requires zero network configuration — no port forwarding, no dynamic DNS, no firewall rules. The free tier covers personal use.

**ttyd** turns any terminal command into a web page served over HTTP and WebSocket. In this setup, it serves a tmux session so you get a full interactive terminal in your phone's browser.

**tmux** is a terminal multiplexer that keeps your Claude Code session alive even when you disconnect. Close your browser, lose your connection, or switch devices — reconnect anytime and pick up exactly where you left off.

**Voice Wrapper** is a FastAPI app that wraps the ttyd terminal in a mobile-friendly page. It exists because iOS voice dictation pastes duplicate words when you dictate directly into the raw terminal (an xterm.js IME handling issue). The wrapper sidesteps this with a native text input field where dictation works correctly, then sends the text to tmux. It also adds quick-action buttons for common keys and auto-reconnect logic so the terminal reloads when your phone wakes from sleep.

**Sleep inhibitor** keeps your machine awake while the services are running. On macOS this uses `caffeinate`; on Linux it uses `systemd-inhibit`. If neither is available the script continues without it.

**Service manager** can auto-start everything on boot and restart services if they crash. On macOS, the included `remote-cli.plist` works with launchd. On Linux, `remote-cli.service` works with systemd.

## Future Ideas

- Custom web chat UI wrapping `claude --output-format stream-json` (no raw terminal exposure)
- Voice assistant mode with Web Speech API for true hands-free operation
- Status dashboard showing active sessions and resource usage
