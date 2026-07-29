# OpenClaw Agent

Multi-agent system for automated MCP server development and publishing.

## Quick Start (WSL)

### Lần đầu tiên (Setup 1 lần)

```bash
# 1. Clone repository
git clone https://github.com/phanhuycuong33-alt/openclaw_agent.git
cd openclaw_agent

# 2. Run setup (cài Docker, Node, SSH, config API key)
chmod +x scripts/*.sh
./scripts/setup-wsl.sh

# 3. Start OpenClaw
./scripts/start-openclaw.sh

# 4. Test agents
./scripts/test-agents.sh
```

### Các lần sau (Daily use)

```bash
cd openclaw_agent

# 1. Pull latest changes
git pull

# 2. Start OpenClaw  
./scripts/start-openclaw.sh

# 3. Test/Use agents
./scripts/test-agents.sh        # Check environment
./scripts/test-agents.sh auth   # Test GitHub auth
./scripts/test-agents.sh cli    # Chat with Supervisor
```

### Dừng OpenClaw

```bash
cd docker && docker compose down
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
| AI API Key | Anthropic/OpenAI for agents |

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



