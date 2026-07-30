#!/usr/bin/env bash
#
# OpenClaw Agent - Enable Direct SSH (Without ngrok)
# Các cách miễn phí để SSH từ máy khác
#
# Usage: ./scripts/enable-direct-ssh.sh [command]
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

# =============================================================================
# OPTION 1: TAILSCALE (Recommended - Free VPN, P2P, No port forwarding)
# =============================================================================

setup_tailscale() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              Setup Tailscale (Free P2P VPN)                           ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "Tailscale là VPN miễn phí, cho phép kết nối giữa các thiết bị như cùng mạng LAN"
    echo ""
    echo "Ưu điểm:"
    echo "  ✓ Miễn phí (personal/small business)"
    echo "  ✓ Không cần port forward router"
    echo "  ✓ Tự động NAT traversal (P2P)"
    echo "  ✓ Encrypted"
    echo "  ✓ Hoạt động trên WSL"
    echo ""
    
    # Check if Tailscale is installed
    if ! command -v tailscale &> /dev/null; then
        log_info "Cài đặt Tailscale..."
        
        # Install Tailscale
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case $ID in
                ubuntu|debian)
                    curl -fsSL https://tailscale.com/install.sh | sh
                    ;;
                fedora)
                    dnf install -y tailscale
                    ;;
                arch)
                    pacman -S tailscale
                    ;;
                *)
                    log_error "Unsupported distro: $ID"
                    log_info "Visit: https://tailscale.com/download/linux"
                    return 1
                    ;;
            esac
        else
            log_error "Không thể xác định distro"
            log_info "Cài đặt thủ công: https://tailscale.com/download/linux"
            return 1
        fi
    else
        log_success "Tailscale đã được cài"
    fi
    
    # Start Tailscale service
    log_info "Khởi động Tailscale service..."
    sudo service tailscaled start 2>/dev/null || sudo systemctl start tailscaled 2>/dev/null || true
    
    # Login to Tailscale
    if ! tailscale status 2>/dev/null | grep -q "Connected"; then
        log_info "Bạn cần đăng nhập Tailscale"
        echo ""
        echo "Chạy lệnh này và theo dõi link:"
        echo "  sudo tailscale up"
        echo ""
        sudo tailscale up
    else
        log_success "Tailscale đã được kết nối"
    fi
    
    echo ""
    log_success "Tailscale setup hoàn tất!"
    echo ""
    show_tailscale_info
}

show_tailscale_info() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              Tailscale SSH Configuration                              ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Get Tailscale IP
    local tailscale_ip=$(tailscale ip -4 2>/dev/null || echo "unknown")
    
    if [ "$tailscale_ip" != "unknown" ]; then
        log_success "Tailscale IP: $tailscale_ip"
    else
        log_warn "Tailscale không connected hoặc không thể lấy IP"
        return 1
    fi
    
    local current_user=$(whoami)
    local machine_name=$(tailscale status 2>/dev/null | grep -E "^\s+[0-9]" | head -1 | awk '{print $2}' | cut -d. -f1 || echo "openclaw-machine")
    
    echo ""
    echo "Để SSH từ máy khác:"
    echo "─────────────────────────────────────────────"
    echo ""
    echo "1. Cài Tailscale trên máy khác:"
    echo "   https://tailscale.com/download"
    echo ""
    echo "2. SSH vào máy này:"
    echo "   ssh $current_user@$tailscale_ip"
    echo ""
    echo "   Hoặc dùng machine name (nếu được resolve):"
    echo "   ssh $current_user@$machine_name"
    echo ""
    echo "─────────────────────────────────────────────"
    echo ""
    
    # Show OpenClaw services on Tailscale network
    echo "Services trên Tailscale network:"
    echo "  - SSH:     $tailscale_ip:22"
    echo "  - VNC:     http://$tailscale_ip:6080"
    echo "  - Gateway: http://$tailscale_ip:18789"
    echo ""
    
    log_info "Xem tất cả máy trong Tailscale: tailscale status"
    log_info "Quản lý: https://login.tailscale.com/"
    echo ""
    
    show_ssh_android
}

# =============================================================================
# SSH FROM ANDROID (Works with Tailscale, Reverse Tunnel, Port Forward)
# =============================================================================

show_ssh_android() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              SSH từ điện thoại Android                                ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_success "Có, SSH từ Android được! 📱"
    echo ""
    
    echo "Các SSH client phổ biến trên Android:"
    echo "─────────────────────────────────────────────"
    echo ""
    
    echo "1. Termux (Khuyến cáo) ⭐"
    echo "   URL: https://termux.com/ hoặc F-Droid"
    echo "   - Terminal đầy đủ, dùng OpenSSH native"
    echo "   - Mã nguồn mở, miễn phí"
    echo "   - Lệnh: pkg install openssh && ssh user@host"
    echo ""
    
    echo "2. JuiceSSH (Đơn giản)"
    echo "   URL: https://play.google.com/store/apps/details?id=com.sonelli.juicessh"
    echo "   - UI đẹp, dễ dùng"
    echo "   - Free version đủ dùng"
    echo ""
    
    echo "3. Connectbot (Cổ điển)"
    echo "   URL: https://play.google.com/store/apps/details?id=org.connectbot"
    echo "   - Miễn phí, nhẹ"
    echo "   - Tương thích tốt"
    echo ""
    
    echo "4. Termius (Pro)"
    echo "   URL: https://termius.com/"
    echo "   - Premium features nhưng free version cũng ok"
    echo "   - UI hiện đại"
    echo ""
    
    echo "─────────────────────────────────────────────"
    echo ""
    
    echo "🔴 KHUYẾN CÁO: Dùng Termux"
    echo ""
    echo "Lý do:"
    echo "  - Mạnh nhất, terminal đầy đủ"
    echo "  - Có package manager (apt)"
    echo "  - Có thể cài thêm tool (vim, tmux, etc)"
    echo "  - Mã nguồn mở"
    echo ""
}

# =============================================================================
# OPTION 2: SSH REVERSE TUNNEL (Nếu có VPS)
# =============================================================================

setup_reverse_tunnel() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║           SSH Reverse Tunnel (Cần VPS hoặc server công cộng)         ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "SSH Reverse Tunnel cho phép kết nối qua server công cộng"
    echo ""
    echo "Yêu cầu:"
    echo "  - VPS/Server có IP public (ví dụ: DigitalOcean free tier, Oracle Cloud)"
    echo "  - SSH access tới VPS"
    echo "  - User có SSH permission"
    echo ""
    
    read -p "Bạn có VPS không? (y/n): " has_vps
    if [ "$has_vps" != "y" ]; then
        echo ""
        log_info "VPS miễn phí:"
        echo "  - Oracle Cloud: https://www.oracle.com/cloud/free/ (always free tier)"
        echo "  - Replit.com: https://replit.com/ (free compute)"
        echo "  - Railway.app: https://railway.app/ (limited free)"
        echo ""
        return 0
    fi
    
    read -p "VPS user (ví dụ: root, ubuntu): " vps_user
    read -p "VPS IP hoặc domain (ví dụ: 1.2.3.4, example.com): " vps_host
    read -p "VPS SSH port (default 22): " vps_port
    vps_port=${vps_port:-22}
    
    local current_user=$(whoami)
    local local_ssh_port=22
    local remote_port=2222
    
    echo ""
    log_info "Cấu hình:"
    echo "  Local SSH:  localhost:$local_ssh_port"
    echo "  Remote port: $remote_port (trên VPS)"
    echo "  VPS: $vps_user@$vps_host:$vps_port"
    echo ""
    
    # Create systemd service for reverse tunnel
    local service_file="/tmp/openclaw-reverse-tunnel.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=OpenClaw SSH Reverse Tunnel
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$current_user
ExecStart=/usr/bin/ssh -N -R $remote_port:localhost:$local_ssh_port -p $vps_port $vps_user@$vps_host
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    echo "Service file:"
    echo "─────────────────────────────────────────────"
    cat "$service_file"
    echo "─────────────────────────────────────────────"
    echo ""
    
    log_info "Để sử dụng service này:"
    echo "  1. Copy vào systemd:"
    echo "     sudo cp $service_file /etc/systemd/system/"
    echo ""
    echo "  2. Bật service:"
    echo "     sudo systemctl daemon-reload"
    echo "     sudo systemctl enable openclaw-reverse-tunnel"
    echo "     sudo systemctl start openclaw-reverse-tunnel"
    echo ""
    echo "  3. SSH từ máy khác:"
    echo "     ssh -p $remote_port $current_user@$vps_host"
    echo ""
    
    log_warn "Note: Bạn cần setup SSH key auth (không password) cho VPS"
    echo "  ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"
    echo "  ssh-copy-id -p $vps_port $vps_user@$vps_host"
    echo ""
}

# =============================================================================
# OPTION 3: PORT FORWARD + DDNS (Nếu IP tĩnh)
# =============================================================================

setup_port_forward() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║        Port Forwarding + DDNS (Nếu IP tĩnh hoặc DDNS)               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "Cách này yêu cầu cấu hình router + DDNS (nếu IP thay đổi)"
    echo ""
    echo "Bước:"
    echo "  1. Cấu hình router:"
    echo "     - Port Forward: public 22 -> laptop-local-ip:22"
    echo "     - Hoặc: public 2222 -> laptop-local-ip:22"
    echo ""
    echo "  2. Nếu IP thay đổi, dùng DDNS:"
    echo "     - no-ip.com (miễn phí)"
    echo "     - duckdns.org (miễn phí)"
    echo "     - Cài client để auto-update DNS"
    echo ""
    
    read -p "Tiếp tục? (y/n): " continue_fw
    if [ "$continue_fw" != "y" ]; then
        return 0
    fi
    
    read -p "Public port (default 2222): " public_port
    public_port=${public_port:-2222}
    
    read -p "Máy này IP local (ví dụ 192.168.1.100): " local_ip
    read -p "Tên domain DDNS hoặc IP public (ví dụ: mypc.duckdns.org): " public_host
    
    local current_user=$(whoami)
    
    echo ""
    echo "Cấu hình hoàn tất!"
    echo ""
    echo "Để SSH từ máy khác:"
    echo "─────────────────────────────────────────────"
    echo "  ssh -p $public_port $current_user@$public_host"
    echo "─────────────────────────────────────────────"
    echo ""
    
    log_info "DDNS setup (duckdns.org ví dụ):"
    echo "  1. Đăng ký: https://www.duckdns.org/"
    echo "  2. Cài client:"
    echo "     sudo apt install duckdns"
    echo "  3. Config: /etc/duckdns/duckdns.conf"
    echo ""
}

# =============================================================================
# SHOW COMPARISON
# =============================================================================

show_comparison() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║            Comparison: Direct SSH Methods                             ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    cat << 'EOF'
┌─────────────┬──────────────┬──────────────┬───────────────┬─────────────┐
│ Method      │ Cost         │ Setup        │ Speed         │ Port Forward│
├─────────────┼──────────────┼──────────────┼───────────────┼─────────────┤
│ Tailscale   │ Free (✓)     │ Easy (✓)     │ Fast P2P (✓)  │ No (✓)      │
│ Reverse SSH │ Free* (✓)    │ Medium       │ Good          │ No (✓)      │
│ Port Forward│ Free (✓)     │ Hard         │ Very Fast     │ Yes (Router)│
└─────────────┴──────────────┴──────────────┴───────────────┴─────────────┘
*Cần VPS miễn phí hoặc có sẵn

KHUYẾN CÁO: Dùng TAILSCALE (dễ + nhanh + không cần cấu hình)
EOF
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

show_help() {
    echo ""
    echo "Usage: ./scripts/enable-direct-ssh.sh [command]"
    echo ""
    echo "Commands:"
    echo "  tailscale       Setup Tailscale (Recommended)"
    echo "  reverse-tunnel  Setup SSH Reverse Tunnel (Need VPS)"
    echo "  port-forward    Setup Port Forwarding (Need Static IP)"
    echo "  compare         Xem so sánh các cách"
    echo "  android         Hướng dẫn SSH từ điện thoại Android"
    echo "  help            Show this help"
    echo ""
    echo "Recommended: ./scripts/enable-direct-ssh.sh tailscale"
    echo ""
}

case "${1:-help}" in
    tailscale)
        setup_tailscale
        ;;
    reverse-tunnel)
        setup_reverse_tunnel
        ;;
    port-forward)
        setup_port_forward
        ;;
    compare)
        show_comparison
        ;;
    android)
        show_ssh_android
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
