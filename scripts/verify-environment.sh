#!/usr/bin/env bash
#
# OpenClaw Agent - Environment Verification Script
# Kiểm tra xem môi trường đã sẵn sàng để chạy agent chưa
#
# Usage: ./scripts/verify-environment.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check_pass() { echo -e "${GREEN}[✓]${NC} $1"; ((PASS++)); }
check_fail() { echo -e "${RED}[✗]${NC} $1"; ((FAIL++)); }
check_warn() { echo -e "${YELLOW}[!]${NC} $1"; ((WARN++)); }
check_info() { echo -e "${BLUE}[i]${NC} $1"; }

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║           OpenClaw Agent - Environment Verification                   ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. SYSTEM
# =============================================================================

echo "▸ System"
echo "─────────────────────────────────────────────"

# WSL Check
if grep -qi microsoft /proc/version 2>/dev/null; then
    check_pass "Running in WSL"
else
    check_warn "Not running in WSL (may still work)"
fi

# User
if [ "$EUID" -ne 0 ]; then
    check_pass "Running as non-root user: $USER"
else
    check_fail "Running as root (not recommended)"
fi

echo ""

# =============================================================================
# 2. DOCKER
# =============================================================================

echo "▸ Docker"
echo "─────────────────────────────────────────────"

# Docker installed
if command -v docker &> /dev/null; then
    check_pass "Docker installed: $(docker --version | cut -d' ' -f3 | tr -d ',')"
else
    check_fail "Docker not installed"
fi

# Docker running
if docker info &>/dev/null 2>&1; then
    check_pass "Docker daemon running"
else
    check_fail "Docker daemon not running or not accessible"
fi

# Docker group
if groups | grep -q docker; then
    check_pass "User in docker group"
else
    check_warn "User not in docker group (may need sudo)"
fi

# Docker Compose
if docker compose version &>/dev/null 2>&1; then
    check_pass "Docker Compose available: $(docker compose version --short)"
else
    check_fail "Docker Compose not available"
fi

# OpenClaw image
if docker image inspect openclaw-ssh:latest &>/dev/null 2>&1; then
    check_pass "openclaw-ssh:latest image exists"
else
    check_warn "openclaw-ssh:latest image not built yet"
fi

# Base image
if docker image inspect ghcr.io/openclaw/openclaw:latest &>/dev/null 2>&1; then
    check_pass "Base OpenClaw image exists"
else
    check_warn "Base OpenClaw image not pulled"
fi

echo ""

# =============================================================================
# 3. NODE.JS
# =============================================================================

echo "▸ Node.js"
echo "─────────────────────────────────────────────"

if command -v node &> /dev/null; then
    NODE_VER=$(node --version | tr -d 'v')
    NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 18 ]; then
        check_pass "Node.js version: $NODE_VER"
    else
        check_warn "Node.js version $NODE_VER (recommend 18+)"
    fi
else
    check_warn "Node.js not installed (only needed for local development)"
fi

if command -v npm &> /dev/null; then
    check_pass "npm available: $(npm --version)"
else
    check_warn "npm not available"
fi

echo ""

# =============================================================================
# 4. GIT & SSH
# =============================================================================

echo "▸ Git & SSH"
echo "─────────────────────────────────────────────"

# Git
if command -v git &> /dev/null; then
    check_pass "Git installed: $(git --version | cut -d' ' -f3)"
else
    check_fail "Git not installed"
fi

# Git config
GIT_USER=$(git config --global user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ]; then
    check_pass "Git configured: $GIT_USER <$GIT_EMAIL>"
else
    check_warn "Git user not configured"
fi

# SSH key
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    check_pass "SSH key exists: ~/.ssh/id_ed25519"
elif [ -f "$HOME/.ssh/id_rsa" ]; then
    check_pass "SSH key exists: ~/.ssh/id_rsa"
else
    check_fail "No SSH key found"
fi

# SSH Agent
if [ -n "$SSH_AUTH_SOCK" ]; then
    IDENTITIES=$(ssh-add -l 2>/dev/null | wc -l || echo "0")
    if [ "$IDENTITIES" -gt 0 ]; then
        check_pass "SSH agent running with $IDENTITIES key(s)"
    else
        check_warn "SSH agent running but no keys loaded"
    fi
else
    check_warn "SSH agent not running"
fi

# GitHub SSH
check_info "Testing GitHub SSH..."
GH_RESULT=$(ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 || true)
if echo "$GH_RESULT" | grep -q "successfully authenticated"; then
    check_pass "GitHub SSH authentication works"
elif echo "$GH_RESULT" | grep -q "Permission denied"; then
    check_fail "GitHub SSH authentication failed"
else
    check_warn "GitHub SSH test inconclusive"
fi

echo ""

# =============================================================================
# 5. DIRECTORIES
# =============================================================================

echo "▸ OpenClaw Directories"
echo "─────────────────────────────────────────────"

DIRS=(
    "$HOME/.openclaw"
    "$HOME/.openclaw/workspace"
    "$HOME/.openclaw-auth-profile-secrets"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        check_pass "Directory exists: $dir"
    else
        check_fail "Directory missing: $dir"
    fi
done

echo ""

# =============================================================================
# 6. CONFIGURATION FILES
# =============================================================================

echo "▸ Configuration"
echo "─────────────────────────────────────────────"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$REPO_ROOT/docker/.env"

if [ -f "$ENV_FILE" ]; then
    check_pass ".env file exists: docker/.env"
else
    check_warn ".env file missing (will use defaults)"
fi

if [ -f "$REPO_ROOT/docker/docker-compose.yml" ]; then
    check_pass "docker-compose.yml exists"
else
    check_fail "docker-compose.yml missing"
fi

echo ""

# =============================================================================
# 7. PORTS
# =============================================================================

echo "▸ Ports"
echo "─────────────────────────────────────────────"

check_port() {
    local port=$1
    local name=$2
    if command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            check_warn "Port $port ($name) already in use"
        else
            check_pass "Port $port ($name) available"
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            check_warn "Port $port ($name) already in use"
        else
            check_pass "Port $port ($name) available"
        fi
    else
        check_info "Port $port ($name) - cannot verify"
    fi
}

check_port 18789 "Gateway"
check_port 18790 "Bridge"
check_port 6080 "VNC/noVNC"
check_port 3978 "MS Teams"

echo ""

# =============================================================================
# SUMMARY
# =============================================================================

echo "═══════════════════════════════════════════════════════════════════════"
echo ""

TOTAL=$((PASS + FAIL + WARN))

echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✓ Environment is ready!${NC}"
    echo ""
    echo "Start OpenClaw with:"
    echo "  cd docker && docker compose up -d"
    echo ""
    echo "Or use:"
    echo "  ./scripts/start-openclaw.sh"
    exit 0
else
    echo -e "${RED}✗ Environment has issues that need to be fixed.${NC}"
    echo ""
    echo "Run the setup script:"
    echo "  ./scripts/setup-wsl.sh"
    exit 1
fi
