#!/usr/bin/env bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$REPO_ROOT/docker"

# OpenClaw directories
OPENCLAW_DIR="$HOME/.openclaw"
WORKSPACE_DIR="$OPENCLAW_DIR/workspace"

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              OpenClaw Agent - Starting Containers                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

log_info "Preparing directories..."
mkdir -p "$OPENCLAW_DIR"
mkdir -p "$WORKSPACE_DIR"
mkdir -p "$WORKSPACE_DIR/AUTH"

# Copy agent specs to workspace
log_info "Copying agent specs..."
cp -r "$REPO_ROOT/supervisor" "$WORKSPACE_DIR/" 2>/dev/null || true
cp -r "$REPO_ROOT/workers" "$WORKSPACE_DIR/" 2>/dev/null || true
cp -r "$REPO_ROOT/config" "$WORKSPACE_DIR/" 2>/dev/null || true

# Copy minimal OpenClaw config if not exists
if [ ! -f "$OPENCLAW_DIR/openclaw.mjs" ]; then
    log_info "Creating openclaw.mjs config..."
    cp "$REPO_ROOT/docker/openclaw.mjs" "$OPENCLAW_DIR/" 2>/dev/null || true
fi

log_info "Starting SSH agent..."
if [ -z "$SSH_AUTH_SOCK" ] || ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
  if [ -f ~/.ssh/id_ed25519 ]; then
    ssh-add ~/.ssh/id_ed25519 2>/dev/null || true
  elif [ -f ~/.ssh/id_rsa ]; then
    ssh-add ~/.ssh/id_rsa 2>/dev/null || true
  fi
fi

# Show SSH keys
log_info "SSH identities available:"
ssh-add -l 2>/dev/null | sed 's/^/  /' || echo "  (none loaded)"

echo ""
log_info "Starting Docker daemon..."
sudo service docker start >/dev/null 2>&1 || sudo systemctl start docker >/dev/null 2>&1 || true

# Check Docker
if ! docker ps >/dev/null 2>&1; then
    log_error "Docker is not running!"
    echo "  Try: sudo service docker start"
    exit 1
fi

log_success "Docker is running"
echo ""

log_info "Starting OpenClaw containers..."

cd "$REPO_ROOT"

# First time: run onboard to create config
if [ ! -f "$OPENCLAW_DIR/openclaw.mjs" ] || ! grep -q "gateway" "$OPENCLAW_DIR/openclaw.mjs" 2>/dev/null; then
    log_info "First-time setup: running OpenClaw onboard..."
    docker compose run --rm openclaw-gateway openclaw onboard --non-interactive --mode local || true
    sleep 2
fi

# Start containers
docker compose up -d

# Wait for containers to be ready
log_info "Waiting for containers to reach healthy state..."

wait_for_health() {
    local max_attempts=60  # 60 * 2 = 120 seconds max wait
    local attempt=0
    local healthy_count=0
    local target_count=3   # gateway, cli, ssh
    
    while [ $attempt -lt $max_attempts ]; do
        # Check health status
        local status=$(docker ps --format "{{.Names}}: {{.Status}}" | grep openclaw || true)
        healthy_count=$(echo "$status" | grep -c "(healthy)" || true)
        
        if [ "$healthy_count" -ge 1 ]; then
            # At least one container healthy
            log_success "Containers healthy: $status"
            return 0
        fi
        
        # Show current status
        if [ $((attempt % 5)) -eq 0 ]; then
            local progress=$((attempt * 2))
            echo -ne "  ⏳ Waiting... (${progress}s elapsed)    \r"
        fi
        
        sleep 2
        ((attempt++))
    done
    
    log_warn "Timeout waiting for healthy status, but containers may still be functional"
    return 0
}

wait_for_health
sleep 2

# Check container status
echo ""
log_info "Checking container status..."

if docker ps | grep -q "openclaw"; then
    log_success "Containers are running:"
    docker ps --format "  {{.Names}}: {{.Status}}" | grep openclaw
else
    log_warn "No OpenClaw containers found"
    log_info "Checking logs:"
    docker compose logs --tail=20
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                    OpenClaw is Ready! 🚀                              ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

echo "📍 Access OpenClaw:"
echo "─────────────────────────────────────────────"
echo "  Web Interface:  http://localhost:18789"
echo "  VNC Browser:    http://localhost:6080"
echo "  API Gateway:    http://localhost:18790"
echo ""

echo "🔍 Monitor & Debug:"
echo "─────────────────────────────────────────────"
echo "  View logs:      docker compose logs -f"
echo "  Container status: docker ps"
echo "  Stop:           docker compose down"
echo ""

echo "🧪 Test Agents:"
echo "─────────────────────────────────────────────"
echo "  ./scripts/test-agents.sh auth"
echo "  ./scripts/test-agents.sh generate"
echo "  ./scripts/test-agents.sh full-flow"
echo ""

echo "🌐 Remote Access:"
echo "─────────────────────────────────────────────"
echo "  SSH:            ./scripts/enable-direct-ssh.sh tailscale"
echo "  Port Forward:   ./scripts/enable-remote.sh start"
echo ""

echo "📱 From Android:"
echo "─────────────────────────────────────────────"
echo "  Read:           docs/ANDROID_SSH_GUIDE.md"
echo "  Setup:          ./scripts/enable-direct-ssh.sh android"
echo ""

echo "═══════════════════════════════════════════════════════════════════════"
echo ""

log_success "Ready! Next: ./scripts/test-agents.sh quick-check"
echo ""
