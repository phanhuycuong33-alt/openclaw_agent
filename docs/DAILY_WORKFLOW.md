# Daily Workflow - OpenClaw Agent

Quy trình hàng ngày sau khi restart laptop.

## 🚀 Quick Start (Lần đầu mỗi ngày)

```bash
# 1. Mở WSL
wsl

# 2. Vào folder
cd ~/openclaw_agent

# 3. Khởi động OpenClaw (Docker containers)
./scripts/start-openclaw.sh
# ⏳ Chờ cho tới khi thấy: [OK] Containers healthy

# 4. Chạy agent (tự động chờ healthy state)
./scripts/run-agent.sh auth
# hoặc: ./scripts/run-agent.sh generate
# hoặc: ./scripts/run-agent.sh full-flow
```

---

## 📋 Chi tiết các bước

### Bước 1: Mở WSL
```bash
# Từ Windows Terminal hoặc cmd
wsl

# Hoặc từ VS Code
# Ctrl+Shift+` (open terminal)
```

### Bước 2: Vào folder
```bash
cd ~/openclaw_agent

# Hoặc nếu chưa pull mới nhất
cd ~/openclaw_agent && git pull
```

### Bước 3: Khởi động OpenClaw
```bash
./scripts/start-openclaw.sh
```

**Script sẽ:**
- ✅ Kiểm tra .env file (AI API key)
- ✅ Chạy `docker compose up -d`
- ✅ **Chờ cho containers healthy** (tự động, không cần manual)
- ✅ Chạy `openclaw onboard` nếu lần đầu
- ✅ Hiển thị ports + URLs

**Output ví dụ:**
```
[INFO] Waiting for containers to reach healthy state...
⏳ Waiting... (0s elapsed)
[OK] Containers healthy: openclaw-gateway: Up 20s (healthy)

[OK] OpenClaw is Ready! 🚀
```

### Bước 4: Chờ containers chạy
```bash
# Script đã tự động chờ healthy state, nhưng có thể kiểm tra lại
docker ps --format "table {{.Names}}\t{{.Status}}"

# Tìm kiếm "(healthy)" - nếu thấy = ready
# Nếu thấy "(health: starting)" = vẫn khởi động, chờ chút nữa
```

**3 trạng thái:**
```
1. Up 5s (health: starting)   ← Chờ chút nữa
2. Up 10s (health: starting)  ← Sắp xong
3. Up 20s (healthy)           ← Ready! ✅
```

### Bước 5: Chạy agents (NEW - khuyến cáo)
```bash
# ⭐⭐⭐ RECOMMENDED: Dùng run-agent.sh
# Tự động chờ healthy state + đọc specs

# Test auth (check GitHub login)
./scripts/run-agent.sh auth

# Test generate (create MCP server)
./scripts/run-agent.sh generate

# Full flow (auth → generate → publish)
./scripts/run-agent.sh full-flow

# Custom task
./scripts/run-agent.sh "mô tả task của bạn"

# ⚠️ OLD (Polling-based, có thể loop):
# ./scripts/test-agents.sh auth
```

---

## 🔧 Troubleshoot Daily Startup

### Containers không start
```bash
# Kiểm tra Docker daemon
sudo service docker start

# Hoặc check logs
docker logs openclaw-gateway
```

### API key lỗi
```bash
# Sửa .env
nano docker/.env

# Restart
docker compose restart
```

### Port bị chiếm
```bash
# Lấy process đang dùng port
sudo lsof -i :18789

# Kill nó
sudo kill -9 <PID>

# Restart containers
docker compose down && docker compose up -d
```

### OpenClaw không response
```bash
# Hard reset
docker compose down
docker system prune -a
docker compose up -d --build
```

---

## 🌐 Access OpenClaw

**Local (trên laptop):**
- Web UI: http://localhost:18789
- VNC (browser): http://localhost:6080
- SSH: `ssh user@localhost` (hoặc local IP)

**Từ máy khác (sau setup Tailscale):**
```bash
# Cài Tailscale trên cả 2 máy
./scripts/enable-direct-ssh.sh tailscale

# Rồi truy cập:
# Web UI: http://tailscale-ip:18789
# VNC: http://tailscale-ip:6080
# SSH: ssh user@tailscale-ip
```

---

## 📱 Từ điện thoại

```bash
# Setup Tailscale (1 lần)
./scripts/enable-direct-ssh.sh tailscale

# Phone setup (Termux hoặc JuiceSSH)
tailscale up
ssh user@tailscale-ip

# Rồi chạy script
./scripts/test-agents.sh auth
```

Xem chi tiết: [`docs/ANDROID_SSH_GUIDE.md`](../docs/ANDROID_SSH_GUIDE.md)

---

## 📝 Cheat Sheet

```bash
# Khởi động
./scripts/start-openclaw.sh

# Test
./scripts/test-agents.sh auth         # Test auth
./scripts/test-agents.sh generate     # Test generate code
./scripts/test-agents.sh full-flow    # Full test
./scripts/test-agents.sh quick-check  # Quick check

# Debug
docker ps                              # Xem containers
docker logs -f openclaw-gateway       # Xem logs
./scripts/enable-direct-ssh.sh debug  # Debug SSH

# Remote access
./scripts/enable-direct-ssh.sh tailscale    # Setup Tailscale
./scripts/enable-remote.sh start             # Setup ngrok
./scripts/enable-direct-ssh.sh android       # Android guide

# Dừng
docker compose down
pkill -f "ngrok"
```

---

## 🎯 Recommend workflow

### **Lần đầu (Setup)**
```bash
cd openclaw_agent
./scripts/setup-wsl.sh          # Cài dependencies
./scripts/start-openclaw.sh     # Start containers
./scripts/test-agents.sh auth   # Test auth
```

### **Hàng ngày (Morning)**
```bash
cd openclaw_agent
git pull                           # Update code
./scripts/start-openclaw.sh        # Start containers
./scripts/test-agents.sh quick-check  # Check status
```

### **Làm việc**
```bash
# Terminal 1
./scripts/start-openclaw.sh
docker logs -f openclaw-gateway  # Watch logs

# Terminal 2
./scripts/test-agents.sh auth     # Run test
./scripts/test-agents.sh generate # Or this
```

### **Chia sẻ với team (Tailscale)**
```bash
./scripts/enable-direct-ssh.sh tailscale
# Share Tailscale IP với team members
# Họ có thể SSH + truy cập web UI
```

---

## ⚙️ Environment Variables

File: `docker/.env`

```bash
# AI Provider (chọn 1)
ANTHROPIC_API_KEY=sk-...      # Claude (recommended)
OPENAI_API_KEY=sk-...         # GPT
DEEPSEEK_API_KEY=sk-...       # DeepSeek

# Optional
GITHUB_TOKEN=ghp_...          # For git push
```

**Chỉnh sửa:**
```bash
nano docker/.env
docker compose restart
```

---

## 📊 Health Check

```bash
./scripts/test-agents.sh quick-check

# Output:
# ✓ .env file
# ✓ Gateway running
# ✓ VNC accessible
# ✓ Docker containers
# ✓ Auth status
```

---

## 🆘 Help

```bash
# Script help
./scripts/start-openclaw.sh --help
./scripts/test-agents.sh help
./scripts/enable-direct-ssh.sh help

# View README
cat README.md
```

---

## 📚 Related Docs

- [Setup WSL](SETUP.md) - First-time setup
- [Android SSH](ANDROID_SSH_GUIDE.md) - SSH from phone
- [Enable Remote Access](../scripts/enable-direct-ssh.sh) - Tailscale, Port Forward
- [Supervisor Spec](../supervisor/SUPERVISOR_SPEC.md) - Agent orchestration
