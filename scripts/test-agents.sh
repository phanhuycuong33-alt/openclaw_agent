#!/usr/bin/env bash
#
# OpenClaw Agent - Test Script
# Test agents với AI model thông qua Supervisor
#
# Usage: ./scripts/test-agents.sh [command]
#

set -e

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
log_task() { echo -e "${CYAN}[TASK]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
GATEWAY_URL="http://localhost:18789"
ENV_FILE="$REPO_ROOT/docker/.env"

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

check_api_key() {
    log_info "Checking AI Model API configuration..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error ".env file not found at docker/.env"
        echo ""
        echo "Create it from template:"
        echo "  cp config/env.example docker/.env"
        echo "  # Then add your API key"
        return 1
    fi
    
    # Source env file
    set -a
    source "$ENV_FILE" 2>/dev/null || true
    set +a
    
    # Check for API keys
    API_CONFIGURED=false
    
    if [ -n "$ANTHROPIC_API_KEY" ] && [ "$ANTHROPIC_API_KEY" != "" ]; then
        log_success "Anthropic API key configured"
        API_CONFIGURED=true
    fi
    
    if [ -n "$OPENAI_API_KEY" ] && [ "$OPENAI_API_KEY" != "" ]; then
        log_success "OpenAI API key configured"
        API_CONFIGURED=true
    fi
    
    if [ -n "$DEEPSEEK_API_KEY" ] && [ "$DEEPSEEK_API_KEY" != "" ]; then
        log_success "DeepSeek API key configured"
        API_CONFIGURED=true
    fi
    
    if [ -n "$AZURE_OPENAI_API_KEY" ] && [ "$AZURE_OPENAI_API_KEY" != "" ]; then
        log_success "Azure OpenAI API key configured"
        API_CONFIGURED=true
    fi
    
    if [ "$API_CONFIGURED" = false ]; then
        log_error "No AI API key configured!"
        echo ""
        echo "Edit docker/.env and add one of:"
        echo "  ANTHROPIC_API_KEY=sk-ant-..."
        echo "  OPENAI_API_KEY=sk-..."
        echo "  DEEPSEEK_API_KEY=sk-..."
        echo ""
        return 1
    fi
    
    return 0
}

check_gateway() {
    log_info "Checking OpenClaw Gateway..."
    
    if curl -s --connect-timeout 5 "$GATEWAY_URL/healthz" > /dev/null 2>&1; then
        log_success "Gateway is running at $GATEWAY_URL"
        return 0
    else
        log_error "Gateway is not running!"
        echo ""
        echo "Start OpenClaw first:"
        echo "  ./scripts/start-openclaw.sh"
        return 1
    fi
}

check_vnc() {
    log_info "Checking VNC..."
    
    if curl -s --connect-timeout 3 "http://localhost:6080" > /dev/null 2>&1; then
        log_success "VNC accessible at http://localhost:6080"
        return 0
    else
        log_warn "VNC not accessible (browser automation may not work)"
        return 1
    fi
}

# =============================================================================
# SUPERVISOR DISPATCH
# =============================================================================

dispatch_to_supervisor() {
    local task="$1"
    local task_id="task_$(date +%s)"
    
    log_task "Dispatching to Supervisor: $task"
    echo ""
    
    # Find container
    CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "openclaw.*gateway" | head -1)
    
    if [ -z "$CONTAINER" ]; then
        log_error "Cannot find OpenClaw Gateway container"
        return 1
    fi
    
    # Create task file for Supervisor
    local task_file="/tmp/supervisor-task-$task_id.md"
    cat > "$task_file" << EOF
# Supervisor Task

Task ID: $task_id
Timestamp: $(date -Iseconds)
User Request: $task

## Instructions

1. Read supervisor/SUPERVISOR_SPEC.md for your role
2. Analyze this task
3. Dispatch to appropriate Worker(s)
4. Wait for Worker result
5. Report back

EOF
    
    # Copy task file to container
    docker cp "$task_file" "$CONTAINER:/home/node/.openclaw/workspace/"
    
    # Execute task via OpenClaw CLI
    log_info "Executing via OpenClaw..."
    echo ""
    echo "─────────────────────────────────────────────"
    
    # Send task to openclaw
    docker exec -it "$CONTAINER" npx openclaw chat --message "$task"
    
    echo "─────────────────────────────────────────────"
    echo ""
    
    # Cleanup
    rm -f "$task_file"
    
    # Check for result files
    log_info "Checking for Worker results..."
    
    for result_file in "worker-auth-result.md" "worker-generate-code-result.md" "worker-publish-mcp-result.md"; do
        if docker exec "$CONTAINER" test -f "/home/node/.openclaw/workspace/$result_file" 2>/dev/null; then
            log_success "Found: $result_file"
            echo ""
            docker exec "$CONTAINER" cat "/home/node/.openclaw/workspace/$result_file"
            echo ""
        fi
    done
}

# =============================================================================
# TEST COMMANDS
# =============================================================================

test_auth() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              Testing Worker Auth via Supervisor                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_api_key || return 1
    check_gateway || return 1
    check_vnc
    
    echo ""
    log_info "This test will:"
    echo "  1. Send task to Supervisor"
    echo "  2. Supervisor dispatches to Worker Auth"
    echo "  3. Worker Auth checks GitHub browser session"
    echo "  4. Worker Auth writes AUTH/github.json"
    echo "  5. Worker Auth writes worker-auth-result.md"
    echo "  6. Supervisor reports result"
    echo ""
    echo "Watch VNC at http://localhost:6080 to see browser"
    echo ""
    read -p "Press Enter to start test..."
    echo ""
    
    dispatch_to_supervisor "Check if GitHub is authenticated. Verify the browser session and report the authentication status."
}

test_generate() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║           Testing Worker Generate Code via Supervisor                 ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_api_key || return 1
    check_gateway || return 1
    
    echo ""
    log_info "This test will:"
    echo "  1. Send task to Supervisor"
    echo "  2. Supervisor dispatches to Worker Generate Code"
    echo "  3. Worker generates a minimal MCP server"
    echo "  4. Worker writes worker-generate-code-result.md"
    echo "  5. Supervisor reports result"
    echo ""
    read -p "Press Enter to start test..."
    echo ""
    
    dispatch_to_supervisor "Generate a simple MCP server called 'hello-test-mcp' with one tool named 'hello_test' that returns 'Hello from test MCP!'"
}

test_full_flow() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              Full Flow Test: Auth → Generate → Publish                ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_api_key || return 1
    check_gateway || return 1
    check_vnc
    
    echo ""
    log_info "This test will run the full agent pipeline:"
    echo "  1. Supervisor checks authentication (Worker Auth)"
    echo "  2. Supervisor generates MCP project (Worker Generate Code)"
    echo "  3. Supervisor publishes to GitHub (Worker Publish MCP)"
    echo ""
    log_warn "This is a comprehensive test and may take several minutes."
    echo ""
    read -p "Press Enter to start full flow test..."
    echo ""
    
    dispatch_to_supervisor "Create a simple MCP server called 'test-flow-mcp' with a 'hello' tool, then publish it to GitHub. First verify GitHub authentication."
}

quick_check() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                    Quick Environment Check                            ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # API Key
    check_api_key
    API_OK=$?
    
    # Gateway
    check_gateway  
    GW_OK=$?
    
    # VNC
    check_vnc
    VNC_OK=$?
    
    # Docker
    log_info "Checking Docker containers..."
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "openclaw"; then
        CONTAINERS=$(docker ps --format '{{.Names}}' | grep openclaw | tr '\n' ', ' | sed 's/,$//')
        log_success "Running: $CONTAINERS"
    else
        log_error "No OpenClaw containers running"
    fi
    
    # Auth status
    log_info "Checking authentication status..."
    AUTH_DIR="$REPO_ROOT/AUTH"
    if [ -d "$AUTH_DIR" ]; then
        for auth_file in "$AUTH_DIR"/*.json; do
            if [ -f "$auth_file" ]; then
                provider=$(basename "$auth_file" .json)
                status=$(jq -r '.status // "unknown"' "$auth_file" 2>/dev/null || echo "parse_error")
                if [ "$status" = "authenticated" ]; then
                    log_success "$provider: authenticated"
                else
                    log_warn "$provider: $status"
                fi
            fi
        done
    else
        log_info "No authentication data yet (AUTH/ directory not found)"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    
    if [ $API_OK -eq 0 ] && [ $GW_OK -eq 0 ]; then
        echo ""
        log_success "Environment ready for agent testing!"
        echo ""
        echo "Run a test:"
        echo "  ./scripts/test-agents.sh auth      # Test authentication"
        echo "  ./scripts/test-agents.sh generate  # Test code generation"
        echo "  ./scripts/test-agents.sh flow      # Test full pipeline"
        echo "  ./scripts/test-agents.sh cli       # Interactive mode"
    else
        echo ""
        log_error "Environment not ready. Fix issues above first."
    fi
    echo ""
}

start_cli() {
    echo ""
    log_info "Starting Interactive CLI..."
    
    check_api_key || return 1
    check_gateway || return 1
    
    CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "openclaw.*gateway" | head -1)
    
    if [ -z "$CONTAINER" ]; then
        log_error "Cannot find OpenClaw Gateway container"
        return 1
    fi
    
    echo ""
    echo "Entering interactive chat mode."
    echo "Your messages go to Supervisor who coordinates Workers."
    echo "Type 'exit' or Ctrl+C to quit."
    echo ""
    echo "Example tasks:"
    echo "  - Check GitHub authentication status"
    echo "  - Create a simple MCP server called my-mcp"  
    echo "  - Publish my-mcp to GitHub"
    echo ""
    echo "─────────────────────────────────────────────"
    
    docker exec -it "$CONTAINER" npx openclaw chat
}

# =============================================================================
# MAIN
# =============================================================================

show_help() {
    echo "OpenClaw Agent Test Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  check      Quick environment check (default)"
    echo "  auth       Test Worker Auth (verify GitHub login)"
    echo "  generate   Test Worker Generate Code (create MCP)"
    echo "  flow       Test full pipeline: Auth → Generate → Publish"
    echo "  cli        Interactive chat with Supervisor"
    echo ""
    echo "Prerequisites:"
    echo "  1. Run setup:  ./scripts/setup-wsl.sh"
    echo "  2. Add API key to docker/.env"
    echo "  3. Start OpenClaw: ./scripts/start-openclaw.sh"
    echo ""
}

case "${1:-check}" in
    check)
        quick_check
        ;;
    auth)
        test_auth
        ;;
    generate)
        test_generate
        ;;
    flow)
        test_full_flow
        ;;
    cli)
        start_cli
        ;;
    -h|--help|help)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
