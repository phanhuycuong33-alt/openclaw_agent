#!/usr/bin/env bash
#
# Wait for OpenClaw containers to reach healthy state
# Usage: ./scripts/wait-healthy.sh [timeout_seconds]
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Get timeout (default 120 seconds)
TIMEOUT=${1:-120}
START_TIME=$(date +%s)
MAX_TIME=$((START_TIME + TIMEOUT))

log_info "Waiting for containers to reach healthy state (timeout: ${TIMEOUT}s)..."
echo ""

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    REMAINING=$((TIMEOUT - ELAPSED))
    
    # Get container status
    STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep -E "openclaw-(cli|ssh)" || true)
    
    if [ -z "$STATUS" ]; then
        log_error "No OpenClaw containers found"
        echo "  Run: ./scripts/start-openclaw.sh"
        exit 1
    fi
    
    # Count healthy containers
    HEALTHY_COUNT=$(echo "$STATUS" | grep -c "(healthy)" || true)
    RUNNING_COUNT=$(echo "$STATUS" | grep -c "Up" || true)
    
    # Show current status
    echo "$STATUS" | while IFS= read -r line; do
        if echo "$line" | grep -q "(healthy)"; then
            echo -e "  ${GREEN}✓${NC} $line"
        elif echo "$line" | grep -q "Up"; then
            echo -e "  ${YELLOW}⟳${NC} $line"
        else
            echo -e "  ${RED}✗${NC} $line"
        fi
    done
    
    # Check if all are healthy
    if [ "$HEALTHY_COUNT" -ge 2 ]; then
        echo ""
        log_success "All containers are healthy!"
        echo ""
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep openclaw
        exit 0
    fi
    
    # Check timeout
    if [ $CURRENT_TIME -ge $MAX_TIME ]; then
        echo ""
        log_error "Timeout reached (${TIMEOUT}s)"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check logs: docker compose logs"
        echo "  2. Restart: docker compose restart"
        echo "  3. Full reset: docker compose down -v && ./scripts/start-openclaw.sh"
        exit 1
    fi
    
    # Show progress
    echo -ne "  ⏳ Waiting... (${ELAPSED}s / ${TIMEOUT}s, ${REMAINING}s remaining)\r"
    
    sleep 1
done
