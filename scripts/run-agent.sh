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
        log_info "Try: sudo service docker start"
        return 1
    fi
    
    # Additional check: verify docker compose works
    if ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose is not available"
        return 1
    fi
}

wait_for_healthy() {
    local max_attempts=30  # 30 * 2 = 60 seconds max wait
    local attempt=0
    
    log_info "Waiting for containers to reach healthy state..."
    
    while [ $attempt -lt $max_attempts ]; do
        # Check for ANY openclaw container that's healthy
        # Support both LOCAL mode (cli + ssh) and GATEWAY mode (gateway + cli + ssh)
        local healthy_count=$(docker ps --format "{{.Names}}: {{.Status}}" | grep openclaw | grep -c "(healthy)" || true)
        local running_count=$(docker ps --format "{{.Names}}: {{.Status}}" | grep openclaw | grep -c "Up" || true)
        
        if [ "$healthy_count" -ge 1 ]; then
            log_success "Containers are healthy ($healthy_count healthy)"
            return 0
        fi
        
        if [ "$running_count" -ge 1 ]; then
            # At least one container running
            local elapsed=$((attempt * 2))
            if [ $elapsed -gt 10 ]; then
                # If running for more than 10 seconds, consider it ready
                log_success "Containers are running ($running_count containers)"
                return 0
            fi
        fi
        
        # Show progress
        if [ $((attempt % 3)) -eq 0 ]; then
            local progress=$((attempt * 2))
            echo -ne "  ⏳ Waiting for health... (${progress}s)    \r"
        fi
        
        sleep 2
        ((attempt++))
    done
    
    # Even if not fully healthy, if any container is running, proceed
    local running=$(docker ps --format "{{.Names}}" | grep openclaw || true)
    if [ -n "$running" ]; then
        log_warn "Containers running but may not be fully healthy. Proceeding anyway..."
        return 0
    fi
    
    return 1
}

check_gateway() {
    if ! docker ps | grep -q "openclaw"; then
        log_error "OpenClaw containers not running"
        log_info "Start with: ./scripts/start-openclaw.sh"
        log_info "  For local mode (CLI only): ./scripts/start-openclaw.sh"
        log_info "  For gateway mode (web UI): ./scripts/start-openclaw.sh --gateway"
        return 1
    fi
    
    # Wait for healthy state
    wait_for_healthy || return 1
}

check_results() {
    local workspace="$HOME/.openclaw/workspace"
    
    if [ ! -d "$workspace" ]; then
        return 1
    fi
    
    # Check for result files
    if ls "$workspace"/worker-*-result.md >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Pre-check: Verify container is responsive
verify_container_responsive() {
    log_info "Verifying container is responsive..."
    
    # Try simple echo command
    if docker compose exec -T openclaw-cli echo "container ok" >/dev/null 2>&1; then
        log_success "Container is responsive"
        return 0
    else
        log_error "Container not responding to exec commands"
        log_info "Checking container status:"
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep openclaw || true
        
        log_info "Try: docker compose restart"
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
    echo "║              OpenClaw Agent - Direct Execution (No Crestodian Loop)   ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "Pre-flight checks..."
    check_docker || return 1
    check_gateway || return 1
    log_success "Checks passed"
    echo ""
    
    log_info "Verifying container responsiveness..."
    verify_container_responsive || return 1
    echo ""
    
    log_info "Building prompt with specs..."
    local prompt=$(build_prompt "$task")
    
    echo "Task: $task_input"
    echo ""
    
    log_info "Sending to supervisor (HTTP API)..."
    echo ""
    
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Send via HTTP API first (optional, might not work in local mode)
    # Local mode doesn't have gateway, so this will fail gracefully
    local api_response=$(curl -s -X POST "http://localhost:18789/api/conversation" \
        -H "Content-Type: application/json" \
        -d "{\"message\": $(echo "$prompt" | jq -Rs .)}" 2>&1)
    
    if [ -n "$api_response" ] && ! echo "$api_response" | grep -qi "not found\|404\|error\|connection refused"; then
        # API worked (gateway mode only)
        log_success "API Response:"
        echo "$api_response" | jq -r '.response // .message // .' 2>/dev/null || echo "$api_response"
    else
        # API not available (expected in local mode) - use docker exec directly
        log_info "Using direct CLI execution (docker exec)..."
        echo ""
        
        # Use docker exec - this is the actual working method
        cd "$REPO_ROOT" || return 1
        
        # Execute agent with realtime output streaming
        echo "Step 1: Preparing prompt..."
        local prompt_len=${#prompt}
        echo "  Prompt size: $prompt_len bytes"
        echo ""
        
        echo "Step 2: Executing docker compose exec..."
        echo "  Command: docker compose exec -T openclaw-cli node dist/index.js agent --message \"...\""
        echo ""
        echo "─────────────────────────────────────────────────────────────────────"
        echo ""
        
        # Stream output realtime while also capturing for error detection
        local output_file="/tmp/openclaw-output-$$.txt"
        local exit_code=0
        
        log_info "⏳ Agent running... (timeout 60s)"
        echo ""
        
        # Use tee to stream output AND save to file, with timeout
        timeout 60 docker compose exec -T openclaw-cli node dist/index.js agent \
            --message "$prompt" 2>&1 | tee "$output_file" || exit_code=$?
        
        local docker_exit=$?
        echo ""
        echo "─────────────────────────────────────────────────────────────────────"
        echo ""
        
        # Handle exit codes
        if [ $exit_code -eq 124 ] || [ $docker_exit -eq 124 ]; then
            log_warn "Execution timed out (60s) - agent is still processing in background"
            echo "  (Results will appear when ready)"
            echo ""
            
        elif [ $exit_code -ne 0 ] || [ $docker_exit -ne 0 ]; then
            log_error "Agent execution failed with exit code $exit_code / docker exit $docker_exit"
            echo ""
            
            # Show what happened
            if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                echo "  Output captured:"
                head -20 "$output_file"
            else
                echo "  No output captured"
                echo ""
                echo "  Container logs:"
                docker compose logs --tail=20 openclaw-cli 2>/dev/null || echo "  (Could not read logs)"
            fi
            
            rm -f "$output_file"
            return 1
        fi
        
        # Clean up
        rm -f "$output_file"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    
    log_success "Agent execution complete"
    echo ""
    
    log_info "Next steps:"
    echo ""
    echo "  1. Check if agent ran:"
    echo "     $ ls ~/.openclaw/workspace/worker-*-result.md"
    echo "     $ cat ~/.openclaw/workspace/worker-auth-result.md"
    echo ""
    echo "  2. View realtime browser activity:"
    echo "     → http://localhost:6080 (VNC)"
    echo ""
    echo "  3. Debug with logs:"
    echo "     $ docker compose logs -f"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

run_agent "$@"
