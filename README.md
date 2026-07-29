# OpenClaw Agent

Multi-agent system for automated MCP server development and publishing.

## Quick Start (WSL)

```bash
# 1. Clone the repository
git clone https://github.com/phanhuycuong33-alt/openclaw_agent.git
cd openclaw_agent

# 2. Run setup script (installs all dependencies)
chmod +x scripts/setup-wsl.sh
./scripts/setup-wsl.sh

# 3. Verify environment
./scripts/verify-environment.sh

# 4. Start OpenClaw
./scripts/start-openclaw.sh
```

## What Gets Installed

The setup script automatically installs:

| Component | Purpose |
|-----------|---------|
| Docker CE | Container runtime |
| Docker Compose | Multi-container orchestration |
| Node.js 20 | JavaScript runtime |
| Git | Version control |
| SSH keys | GitHub authentication |
| Xvfb | Virtual display |
| x11vnc | VNC server |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       SUPERVISOR                            │
│                   (Orchestrates Workers)                    │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┬─────────────┐
        ▼             ▼             ▼             ▼
┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐
│  Worker   │  │  Worker   │  │  Worker   │  │  Worker   │
│   Auth    │  │ Generate  │  │  Publish  │  │  Report   │
│           │  │   Code    │  │   MCP     │  │           │
└───────────┘  └───────────┘  └───────────┘  └───────────┘
```

### Workers

- **Worker Auth**: Manages browser authentication sessions
- **Worker Generate Code**: Creates MCP server projects from tasks
- **Worker Publish MCP**: Publishes MCP servers to marketplaces via browser automation
- **Worker Report**: Standardized reporting format

## Ports

| Port | Service |
|------|---------|
| 18789 | OpenClaw Gateway |
| 18790 | Gateway Bridge |
| 6080 | VNC/noVNC (browser view) |
| 3978 | MS Teams integration |

## Directory Structure

```
~/.openclaw/              # OpenClaw config and state
~/.openclaw/workspace/    # Workspace for projects
~/.openclaw-auth-profile-secrets/  # Auth profiles
```

## Troubleshooting

### Docker permission denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### GitHub SSH not working
```bash
# Start SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Test connection
ssh -T git@github.com
```

### Verify environment
```bash
./scripts/verify-environment.sh
```

## License

See LICENSE file.



