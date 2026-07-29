#!/usr/bin/env bash
#
# OpenClaw Agent - WSL Setup Script
# Chạy script này sau khi clone repo để cài đặt tất cả dependencies
#
# Usage: ./scripts/setup-wsl.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║           OpenClaw Agent - WSL Environment Setup                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running in WSL
if ! grep -qi microsoft /proc/version 2>/dev/null; then
    log_warn "This script is designed for WSL. Detected non-WSL environment."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Do not run this script as root. Run as normal user."
    exit 1
fi

# =============================================================================
# STEP 1: SYSTEM PACKAGES
# =============================================================================

log_info "Step 1/8: Updating system packages..."

sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Essential packages
PACKAGES=(
    # Build essentials
    build-essential
    curl
    wget
    git
    ca-certificates
    gnupg
    lsb-release
    
    # SSH
    openssh-client
    
    # Display/VNC (for local mode without Docker)
    xvfb
    x11vnc
    
    # Python (for some tools)
    python3
    python3-pip
    
    # Utilities
    jq
    unzip
    htop
    net-tools
)

log_info "Installing required packages..."
sudo apt-get install -y -qq "${PACKAGES[@]}"
log_success "System packages installed"

# =============================================================================
# STEP 2: DOCKER
# =============================================================================

log_info "Step 2/8: Setting up Docker..."

if command -v docker &> /dev/null; then
    log_success "Docker already installed: $(docker --version)"
else
    log_info "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_success "Docker installed"
fi

# Add user to docker group
if ! groups | grep -q docker; then
    log_info "Adding user to docker group..."
    sudo usermod -aG docker "$USER"
    log_warn "You may need to log out and back in for docker group to take effect"
fi

# Start Docker service
log_info "Starting Docker service..."
sudo service docker start 2>/dev/null || true
sleep 2

# Verify Docker
if docker info &>/dev/null; then
    log_success "Docker is running"
else
    log_warn "Docker may require re-login. Try: newgrp docker"
fi

# =============================================================================
# STEP 3: NODE.JS
# =============================================================================

log_info "Step 3/8: Setting up Node.js..."

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    log_success "Node.js already installed: $NODE_VERSION"
else
    log_info "Installing Node.js 20 LTS..."
    
    # Using NodeSource
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y -qq nodejs
    
    log_success "Node.js installed: $(node --version)"
fi

# Verify npm
if command -v npm &> /dev/null; then
    log_success "npm available: $(npm --version)"
fi

# =============================================================================
# STEP 4: SSH KEYS FOR GITHUB
# =============================================================================

log_info "Step 4/8: Checking SSH keys for GitHub..."

SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
SSH_KEY_EXISTS=false

if [ -f "$SSH_KEY_PATH" ]; then
    log_success "SSH key exists: $SSH_KEY_PATH"
    SSH_KEY_EXISTS=true
elif [ -f "$HOME/.ssh/id_rsa" ]; then
    log_success "SSH key exists: $HOME/.ssh/id_rsa"
    SSH_KEY_PATH="$HOME/.ssh/id_rsa"
    SSH_KEY_EXISTS=true
else
    log_warn "No SSH key found"
    echo ""
    read -p "Generate new SSH key for GitHub? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        read -p "Enter your GitHub email: " github_email
        if [ -n "$github_email" ]; then
            ssh-keygen -t ed25519 -C "$github_email" -f "$SSH_KEY_PATH" -N ""
            log_success "SSH key generated: $SSH_KEY_PATH"
            SSH_KEY_EXISTS=true
            
            echo ""
            log_info "Add this public key to GitHub (https://github.com/settings/keys):"
            echo ""
            cat "${SSH_KEY_PATH}.pub"
            echo ""
            read -p "Press Enter after adding the key to GitHub..."
        fi
    fi
fi

# Configure SSH for GitHub
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if ! grep -q "github.com" "$HOME/.ssh/config" 2>/dev/null; then
    cat >> "$HOME/.ssh/config" << 'EOF'

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    AddKeysToAgent yes
EOF
    chmod 600 "$HOME/.ssh/config"
    log_success "SSH config updated for GitHub"
fi

# Create known_hosts if not exists
if [ ! -f "$HOME/.ssh/known_hosts" ]; then
    ssh-keyscan -t ed25519,rsa github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
    log_success "GitHub added to known_hosts"
fi

# Test GitHub SSH (optional)
if [ "$SSH_KEY_EXISTS" = true ]; then
    log_info "Testing GitHub SSH connection..."
    if ssh -T -o ConnectTimeout=10 -o BatchMode=yes git@github.com 2>&1 | grep -q "successfully authenticated"; then
        log_success "GitHub SSH authentication working"
    else
        log_warn "GitHub SSH test inconclusive - may need manual verification"
    fi
fi

# =============================================================================
# STEP 5: OPENCLAW DIRECTORIES
# =============================================================================

log_info "Step 5/8: Creating OpenClaw directories..."

OPENCLAW_DIRS=(
    "$HOME/.openclaw"
    "$HOME/.openclaw/workspace"
    "$HOME/.openclaw-auth-profile-secrets"
)

for dir in "${OPENCLAW_DIRS[@]}"; do
    mkdir -p "$dir"
    log_success "Created: $dir"
done

# =============================================================================
# STEP 6: ENVIRONMENT CONFIGURATION
# =============================================================================

log_info "Step 6/8: Setting up environment configuration..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$REPO_ROOT/docker"
ENV_FILE="$DOCKER_DIR/.env"

# Create .env file if not exists
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" << EOF
# OpenClaw Agent Environment Configuration
# Generated by setup-wsl.sh on $(date)

# Home directory
HOME=$HOME

# OpenClaw directories
OPENCLAW_CONFIG_DIR=$HOME/.openclaw
OPENCLAW_WORKSPACE_DIR=$HOME/.openclaw/workspace
OPENCLAW_AUTH_PROFILE_SECRET_DIR=$HOME/.openclaw-auth-profile-secrets

# Gateway settings
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_MSTEAMS_PORT=3978

# SSH Agent (auto-detected at runtime)
SSH_AUTH_SOCK=$SSH_AUTH_SOCK

# Timezone
OPENCLAW_TZ=$(cat /etc/timezone 2>/dev/null || echo "UTC")

# Gateway token (generate your own for security)
OPENCLAW_GATEWAY_TOKEN=

# Optional: Disable Bonjour (0=auto, 1=disable)
OPENCLAW_DISABLE_BONJOUR=1
EOF
    log_success "Created: $ENV_FILE"
else
    log_success ".env file already exists"
fi

# =============================================================================
# STEP 7: BUILD DOCKER IMAGE
# =============================================================================

log_info "Step 7/8: Building OpenClaw Docker image..."

if docker info &>/dev/null; then
    cd "$DOCKER_DIR"
    
    # Check if base image exists
    log_info "Pulling base OpenClaw image..."
    if docker pull ghcr.io/openclaw/openclaw:latest; then
        log_success "Base image pulled"
        
        # Copy scripts to docker directory for build context
        cp "$SCRIPT_DIR/start-vnc.sh" "$DOCKER_DIR/" 2>/dev/null || true
        cp "$SCRIPT_DIR/start-openclaw-with-vnc.sh" "$DOCKER_DIR/" 2>/dev/null || true
        
        log_info "Building openclaw-ssh image..."
        if docker build -t openclaw-ssh:latest -f Dockerfile.openclaw-ssh .; then
            log_success "Docker image built: openclaw-ssh:latest"
        else
            log_warn "Docker image build failed - may need manual build"
        fi
    else
        log_warn "Could not pull base image - Docker build skipped"
    fi
    
    cd "$REPO_ROOT"
else
    log_warn "Docker not accessible - skipping image build"
    log_info "Run 'newgrp docker' or re-login, then run: cd docker && docker build -t openclaw-ssh:latest -f Dockerfile.openclaw-ssh ."
fi

# =============================================================================
# STEP 8: AI API CONFIGURATION
# =============================================================================

log_info "Step 8/8: AI API Configuration..."

# Check if API key is already configured
API_CONFIGURED=false
if [ -f "$ENV_FILE" ]; then
    if grep -q "ANTHROPIC_API_KEY=sk-" "$ENV_FILE" 2>/dev/null; then
        log_success "Anthropic API key already configured"
        API_CONFIGURED=true
    elif grep -q "OPENAI_API_KEY=sk-" "$ENV_FILE" 2>/dev/null; then
        log_success "OpenAI API key already configured"
        API_CONFIGURED=true
    fi
fi

if [ "$API_CONFIGURED" = false ]; then
    echo ""
    log_warn "AI API key not configured yet."
    echo ""
    echo "The agents require an AI model API to function."
    echo "Supported providers: Anthropic Claude, OpenAI GPT-4"
    echo ""
    read -p "Do you want to configure an API key now? (Y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        echo "Choose provider:"
        echo "  1) Anthropic Claude (recommended)"
        echo "  2) OpenAI"
        echo "  3) Skip for now"
        echo ""
        read -p "Enter choice [1-3]: " provider_choice
        
        case "$provider_choice" in
            1)
                read -p "Enter Anthropic API key (sk-ant-...): " api_key
                if [ -n "$api_key" ]; then
                    echo "" >> "$ENV_FILE"
                    echo "# AI Model Configuration" >> "$ENV_FILE"
                    echo "ANTHROPIC_API_KEY=$api_key" >> "$ENV_FILE"
                    echo "AGENT_PROVIDER=anthropic" >> "$ENV_FILE"
                    log_success "Anthropic API key saved to docker/.env"
                fi
                ;;
            2)
                read -p "Enter OpenAI API key (sk-...): " api_key
                if [ -n "$api_key" ]; then
                    echo "" >> "$ENV_FILE"
                    echo "# AI Model Configuration" >> "$ENV_FILE"
                    echo "OPENAI_API_KEY=$api_key" >> "$ENV_FILE"
                    echo "AGENT_PROVIDER=openai" >> "$ENV_FILE"
                    log_success "OpenAI API key saved to docker/.env"
                fi
                ;;
            *)
                log_info "Skipped. Add API key later to docker/.env"
                ;;
        esac
    fi
fi

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                         Setup Complete!                               ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

log_success "All dependencies installed!"
echo ""
echo "Installed components:"
echo "  - Docker:    $(docker --version 2>/dev/null || echo 'needs re-login')"
echo "  - Node.js:   $(node --version 2>/dev/null || echo 'not found')"
echo "  - npm:       $(npm --version 2>/dev/null || echo 'not found')"
echo "  - Git:       $(git --version 2>/dev/null || echo 'not found')"
echo ""
echo "Directories created:"
echo "  - $HOME/.openclaw"
echo "  - $HOME/.openclaw/workspace"
echo "  - $HOME/.openclaw-auth-profile-secrets"
echo ""

if ! groups | grep -q docker; then
    echo -e "${YELLOW}⚠ IMPORTANT:${NC} Log out and back in, or run:"
    echo "    newgrp docker"
    echo ""
fi

echo -e "${YELLOW}⚠ REQUIRED:${NC} Configure AI API key before running agents:"
echo "    Edit docker/.env and add your API key:"
echo "    ANTHROPIC_API_KEY=sk-ant-...  (or OPENAI_API_KEY=sk-...)"
echo ""
echo "Next steps:"
echo "  1. Add AI API key to docker/.env (REQUIRED)"
echo "  2. Start OpenClaw:"
echo "     ./scripts/start-openclaw.sh"
echo "  3. Test agents:"
echo "     ./scripts/test-agents.sh"
echo ""
echo "  Or use the quick start script:"
echo "     ./scripts/start-openclaw.sh"
echo ""
echo "Ports:"
echo "  - Gateway:  http://localhost:18789"
echo "  - VNC:      http://localhost:6080"
echo ""
