#!/usr/bin/env bash
#
# OpenClaw Agent - Enable Remote Access
# Cho phép truy cập từ xa qua SSH, VNC, Gateway API
# Sử dụng ngrok để tunnel qua internet (không cần port forward router)
#
# Usage: ./scripts/enable-remote.sh [start|stop|status|install]
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
# Support both ngrok v2 and v3+ config paths
NGROK_CONFIG_V2="$HOME/.ngrok2/ngrok.yml"
NGROK_CONFIG_V3="$HOME/.config/ngrok/ngrok.yml"
TUNNEL_INFO_FILE="$REPO_ROOT/.remote-access.txt"

# Helper to check if ngrok is properly configured
check_ngrok_auth() {
    if [ -f "$NGROK_CONFIG_V2" ] && grep -q "authtoken" "$NGROK_CONFIG_V2" 2>/dev/null; then
        return 0
    fi
    if [ -f "$NGROK_CONFIG_V3" ] && grep -q "authtoken" "$NGROK_CONFIG_V3" 2>/dev/null; then
        return 0
    fi
    # Try to verify with ngrok command
    if ngrok config check &>/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# =============================================================================
# INSTALLATION
# =============================================================================

install_dependencies() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              Installing Remote Access Dependencies                    ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Install OpenSSH Server
    log_info "Installing OpenSSH Server..."
    sudo apt-get update
    sudo apt-get install -y openssh-server
    
    # Configure SSH
    log_info "Configuring SSH..."
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
    
    # Start SSH service
    sudo service ssh start || sudo systemctl start sshd || true
    
    # Install ngrok
    if ! command -v ngrok &> /dev/null; then
        log_info "Installing ngrok..."
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt-get update
        sudo apt-get install -y ngrok
    else
        log_success "ngrok already installed"
    fi
    
    echo ""
    log_success "Dependencies installed!"
    echo ""
    
    # Check if ngrok is configured
    if ! check_ngrok_auth; then
        echo "═══════════════════════════════════════════════════════════════════════"
        echo ""
        log_warn "ngrok chưa được cấu hình!"
        echo ""
        echo "Để sử dụng ngrok, bạn cần:"
        echo "  1. Đăng ký tài khoản miễn phí tại: https://ngrok.com/signup"
        echo "  2. Lấy authtoken từ: https://dashboard.ngrok.com/get-started/your-authtoken"
        echo "  3. Chạy lệnh: ngrok config add-authtoken YOUR_TOKEN"
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════"
        echo ""
        
        read -p "Nhập ngrok authtoken (hoặc Enter để bỏ qua): " NGROK_TOKEN
        if [ -n "$NGROK_TOKEN" ]; then
            ngrok config add-authtoken "$NGROK_TOKEN"
            sleep 1
            
            # Verify authtoken was set
            if check_ngrok_auth; then
                log_success "ngrok đã được cấu hình!"
            else
                log_error "Không thể xác nhận authtoken. Vui lòng thử lại."
            fi
        fi
    else
        log_success "ngrok đã được cấu hình"
    fi
}

# =============================================================================
# START REMOTE ACCESS
# =============================================================================

start_remote() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              Starting Remote Access Tunnels                           ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check ngrok
    if ! command -v ngrok &> /dev/null; then
        log_error "ngrok chưa được cài đặt. Chạy: ./scripts/enable-remote.sh install"
        return 1
    fi
    
    # Check ngrok auth
    if ! check_ngrok_auth; then
        log_error "ngrok chưa được cấu hình. Chạy: ./scripts/enable-remote.sh install"
        log_info "Nếu đã cấu hình, thử chạy: ngrok config check"
        return 1
    fi
    
    # Start SSH service
    log_info "Starting SSH service..."
    sudo service ssh start 2>/dev/null || sudo systemctl start sshd 2>/dev/null || true
    
    # Kill existing ngrok processes
    pkill -f "ngrok" 2>/dev/null || true
    sleep 1
    
    log_info "Starting ngrok tunnels..."
    log_info "  - SSH (TCP port 22)"
    log_info "  - VNC (HTTP port 6080)"
    log_info "  - Gateway (HTTP port 18789)"
    echo ""
    
    # Start ngrok tunnels in background
    # Note: Each tunnel needs its own ngrok process OR use ngrok agent with config
    # We'll start them with config file but with verbose output
    
    # Create ngrok config for multiple tunnels
    local ngrok_config_dir="$HOME/.ngrok2"
    mkdir -p "$ngrok_config_dir"
    
    local ngrok_tunnels_config="$ngrok_config_dir/openclaw-tunnels.yml"
    cat > "$ngrok_tunnels_config" << 'EOF'
version: "2"
tunnels:
  ssh:
    proto: tcp
    addr: 22
  vnc:
    proto: http
    addr: 6080
  gateway:
    proto: http
    addr: 18789
EOF
    
    log_info "Tunnels config: $ngrok_tunnels_config"
    
    # Start ngrok - show output to help debug
    log_info "Running: ngrok start --all --config $ngrok_tunnels_config"
    echo ""
    
    ngrok start --all --config "$ngrok_tunnels_config" &
    NGROK_PID=$!
    
    # Wait for ngrok to start
    sleep 5
    
    # Check if ngrok started successfully
    if ! kill -0 $NGROK_PID 2>/dev/null; then
        log_error "Ngrok process died. Checking credentials..."
        sleep 2
        
        # Show ngrok config status
        log_info "Running: ngrok config check"
        ngrok config check || true
        
        return 1
    fi
    
    log_success "Ngrok process started (PID: $NGROK_PID)"
    echo ""
    
    # Get tunnel info from ngrok API
    log_info "Getting tunnel information..."
    
    local max_attempts=15
    local attempt=0
    local tunnels_json=""
    
    while [ $attempt -lt $max_attempts ]; do
        tunnels_json=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null || echo "")
        if echo "$tunnels_json" | grep -q "public_url"; then
            break
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    if [ -z "$tunnels_json" ] || ! echo "$tunnels_json" | grep -q "public_url"; then
        log_error "Không thể lấy thông tin tunnel từ ngrok"
        log_info "Raw response:"
        echo "$tunnels_json"
        echo ""
        log_info "Kiểm tra ngrok dashboard: http://localhost:4040"
        log_info "Hoặc chạy: curl http://localhost:4040/api/tunnels"
        return 1
    fi
    
    # Parse tunnel URLs (with fallback if jq not available)
    local ssh_url=""
    local vnc_url=""
    local gateway_url=""
    
    if command -v jq &> /dev/null; then
        ssh_url=$(echo "$tunnels_json" | jq -r '.tunnels[] | select(.name=="ssh") | .public_url' 2>/dev/null | sed 's|tcp://||' | head -1)
        vnc_url=$(echo "$tunnels_json" | jq -r '.tunnels[] | select(.name=="vnc") | .public_url' 2>/dev/null | head -1)
        gateway_url=$(echo "$tunnels_json" | jq -r '.tunnels[] | select(.name=="gateway") | .public_url' 2>/dev/null | head -1)
    else
        log_warn "jq không được cài, dùng grep thay thế..."
        # Fallback: try to extract URLs with grep
        ssh_url=$(echo "$tunnels_json" | grep -o '"public_url":"[^"]*tcp[^"]*"' | head -1 | cut -d'"' -f4 | sed 's|tcp://||')
        vnc_url=$(echo "$tunnels_json" | grep -o '"public_url":"https[^"]*"' | head -1 | cut -d'"' -f4)
        gateway_url=$(echo "$tunnels_json" | grep -o '"public_url":"https[^"]*"' | tail -1 | cut -d'"' -f4)
    fi
    
    # Fallback: if no named tunnels, use first available
    if [ -z "$ssh_url" ] || [ -z "$vnc_url" ] || [ -z "$gateway_url" ]; then
        log_warn "Không tìm thấy tất cả tunnel. Raw response:"
        echo "$tunnels_json" | head -50
        echo ""
        log_warn "Có thể cấu hình tunnel config không khớp"
    fi
    
    # Get current user
    local current_user=$(whoami)
    
    # Save tunnel info
    cat > "$TUNNEL_INFO_FILE" << EOF
# OpenClaw Remote Access Information
# Generated: $(date)
# PID: $NGROK_PID

SSH_URL=$ssh_url
VNC_URL=$vnc_url
GATEWAY_URL=$gateway_url
USER=$current_user
EOF
    
    # Display info
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    log_success "Remote Access đã được bật!"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│  SSH Access (từ laptop khác hoặc điện thoại)                       │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    
    if [ -n "$ssh_url" ] && [ "$ssh_url" != "null" ]; then
        local ssh_host=$(echo "$ssh_url" | cut -d: -f1)
        local ssh_port=$(echo "$ssh_url" | cut -d: -f2)
        echo "│  ssh $current_user@$ssh_host -p $ssh_port"
        echo "│"
    else
        echo "│  (SSH tunnel không khả dụng)"
    fi
    
    echo "├─────────────────────────────────────────────────────────────────────┤"
    echo "│  VNC (Xem browser từ xa)                                           │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    
    if [ -n "$vnc_url" ] && [ "$vnc_url" != "null" ]; then
        echo "│  $vnc_url"
    else
        echo "│  (VNC tunnel không khả dụng)"
    fi
    
    echo "│"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    echo "│  Gateway API (OpenClaw Web Interface)                              │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    
    if [ -n "$gateway_url" ] && [ "$gateway_url" != "null" ]; then
        echo "│  $gateway_url"
    else
        echo "│  (Gateway tunnel không khả dụng)"
    fi
    
    echo "│"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "ngrok Dashboard: http://localhost:4040"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    log_info "Lưu ý: Các URL này sẽ thay đổi mỗi lần restart"
    log_info "Để dừng: ./scripts/enable-remote.sh stop"
    echo ""
    
    # Debug info
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│  Debug Info                                                         │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    echo "│  Ngrok PID: $NGROK_PID"
    echo "│  Check status: curl http://localhost:4040/api/tunnels | jq"
    echo "│  Kill ngrok: kill $NGROK_PID"
    echo "│  View logs: tail -f /var/log/ngrok.log"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    echo ""
    
    # Also show local network info
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│  Local Network Access (cùng mạng WiFi)                             │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    
    local local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$local_ip" ]; then
        echo "│  SSH:     ssh $current_user@$local_ip"
        echo "│  VNC:     http://$local_ip:6080"
        echo "│  Gateway: http://$local_ip:18789"
    else
        echo "│  (Không thể xác định IP local)"
    fi
    
    echo "└─────────────────────────────────────────────────────────────────────┘"
    echo ""
}

# =============================================================================
# STOP REMOTE ACCESS
# =============================================================================

stop_remote() {
    echo ""
    log_info "Stopping remote access tunnels..."
    
    pkill -f "ngrok" 2>/dev/null || true
    
    if [ -f "$TUNNEL_INFO_FILE" ]; then
        rm -f "$TUNNEL_INFO_FILE"
    fi
    
    log_success "Remote access đã được tắt"
    echo ""
}

# =============================================================================
# STATUS
# =============================================================================

show_status() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              Remote Access Status                                     ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check ngrok process
    if pgrep -f "ngrok" > /dev/null 2>&1; then
        log_success "ngrok đang chạy"
        
        # Get tunnel info
        local tunnels_json=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null || echo "")
        
        if echo "$tunnels_json" | grep -q "public_url"; then
            echo ""
            echo "Active Tunnels:"
            echo "$tunnels_json" | jq -r '.tunnels[] | "  \(.name): \(.public_url)"' 2>/dev/null
        fi
    else
        log_warn "ngrok không chạy"
    fi
    
    # Check SSH
    if pgrep -f "sshd" > /dev/null 2>&1; then
        log_success "SSH server đang chạy"
    else
        log_warn "SSH server không chạy"
    fi
    
    # Check Docker/OpenClaw
    if docker ps 2>/dev/null | grep -qiE "openclaw|gateway"; then
        log_success "OpenClaw container đang chạy"
    else
        log_warn "OpenClaw container không chạy"
    fi
    
    # Show saved tunnel info
    if [ -f "$TUNNEL_INFO_FILE" ]; then
        echo ""
        echo "Saved tunnel info:"
        cat "$TUNNEL_INFO_FILE"
    fi
    
    echo ""
}

# =============================================================================
# DEBUG
# =============================================================================

debug_ngrok() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              Ngrok Configuration & Credential Check                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "Checking ngrok installation..."
    if command -v ngrok &> /dev/null; then
        log_success "ngrok installed"
        ngrok version
    else
        log_error "ngrok not found"
        return 1
    fi
    
    echo ""
    log_info "Checking ngrok configuration..."
    
    if [ -f "$NGROK_CONFIG_V2" ]; then
        log_success "Config found: $NGROK_CONFIG_V2"
        echo "Content:"
        head -20 "$NGROK_CONFIG_V2"
    elif [ -f "$NGROK_CONFIG_V3" ]; then
        log_success "Config found: $NGROK_CONFIG_V3"
        echo "Content:"
        head -20 "$NGROK_CONFIG_V3"
    else
        log_warn "No config file found"
    fi
    
    echo ""
    log_info "Running: ngrok config check"
    ngrok config check || log_error "Config check failed"
    
    echo ""
    log_info "Testing ngrok with simple tunnel..."
    log_info "Running: ngrok http 8080 --log=stdout"
    echo "(This will run for 5 seconds to test credentials)"
    
    timeout 5 ngrok http 8080 --log=stdout 2>&1 | head -30 || true
    
    echo ""
    log_success "Debug check complete"
    echo ""
}

# =============================================================================
# QUICK CONNECT INFO (for mobile/other devices)
# =============================================================================

show_connect_info() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              Quick Connect Info                                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ -f "$TUNNEL_INFO_FILE" ]; then
        source "$TUNNEL_INFO_FILE"
        
        echo "Copy các lệnh sau để kết nối từ thiết bị khác:"
        echo ""
        
        if [ -n "$SSH_URL" ] && [ "$SSH_URL" != "null" ]; then
            local ssh_host=$(echo "$SSH_URL" | cut -d: -f1)
            local ssh_port=$(echo "$SSH_URL" | cut -d: -f2)
            echo "SSH (Terminal):"
            echo "  ssh $USER@$ssh_host -p $ssh_port"
            echo ""
        fi
        
        if [ -n "$VNC_URL" ] && [ "$VNC_URL" != "null" ]; then
            echo "VNC (Browser - xem màn hình):"
            echo "  $VNC_URL"
            echo ""
        fi
        
        if [ -n "$GATEWAY_URL" ] && [ "$GATEWAY_URL" != "null" ]; then
            echo "OpenClaw Web Interface:"
            echo "  $GATEWAY_URL"
            echo ""
        fi
    else
        log_warn "Chưa có tunnel nào đang chạy"
        log_info "Chạy: ./scripts/enable-remote.sh start"
    fi
    
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

show_help() {
    echo ""
    echo "Usage: ./scripts/enable-remote.sh [command]"
    echo ""
    echo "Commands:"
    echo "  install    Cài đặt dependencies (SSH, ngrok)"
    echo "  start      Bắt đầu remote access tunnels"
    echo "  stop       Dừng remote access tunnels"
    echo "  status     Xem trạng thái"
    echo "  info       Hiển thị thông tin kết nối"
    echo "  test       Test ngrok với đơn giản (chỉ HTTP port 80)"
    echo "  debug      Kiểm tra ngrok config và credential"
    echo "  help       Hiển thị help"
    echo ""
    echo "Ví dụ:"
    echo "  ./scripts/enable-remote.sh install  # Lần đầu"
    echo "  ./scripts/enable-remote.sh start    # Bật remote access"
    echo "  ./scripts/enable-remote.sh info     # Lấy URL để kết nối"
    echo "  ./scripts/enable-remote.sh debug    # Kiểm tra credential"
    echo ""
}

case "${1:-help}" in
    install)
        install_dependencies
        ;;
    start)
        start_remote
        ;;
    stop)
        stop_remote
        ;;
    status)
        show_status
        ;;
    info)
        show_connect_info
        ;;
    debug)
        debug_ngrok
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
