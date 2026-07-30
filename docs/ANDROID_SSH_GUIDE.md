# SSH từ điện thoại Android 📱

Có, bạn có thể SSH vào laptop A từ điện thoại Android! Đây là cách dễ nhất.

## 🎯 Cách nhanh nhất (Termux)

### Bước 1: Setup laptop A (có sẵn sau khi chạy setup script)
```bash
git pull openclaw_agent
cd openclaw_agent
./scripts/enable-direct-ssh.sh tailscale
# Sau đó: sudo tailscale up
# -> Lấy Tailscale IP (ví dụ: 100.64.x.x)
```

### Bước 2: Setup điện thoại Android

#### Tùy chọn A: Termux (Khuyến cáo ⭐)

**Cài đặt:**
1. Mở Google Play hoặc F-Droid
2. Tìm "Termux"
3. Cài đặt
4. Mở Termux

**Đăng nhập Tailscale:**
```bash
# Termux shell
pkg install tailscale

# Kết nối Tailscale
tailscale up

# Follow link, login, back to Termux
```

**SSH vào laptop:**
```bash
# Lấy IP laptop (từ enable-direct-ssh.sh output)
ssh user@100.64.x.x

# Hoặc dùng machine name
ssh user@openclaw-machine
```

**Mở cổng VNC (optional):**
```bash
# Sau khi SSH vào laptop
# Xem OpenClaw (port 6080)
# Từ Android browser: http://100.64.x.x:6080
```

---

#### Tùy chọn B: JuiceSSH (UI đẹp)

**Cài đặt:**
1. Google Play → "JuiceSSH"
2. Cài đặt + Mở

**Setup SSH:**
1. Tab "Connections"
2. "+" (add) → "SSH"
3. Điền:
   - **Host:** 100.64.x.x (Tailscale IP)
   - **Port:** 22
   - **User:** cuong (hoặc user của bạn)
   - **Auth:** SSH Key (hoặc Password)
4. **Connect**

**Cộp SSH key (nếu không dùng password):**
```bash
# Trên laptop
cat ~/.ssh/id_rsa.pub

# Copy, rồi paste vào JuiceSSH config
```

---

#### Tùy chọn C: Connectbot (Nhẹ)

**Cài đặt:**
1. Google Play → "ConnectBot"
2. Cài + Mở

**Setup:**
1. "Menu" → "Open" hoặc click "+"
2. Paste: `user@100.64.x.x:22`
3. Tap → **Connect**
4. Accept fingerprint
5. Login

---

## 🔗 SSH từ Android (Tất cả phương pháp)

### Tailscale (Recommended)
```
Laptop:  ./scripts/enable-direct-ssh.sh tailscale
Phone:   Termux / JuiceSSH + Tailscale
Command: ssh user@tailscale-ip
```

### Port Forward (Local network)
```
Wifi:    Same WiFi network (laptop + phone)
Command: ssh user@laptop-local-ip
# Ví dụ: ssh cuong@192.168.1.100
```

### Reverse SSH Tunnel
```
Laptop:  ./scripts/enable-direct-ssh.sh reverse-tunnel
Phone:   ssh -p 2222 user@vps-ip
```

---

## ⚙️ Setup SSH Key (Optional nhưng khuyến cáo)

### Tạo key (trên laptop):
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
cat ~/.ssh/id_rsa  # Copy private key
```

### Import key vào Termux:
```bash
# Termux
echo "paste-private-key-content-here" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

# Hoặc:
scp -r ~/.ssh user@laptop:/tmp/
# rồi copy vào Termux
```

### Import key vào JuiceSSH:
1. JuiceSSH → Menu → "Manage Keys"
2. "+" → Paste content của id_rsa
3. Save

---

## 🎮 Dùng OpenClaw từ Android

### Option 1: Terminal (Termux)
```bash
# SSH vào laptop
ssh user@tailscale-ip

# Rồi bạn có thể:
# - Chạy ./scripts/test-agents.sh
# - Kiểm tra Docker containers
# - Quản lý files
```

### Option 2: Browser (Web UI)
```
Từ Android Chrome/Firefox:
http://tailscale-ip:18789
# Truy cập OpenClaw Gateway
```

### Option 3: VNC (Xem GUI)
```
Từ Android VNC client (ví dụ: VNC Viewer):
Máy: tailscale-ip
Port: 6080
# Xem desktop + browser automation
```

---

## 🚀 Ví dụ workflow

**Laptop A (Ubuntu WSL):**
```bash
$ ./scripts/enable-direct-ssh.sh tailscale
[OK] Tailscale IP: 100.64.x.x
```

**Phone (Termux):**
```bash
$ tailscale up
# Login + OK

$ ssh cuong@100.64.x.x
cuong@openclaw-machine:~$ ./scripts/test-agents.sh auth
# Running test...
```

**Browser phone:**
```
Mở Chrome: http://100.64.x.x:18789
# Xem OpenClaw Web UI
```

---

## 🆘 Troubleshoot

### "Connection refused"
- SSH service chưa chạy: `sudo service ssh start`
- Firewall block: `sudo ufw allow 22`

### "Network unreachable"
- Tailscale chưa kết nối: `tailscale status`
- Cùng account? Vào https://login.tailscale.com/

### Chậm
- Dùng Tailscale (P2P tự động)
- Hoặc Port Forward (nếu cùng WiFi)

### Không thấy machine name
- Dùng IP thay vì hostname
- Hoặc `tailscale --hostname=openclaw-machine` (custom name)

---

## 📱 Các SSH Client Android tốt

| App | Cost | Notes |
|-----|------|-------|
| Termux | Free | Mạnh nhất, full terminal |
| JuiceSSH | Free | UI đẹp, dễ dùng |
| ConnectBot | Free | Nhẹ, tương thích tốt |
| Termius | Free+ | Premium UI |
| SSHControl | Free | Đơn giản |

**Khuyến cáo: Termux** (để lại window chạy script + SSH)

---

## ❓ FAQ

**Q: Có cần root không?**
A: Không. Termux và SSH client là user-level apps.

**Q: Tailscale chạy chút nước pin?**
A: Có một chút, như bất kỳ VPN nào. Nhưng P2P nên tiết kiệm hơn ngrok.

**Q: Có an toàn không?**
A: Tailscale dùng WireGuard (được kiểm toán). SSH key auth còn an toàn hơn.

**Q: Có thể chạy script từ phone?**
A: Có, qua Termux + SSH. Lệnh như bình thường.

---

## 🔗 Links

- Termux: https://termux.com/
- Tailscale: https://tailscale.com/download
- JuiceSSH: https://play.google.com/store/apps/details?id=com.sonelli.juicessh
- ConnectBot: https://play.google.com/store/apps/details?id=org.connectbot
