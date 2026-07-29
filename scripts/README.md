# Scripts

Automation scripts for OpenClaw Agent.

## Setup & Verification

| Script | Purpose |
|--------|---------|
| `setup-wsl.sh` | **Main setup script** - Installs all dependencies (Docker, Node.js, SSH, etc.) |
| `verify-environment.sh` | Checks if environment is ready to run agents |
| `test-agents.sh` | Test individual workers or start interactive CLI |

## Runtime

| Script | Purpose |
|--------|---------|
| `start-openclaw.sh` | Starts OpenClaw Gateway with Docker |
| `start-vnc.sh` | Starts Xvfb + x11vnc + noVNC (used inside container) |
| `start-openclaw-with-vnc.sh` | Starts both VNC and Gateway (container entrypoint) |

## Usage

### Fresh WSL Setup

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run setup (one-time)
./scripts/setup-wsl.sh

# Verify everything is ready
./scripts/verify-environment.sh

# Start OpenClaw
./scripts/start-openclaw.sh
```

### Daily Use

```bash
# Start
./scripts/start-openclaw.sh

# Or manually
cd docker && docker compose up -d

# Stop
cd docker && docker compose down
```

## What setup-wsl.sh Does

1. **System packages**: curl, git, build-essential, etc.
2. **Docker**: Docker CE + Docker Compose
3. **Node.js**: v20 LTS
4. **SSH keys**: Generates ed25519 key for GitHub
5. **Directories**: Creates ~/.openclaw structure
6. **Environment**: Creates docker/.env config
7. **Docker image**: Builds openclaw-ssh:latest
