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

# Parse arguments
GATEWAY_MODE=false
if [ "$1" = "--gateway" ]; then
    GATEWAY_MODE=true
    echo "[INFO] Using GATEWAY mode (with web interface)"
else
    echo "[INFO] Using LOCAL mode (CLI only, no web gateway)"
    echo "       Tip: Use './scripts/start-openclaw.sh --gateway' for web mode"
fi
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

# Select compose file based on mode
COMPOSE_FILE="docker-compose.yml"  # Local mode (default)
if [ "$GATEWAY_MODE" = true ]; then
    COMPOSE_FILE="docker-compose-gateway.yml"
fi

# Function: Check and cleanup port conflicts
check_and_cleanup_ports() {
    log_info "Checking for port conflicts..."
    
    # Aggressively cleanup first (better than selective stop)
    log_info "Cleaning up previous containers..."
    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true
    sleep 3  # Give OS time to release port
    
    # Check if port 2222 is still in use (our new SSH port)
    if lsof -i :2222 >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ":2222 "; then
        log_warn "Port 2222 is still in use by another process!"
        
        # Try to identify what's using it
        local pid=$(lsof -t -i :2222 2>/dev/null || true)
        if [ -n "$pid" ]; then
            log_warn "Process using port 2222: PID=$pid"
            local proc=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            log_warn "Process name: $proc"
        fi
        
        echo "  Options:"
        echo "    1. Stop the process: sudo kill -9 $pid"
        echo "    2. Use different port: Edit docker-compose.yml, change '2222:22' to 'XXXX:22'"
        echo "    3. Restart WSL: wsl --shutdown"
        return 1
    fi
    
    return 0
}

# Run cleanup checks
if ! check_and_cleanup_ports; then
    echo ""
    log_error "Port 22 still in use. Cannot start OpenClaw."
    exit 1
fi

# First time: run onboard to create config (only for gateway mode)
if [ "$GATEWAY_MODE" = true ]; then
    if [ ! -f "$OPENCLAW_DIR/openclaw.mjs" ] || ! grep -q "gateway" "$OPENCLAW_DIR/openclaw.mjs" 2>/dev/null; then
        log_info "First-time setup: running OpenClaw onboard..."
        docker compose -f "$COMPOSE_FILE" run --rm openclaw-gateway openclaw onboard --non-interactive --mode local || true
        sleep 2
    fi
fi

# Start containers
log_info "Starting containers (port 22 should now be available)..."
docker compose -f "$COMPOSE_FILE" up -d

# Wait for containers to be ready
log_info "Waiting for containers to reach healthy state..."

wait_for_health() {
    local max_attempts=60  # 60 * 2 = 120 seconds max wait
    local attempt=0
    local healthy_count=0
    local target_count=2   # cli + ssh (or gateway + cli + ssh in gateway mode)
    
    while [ $attempt -lt $max_attempts ]; do
        # Check health status
        if [ "$GATEWAY_MODE" = true ]; then
            local status=$(docker compose -f "$COMPOSE_FILE" ps --format "{{.Names}}: {{.Status}}" | grep openclaw || true)
            healthy_count=$(echo "$status" | grep -c "(healthy)" || true)
        else
            # Local mode: just check if containers are running
            local status=$(docker compose -f "$COMPOSE_FILE" ps --format "{{.Names}}: {{.Status}}" | grep openclaw || true)
            healthy_count=$(echo "$status" | grep -c "Up" || true)
        fi
        
        if [ "$healthy_count" -ge 1 ]; then
            # At least one container healthy or running
            log_success "Containers ready: $status"
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

if docker compose -f "$COMPOSE_FILE" ps | grep -q "openclaw"; then
    log_success "Containers are running:"
    docker compose -f "$COMPOSE_FILE" ps --format "  {{.Names}}: {{.Status}}"
else
    log_warn "No OpenClaw containers found"
    log_info "Checking logs:"
    docker compose -f "$COMPOSE_FILE" logs --tail=20
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                    OpenClaw is Ready! 🚀                              ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$GATEWAY_MODE" = true ]; then
    echo "📍 Access OpenClaw (Gateway Mode):"
    echo "─────────────────────────────────────────────"
    echo "  Web Interface:  http://localhost:18789"
    echo "  VNC Browser:    http://localhost:6080"
    echo "  API Gateway:    http://localhost:18790"
    echo ""
else
    echo "📍 Local Mode (CLI only - no web interface)"
    echo "─────────────────────────────────────────────"
    echo "  SSH Access:     localhost:2222"
    echo "  Command line:   ./scripts/run-agent.sh"
    echo ""
fi

echo "🔍 Monitor & Debug:"
echo "─────────────────────────────────────────────"
if [ "$GATEWAY_MODE" = true ]; then
    echo "  View logs:      docker compose -f docker-compose-gateway.yml logs -f"
else
    echo "  View logs:      docker compose logs -f"
fi
echo "  Container status: docker ps"
echo "  Stop:           docker compose down"
echo ""

echo "🧪 Test Agents:"
echo "─────────────────────────────────────────────"
echo "  ./scripts/run-agent.sh auth"
echo "  ./scripts/run-agent.sh generate"
echo "  ./scripts/run-agent.sh full-flow"
echo ""

if [ "$GATEWAY_MODE" = false ]; then
    echo "🌐 Switch to Gateway Mode:"
    echo "─────────────────────────────────────────────"
    echo "  docker compose down"
    echo "  ./scripts/start-openclaw.sh --gateway"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════════════"
echo ""

log_success "Ready! Next: ./scripts/run-agent.sh auth"
echo ""
