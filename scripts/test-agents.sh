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
CONTAINER=""  # Will be set when needed

# Check required tools
if ! command -v jq &> /dev/null; then
    echo "Warning: jq not installed. Install with: sudo apt install jq"
fi
if ! command -v curl &> /dev/null; then
    echo "Error: curl not installed. Install with: sudo apt install curl"
    exit 1
fi

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
    
    # Find container (try multiple patterns)
    CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE "openclaw|gateway" | head -1)
    
    if [ -z "$CONTAINER" ]; then
        log_error "Cannot find OpenClaw Gateway container"
        log_info "Running containers:"
        docker ps --format '{{.Names}}' 2>/dev/null || echo "(none)"
        return 1
    fi
    
    log_info "Using container: $CONTAINER"
    
    # Read spec files and create full prompt
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(dirname "$SCRIPT_DIR")"
    
    SUPERVISOR_SPEC=$(cat "$REPO_ROOT/supervisor/SUPERVISOR_SPEC.md" 2>/dev/null || echo "")
    WORKER_AUTH_SPEC=$(cat "$REPO_ROOT/workers/WORKER_AUTH.md" 2>/dev/null || echo "")
    WORKER_REPORT_SPEC=$(cat "$REPO_ROOT/workers/WORKER_REPORT_SPEC.md" 2>/dev/null || echo "")
    
    # Create full prompt with specs
    local prompt_file="/tmp/openclaw-prompt-$task_id.txt"
    cat > "$prompt_file" << PROMPT_EOF
You are the Supervisor of an AI agent system. Read the specs below and execute the task.

=== SUPERVISOR SPEC ===
$SUPERVISOR_SPEC

=== WORKER AUTH SPEC ===
$WORKER_AUTH_SPEC

=== WORKER REPORT SPEC ===
$WORKER_REPORT_SPEC

=== TASK ===
$task

=== INSTRUCTIONS ===
1. Execute this task according to your spec
2. Use browser automation if needed (VNC at http://localhost:6080)
3. Write results to the appropriate result file
4. If you need user action (login, approval), clearly state what you need and STOP
5. Do NOT ask unnecessary questions - just execute

BEGIN EXECUTION:
PROMPT_EOF

    log_info "Sending task to OpenClaw API..."
    echo ""
    
    # Send via OpenClaw API (conversation endpoint)
    local response
    response=$(curl -s -X POST "http://localhost:18789/api/conversation" \
        -H "Content-Type: application/json" \
        -d "{\"message\": $(cat "$prompt_file" | jq -Rs .)}" 2>&1)
    
    if [ $? -ne 0 ]; then
        log_warn "API call failed, falling back to CLI..."
        # Copy prompt to container and use CLI
        docker cp "$prompt_file" "$CONTAINER:/tmp/task-prompt.txt"
        docker exec "$CONTAINER" sh -c "cat /tmp/task-prompt.txt | openclaw chat" &
        TASK_PID=$!
        
        echo ""
        echo "─────────────────────────────────────────────"
        log_info "Task running in background (PID: $TASK_PID)"
        log_info "Watch VNC at http://localhost:6080"
        echo "─────────────────────────────────────────────"
        echo ""
        
        # Wait and poll for results
        poll_for_results "$task_id"
    else
        echo "$response" | jq -r '.response // .message // .error // .' 2>/dev/null || echo "$response"
        echo ""
        # API returned, now poll for worker results
        poll_for_results "$task_id"
    fi
    
    # Cleanup
    rm -f "$prompt_file"
}

poll_for_results() {
    local task_id="$1"
    local max_wait=300  # 5 minutes
    local elapsed=0
    local check_interval=5
    
    # Ensure container is set
    if [ -z "$CONTAINER" ]; then
        CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE "openclaw|gateway" | head -1)
    fi
    
    if [ -z "$CONTAINER" ]; then
        log_error "No container found for polling"
        return 1
    fi
    
    log_info "Polling for worker results in container: $CONTAINER"
    
    while [ $elapsed -lt $max_wait ]; do
        # Check if any result file exists
        for result_file in "worker-auth-result.md" "worker-generate-code-result.md" "worker-publish-mcp-result.md"; do
            if docker exec "$CONTAINER" test -f "/home/node/.openclaw/workspace/$result_file" 2>/dev/null; then
                echo ""
                log_success "Found result: $result_file"
                echo ""
                
                # Read and parse result
                local result
                result=$(docker exec "$CONTAINER" cat "/home/node/.openclaw/workspace/$result_file")
                echo "$result"
                echo ""
                
                # Check status
                local status
                status=$(echo "$result" | grep -i "^status:" | head -1 | cut -d: -f2 | tr -d ' ')
                
                case "$status" in
                    PASS)
                        log_success "Task completed successfully!"
                        return 0
                        ;;
                    REQUIRES_USER_ACTION)
                        log_warn "User action required!"
                        echo ""
                        echo "The agent needs you to do something."
                        echo "Check VNC at http://localhost:6080"
                        echo ""
                        read -p "Press Enter after completing the action..."
                        # Reset and continue
                        docker exec "$CONTAINER" rm -f "/home/node/.openclaw/workspace/$result_file"
                        ;;
                    BLOCKED)
                        local blocker
                        blocker=$(echo "$result" | grep -i "^blocker:" | cut -d: -f2-)
                        log_warn "Task blocked: $blocker"
                        local next_action
                        next_action=$(echo "$result" | grep -i "^next_action:" | cut -d: -f2 | tr -d ' ')
                        if [ "$next_action" = "CALL_AUTH" ]; then
                            log_info "Calling Worker Auth..."
                            dispatch_to_supervisor "Authenticate with GitHub"
                        fi
                        ;;
                    FAILED)
                        log_error "Task failed!"
                        return 1
                        ;;
                esac
            fi
        done
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
        printf "."
    done
    
    echo ""
    log_warn "Timeout waiting for results"
    return 1
}

check_worker_results() {
    log_info "Checking for Worker results..."
    
    # Make sure we have a container
    if [ -z "$CONTAINER" ]; then
        CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE "openclaw|gateway" | head -1)
    fi
    
    if [ -z "$CONTAINER" ]; then
        log_warn "No container found to check results"
        return 1
    fi
    
    local found=0
    for result_file in "worker-auth-result.md" "worker-generate-code-result.md" "worker-publish-mcp-result.md"; do
        if docker exec "$CONTAINER" test -f "/home/node/.openclaw/workspace/$result_file" 2>/dev/null; then
            log_success "Found: $result_file"
            echo ""
            docker exec "$CONTAINER" cat "/home/node/.openclaw/workspace/$result_file"
            echo ""
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        log_info "No result files found yet"
    fi
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
    log_info "Auto-executing task..."
    echo "  - Supervisor will dispatch to Worker Auth"
    echo "  - Worker Auth checks GitHub browser session"  
    echo "  - If login needed, script will pause and ask you to login via VNC"
    echo ""
    echo "Watch VNC at http://localhost:6080 to see browser"
    echo ""
    
    dispatch_to_supervisor "Check if GitHub is authenticated. Verify the browser session and report the authentication status. If not authenticated, open browser and ask user to login."
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
    log_info "Auto-executing task..."
    echo "  - Supervisor dispatches to Worker Generate Code"
    echo "  - Worker generates a minimal MCP server"
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
    log_info "Auto-executing full pipeline..."
    echo "  - Auth → Generate → Publish"
    echo "  - If login needed, script will pause at VNC"
    log_warn "This may take several minutes."
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
    log_info "Starting Interactive Mode..."
    
    check_api_key || return 1
    check_gateway || return 1
    
    CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "openclaw.*gateway" | head -1)
    
    if [ -z "$CONTAINER" ]; then
        log_error "Cannot find OpenClaw Gateway container"
        return 1
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  OpenClaw Agent - Interactive Mode"
    echo ""
    echo "  Web Interface:  http://localhost:18789"
    echo "  VNC Browser:    http://localhost:6080"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Example tasks to try:"
    echo "  - Check GitHub authentication status"
    echo "  - Create a simple MCP server called my-mcp"  
    echo "  - Publish my-mcp to GitHub"
    echo ""
    echo "─────────────────────────────────────────────"
    echo ""
    
    # Try different ways to start CLI
    docker exec -it "$CONTAINER" openclaw 2>/dev/null || \
    docker exec -it "$CONTAINER" npx openclaw 2>/dev/null || \
    docker exec -it "$CONTAINER" node dist/index.js 2>/dev/null || \
    echo "Note: CLI not available. Use web interface at http://localhost:18789"
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
