#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$REPO_ROOT/docker"

# OpenClaw directories
OPENCLAW_DIR="$HOME/.openclaw"
WORKSPACE_DIR="$OPENCLAW_DIR/workspace"

echo "=== Preparing directories ==="
mkdir -p "$OPENCLAW_DIR"
mkdir -p "$WORKSPACE_DIR"
mkdir -p "$WORKSPACE_DIR/AUTH"

# Copy agent specs to workspace (not openclaw.json - let OpenClaw create default)
echo "Copying agent specs..."
cp -r "$REPO_ROOT/supervisor" "$WORKSPACE_DIR/" 2>/dev/null || true
cp -r "$REPO_ROOT/workers" "$WORKSPACE_DIR/" 2>/dev/null || true
cp -r "$REPO_ROOT/config" "$WORKSPACE_DIR/" 2>/dev/null || true

# Copy minimal OpenClaw config if not exists
if [ ! -f "$OPENCLAW_DIR/openclaw.mjs" ]; then
    cp "$REPO_ROOT/docker/openclaw.mjs" "$OPENCLAW_DIR/" 2>/dev/null || true
    echo "Created openclaw.mjs config"
fi
echo "Done"

echo "=== Starting SSH agent ==="
if [ -z "$SSH_AUTH_SOCK" ] || ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
  if [ -f ~/.ssh/id_ed25519 ]; then
    ssh-add ~/.ssh/id_ed25519 2>/dev/null || true
  elif [ -f ~/.ssh/id_rsa ]; then
    ssh-add ~/.ssh/id_rsa 2>/dev/null || true
  fi
fi
echo "=== SSH identities ==="
ssh-add -l 2>/dev/null || echo "No SSH keys loaded"

echo "=== Starting Docker ==="
sudo service docker start >/dev/null 2>&1 || true

echo "=== Starting OpenClaw ==="
cd "$DOCKER_DIR"

# First time: run onboard to create config
if [ ! -f "$OPENCLAW_DIR/openclaw.mjs" ] || ! grep -q "gateway" "$OPENCLAW_DIR/openclaw.mjs" 2>/dev/null; then
    echo "Running OpenClaw onboard (first time setup)..."
    docker compose run --rm openclaw-gateway openclaw onboard --non-interactive --mode local || true
fi

docker compose up -d

echo ""
echo "=== OpenClaw Ready ==="
echo ""
echo "  Web Interface:  http://localhost:18789"
echo "  VNC Browser:    http://localhost:6080"
echo ""
echo "  View logs:      docker compose logs -f"
echo "  Stop:           docker compose down"
echo ""
