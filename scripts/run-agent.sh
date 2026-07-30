#!/usr/bin/env bash
#
# OpenClaw Agent - Run Agent with Spec Auto-Reading
# Chạy agent trực tiếp từ CLI, tự động đọc spec files
#
# Usage: ./scripts/run-agent.sh "task description"
#        ./scripts/run-agent.sh auth
#        ./scripts/run-agent.sh "generate hello-mcp"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$REPO_ROOT/docker"

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

check_docker() {
    if ! docker ps >/dev/null 2>&1; then
        log_error "Docker is not running"
        return 1
    fi
}

check_gateway() {
    if ! docker ps | grep -q "openclaw"; then
        log_error "OpenClaw containers not running"
        log_info "Start with: ./scripts/start-openclaw.sh"
        return 1
    fi
}

# =============================================================================
# TASK MAPPING
# =============================================================================

map_task() {
    local input="$1"
    
    case "$input" in
        auth|authentication)
            echo "Check if GitHub is authenticated. Read WORKER_AUTH.md spec and verify the browser session. Report the authentication status."
            ;;
        generate|gen)
            echo "Generate a simple MCP server called 'hello-test-mcp' with one tool named 'hello_test' that returns 'Hello from test MCP!'. Read WORKER_GENERATE_CODE.md spec and create the server."
            ;;
        publish)
            echo "Publish the hello-test-mcp to GitHub. Read WORKER_PUBLISH_MCP.md spec and handle GitHub authentication."
            ;;
        full|full-flow)
            echo "Run full flow: auth -> generate -> publish. Read all specs and execute in order."
            ;;
        *)
            # Custom message
            echo "$input"
            ;;
    esac
}

# =============================================================================
# BUILD PROMPT WITH SPECS
# =============================================================================

build_prompt() {
    local task="$1"
    
    # Read spec files
    local supervisor_spec=""
    local worker_auth_spec=""
    local worker_generate_spec=""
    local worker_publish_spec=""
    local worker_report_spec=""
    
    if [ -f "$REPO_ROOT/supervisor/SUPERVISOR_SPEC.md" ]; then
        supervisor_spec=$(cat "$REPO_ROOT/supervisor/SUPERVISOR_SPEC.md")
    fi
    
    if [ -f "$REPO_ROOT/workers/WORKER_AUTH.md" ]; then
        worker_auth_spec=$(cat "$REPO_ROOT/workers/WORKER_AUTH.md")
    fi
    
    if [ -f "$REPO_ROOT/workers/WORKER_GENERATE_CODE.md" ]; then
        worker_generate_spec=$(cat "$REPO_ROOT/workers/WORKER_GENERATE_CODE.md")
    fi
    
    if [ -f "$REPO_ROOT/workers/WORKER_PUBLISH_MCP.md" ]; then
        worker_publish_spec=$(cat "$REPO_ROOT/workers/WORKER_PUBLISH_MCP.md")
    fi
    
    if [ -f "$REPO_ROOT/workers/WORKER_REPORT_SPEC.md" ]; then
        worker_report_spec=$(cat "$REPO_ROOT/workers/WORKER_REPORT_SPEC.md")
    fi
    
    # Build full prompt
    cat << PROMPT
You are the Supervisor of an AI agent system. Read the specs below and execute the task.

=== SUPERVISOR SPEC ===
$supervisor_spec

=== WORKER AUTH SPEC ===
$worker_auth_spec

=== WORKER GENERATE CODE SPEC ===
$worker_generate_spec

=== WORKER PUBLISH MCP SPEC ===
$worker_publish_spec

=== WORKER REPORT SPEC ===
$worker_report_spec

=== TASK ===
$task

=== INSTRUCTIONS ===
1. Execute this task according to the specs
2. Use browser automation if needed (VNC at http://localhost:6080)
3. Write results to the appropriate result file in /home/node/.openclaw/workspace/
4. If you need user action (login, approval), clearly state what you need and STOP
5. Do NOT ask unnecessary questions - just execute and report

BEGIN EXECUTION:
PROMPT
}

# =============================================================================
# RUN AGENT
# =============================================================================

run_agent() {
    local task_input="$1"
    
    if [ -z "$task_input" ]; then
        log_error "No task specified"
        echo ""
        echo "Usage: ./scripts/run-agent.sh [task]"
        echo ""
        echo "Quick tasks:"
        echo "  auth       - Check GitHub authentication"
        echo "  generate   - Generate sample MCP server"
        echo "  publish    - Publish to GitHub"
        echo "  full-flow  - Run full auth → generate → publish"
        echo ""
        echo "Custom task:"
        echo "  ./scripts/run-agent.sh \"your custom task here\""
        echo ""
        return 1
    fi
    
    # Map task if it's a known shortcut
    local task=$(map_task "$task_input")
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              OpenClaw Agent - Direct Execution                         ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "Pre-flight checks..."
    check_docker || return 1
    check_gateway || return 1
    log_success "Checks passed"
    echo ""
    
    log_info "Building prompt with specs..."
    local prompt=$(build_prompt "$task")
    
    echo "Task: $task_input"
    echo ""
    
    log_info "Running agent in container..."
    echo "Command: docker compose exec openclaw-cli node dist/index.js agent --message \"...\""
    echo ""
    
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Run agent with message
    cd "$DOCKER_DIR"
    docker compose exec openclaw-cli node dist/index.js agent --message "$prompt" || true
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    
    log_success "Agent execution complete"
    echo ""
    
    log_info "Check results:"
    echo "  Result files: ~/.openclaw/workspace/worker-*-result.md"
    echo "  View logs: docker compose logs -f openclaw-gateway"
    echo "  Check VNC: http://localhost:6080"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

run_agent "$@"
