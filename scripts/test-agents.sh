#!/usr/bin/env bash
#
# OpenClaw Agent - Test Script
# Test các workers sau khi setup
#
# Usage: ./scripts/test-agents.sh [worker_name]
# Example: ./scripts/test-agents.sh auth
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

GATEWAY_URL="http://localhost:18789"

# =============================================================================
# CHECK GATEWAY
# =============================================================================

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
        echo ""
        echo "Or manually:"
        echo "  cd docker && docker compose up -d"
        return 1
    fi
}

# =============================================================================
# TEST WORKER AUTH
# =============================================================================

test_worker_auth() {
    log_info "Testing Worker Auth..."
    echo ""
    echo "Worker Auth manages browser authentication sessions."
    echo ""
    echo "To test Worker Auth, you need to:"
    echo ""
    echo "1. Open VNC viewer: http://localhost:6080"
    echo ""
    echo "2. Use OpenClaw CLI to call Worker Auth:"
    echo "   docker exec -it openclaw-gateway npx openclaw chat"
    echo ""
    echo "3. Send a task to authenticate with a provider:"
    echo "   Example prompts:"
    echo "   - 'Check GitHub authentication status'"
    echo "   - 'Authenticate with GitHub'"
    echo "   - 'Verify my GitHub session'"
    echo ""
    echo "4. Watch the browser in VNC - Worker Auth will:"
    echo "   - Open browser if needed"
    echo "   - Check login status"
    echo "   - Request user action if authentication needed"
    echo "   - Write status to AUTH/<provider>.json"
    echo ""
}

# =============================================================================
# TEST WORKER GENERATE CODE
# =============================================================================

test_worker_generate() {
    log_info "Testing Worker Generate Code..."
    echo ""
    echo "Worker Generate Code creates MCP server projects."
    echo ""
    echo "To test:"
    echo ""
    echo "1. Use OpenClaw CLI:"
    echo "   docker exec -it openclaw-gateway npx openclaw chat"
    echo ""
    echo "2. Send a task to generate MCP:"
    echo "   Example prompts:"
    echo "   - 'Generate a simple MCP server called hello-mcp with one tool'"
    echo "   - 'Create an MCP server that returns the current time'"
    echo ""
    echo "3. Check results:"
    echo "   - Look for worker-generate-code-result.md"
    echo "   - Check the generated project in workspace"
    echo ""
}

# =============================================================================
# TEST WORKER PUBLISH
# =============================================================================

test_worker_publish() {
    log_info "Testing Worker Publish MCP..."
    echo ""
    echo "Worker Publish MCP publishes to MCP marketplaces via browser."
    echo ""
    echo "Prerequisites:"
    echo "  - Worker Auth must have valid GitHub session"
    echo "  - An MCP project must exist (from Worker Generate Code)"
    echo ""
    echo "To test:"
    echo ""
    echo "1. Open VNC viewer: http://localhost:6080"
    echo ""
    echo "2. Use OpenClaw CLI:"
    echo "   docker exec -it openclaw-gateway npx openclaw chat"
    echo ""
    echo "3. Send a publish task:"
    echo "   Example prompts:"
    echo "   - 'Publish the hello-mcp project to GitHub'"
    echo "   - 'Submit hello-mcp to MCP marketplace'"
    echo ""
}

# =============================================================================
# QUICK HEALTHCHECK
# =============================================================================

quick_test() {
    log_info "Running quick health check..."
    echo ""
    
    # Check Gateway
    if curl -s --connect-timeout 5 "$GATEWAY_URL/healthz" > /dev/null 2>&1; then
        log_success "Gateway: Running"
    else
        log_error "Gateway: Not running"
    fi
    
    # Check Docker containers
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "openclaw"; then
        CONTAINERS=$(docker ps --format '{{.Names}}' | grep openclaw | tr '\n' ', ' | sed 's/,$//')
        log_success "Docker: $CONTAINERS"
    else
        log_error "Docker: No openclaw containers running"
    fi
    
    # Check VNC
    if curl -s --connect-timeout 3 "http://localhost:6080" > /dev/null 2>&1; then
        log_success "VNC: Accessible at http://localhost:6080"
    else
        log_error "VNC: Not accessible"
    fi
    
    # Check auth directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(dirname "$SCRIPT_DIR")"
    if [ -d "$REPO_ROOT/auth" ]; then
        AUTH_FILES=$(find "$REPO_ROOT/auth" -name "*.json" 2>/dev/null | wc -l)
        if [ "$AUTH_FILES" -gt 0 ]; then
            log_success "Auth: $AUTH_FILES provider(s) configured"
        else
            log_info "Auth: No providers authenticated yet"
        fi
    fi
    
    echo ""
}

# =============================================================================
# INTERACTIVE CLI
# =============================================================================

start_cli() {
    log_info "Starting OpenClaw CLI..."
    echo ""
    
    if ! check_gateway; then
        exit 1
    fi
    
    echo "Entering interactive chat mode..."
    echo "Type your tasks for the agents. Use Ctrl+C to exit."
    echo ""
    
    # Try to exec into container
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "openclaw-gateway"; then
        docker exec -it $(docker ps --format '{{.Names}}' | grep "openclaw-gateway" | head -1) npx openclaw chat
    else
        log_error "Cannot find openclaw-gateway container"
        echo ""
        echo "Start with: ./scripts/start-openclaw.sh"
    fi
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
    echo "  check       Quick health check (default)"
    echo "  auth        Test Worker Auth"
    echo "  generate    Test Worker Generate Code"
    echo "  publish     Test Worker Publish MCP"
    echo "  cli         Start interactive CLI"
    echo "  all         Show all test instructions"
    echo ""
    echo "Examples:"
    echo "  $0              # Quick health check"
    echo "  $0 auth         # Instructions for testing Worker Auth"
    echo "  $0 cli          # Start interactive CLI session"
    echo ""
}

case "${1:-check}" in
    check)
        quick_test
        ;;
    auth)
        check_gateway && test_worker_auth
        ;;
    generate)
        check_gateway && test_worker_generate
        ;;
    publish)
        check_gateway && test_worker_publish
        ;;
    cli)
        start_cli
        ;;
    all)
        check_gateway
        echo ""
        test_worker_auth
        echo "─────────────────────────────────────────────"
        test_worker_generate
        echo "─────────────────────────────────────────────"
        test_worker_publish
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
