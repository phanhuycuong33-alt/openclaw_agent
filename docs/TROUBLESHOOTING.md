# Troubleshooting Agent Issues

## Crestodian Loop Issue

### Vấn đề
Khi chạy agent, Crestodian liên tục hiển thị:
```
Gateway: not reachable at ws://127.0.0.1:18789
I can start debugging with gateway status, or queue restart gateway for approval.
```

Đây là vòng lặp (loop) vì:
1. Crestodian start + show status
2. Không kết nối được Gateway (URL sai)
3. Offer để restart Gateway
4. Nhưng không có action được chọn → lại hiển thị status
5. **Loop!**

### Nguyên nhân
- Gateway cấu hình ở `http://localhost:18789` (HTTP)
- Crestodian tìm ở `ws://127.0.0.1:18789` (WebSocket + IP)
- Mismatch → không kết nối

### Giải pháp

#### Cách 1: Dùng `run-agent.sh` (Khuyến cáo ⭐)
Script mới này tránh vòng lặp bằng cách chạy agent trực tiếp:

```bash
# Quick tasks
./scripts/run-agent.sh auth
./scripts/run-agent.sh generate
./scripts/run-agent.sh publish
./scripts/run-agent.sh full-flow

# Custom task
./scripts/run-agent.sh "đọc spec và làm auth"
```

**Ưu điểm:**
- ✅ Tự động đọc spec files
- ✅ Không vòng lặp
- ✅ Direct CLI execution
- ✅ Như bạn muốn: `docker compose exec ... --message "..."`

---

#### Cách 2: Fix Gateway URL (nếu dùng Crestodian interactive)

**A. Cập nhật openclaw.mjs:**
```bash
nano ~/.openclaw/openclaw.mjs
```

Thêm hoặc sửa:
```javascript
export default {
  "gateway": {
    "mode": "local",
    "bind": "127.0.0.1",  // Hoặc "localhost"
    "port": 18789,
    "hostname": "localhost"  // Add this
  },
  "browser": {
    "headless": false,
    "display": ":99"
  }
};
```

Restart:
```bash
docker compose down
docker compose up -d
```

**B. Hoặc set environment variable:**
```bash
export OPENCLAW_GATEWAY_URL="http://localhost:18789"
docker compose up -d
```

---

## Comparison: test-agents.sh vs run-agent.sh

### test-agents.sh (Polling-based)
```bash
./scripts/test-agents.sh auth
```
- ✅ Gọi supervisor qua HTTP API
- ✅ Poll for result files
- ✅ Show docker logs while waiting
- ⚠️ Kỳ lạ nếu gateway không respond

### run-agent.sh (Direct CLI)
```bash
./scripts/run-agent.sh auth
```
- ✅ Chạy agent trực tiếp
- ✅ Tự động đọc spec files
- ✅ Không vòng lặp
- ✅ Output realtime
- ✅ Như: `docker compose exec openclaw-cli node dist/index.js agent --message "..."`

**→ Khuyến cáo: Dùng `run-agent.sh`**

---

## Usage Examples

### Chạy ngắn gọn
```bash
# Test auth
./scripts/run-agent.sh auth

# Generate code
./scripts/run-agent.sh generate

# Publish to GitHub
./scripts/run-agent.sh publish

# Full flow
./scripts/run-agent.sh full-flow
```

### Custom task
```bash
# Tự động đọc spec + thực hiện task
./scripts/run-agent.sh "Mở Gmail, kiểm tra email chưa đọc"

# Spec sẽ được auto-inject vào prompt
```

### Giống command của bạn
```bash
# Trước (manual command)
docker compose exec openclaw-cli node dist/index.js agent --message "đọc spec và làm auth"

# Giờ (wrapper script, auto spec reading)
./scripts/run-agent.sh auth
# Hoặc
./scripts/run-agent.sh "auth with spec"
```

---

## Debug Commands

### Check Gateway status
```bash
# HTTP
curl http://localhost:18789/api/status

# WebSocket (using websocat)
websocat ws://localhost:18789/ws

# Docker logs
docker logs -f openclaw-gateway
docker logs -f openclaw-cli
```

### Check Spec Files
```bash
# View specs
cat supervisor/SUPERVISOR_SPEC.md
cat workers/WORKER_AUTH.md

# Check result files
ls -la ~/.openclaw/workspace/worker-*-result.md
cat ~/.openclaw/workspace/worker-auth-result.md
```

### Manual Agent Execution (giống run-agent.sh)
```bash
# Build prompt with specs (manually)
PROMPT="$(cat supervisor/SUPERVISOR_SPEC.md)..."

# Run agent
docker compose exec openclaw-cli node dist/index.js agent --message "$PROMPT"
```

---

## Gateway Connection Issues

### Check if Gateway is running
```bash
docker ps | grep openclaw
```

### Check Gateway logs
```bash
docker compose logs openclaw-gateway | tail -50
```

### Restart Gateway
```bash
docker compose restart openclaw-gateway
# hoặc
docker compose down && docker compose up -d
```

### Verify Gateway is accessible
```bash
# HTTP (Gateway)
curl -v http://localhost:18789

# WebSocket
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
  http://localhost:18789/ws
```

---

## Crestodian Agent (Interactive CLI)

Nếu muốn dùng Crestodian interactive CLI (cảnh báo: có thể bị loop):

```bash
# Start Crestodian
docker compose exec openclaw-cli

# Trong container
node dist/index.js agent
```

**Tips:**
- Gõ: `auth` → run auth task
- Gõ: `generate` → generate code
- Gõ: `help` → show commands
- Ctrl+C → exit
- Nếu loop → bấm Ctrl+C + dùng `run-agent.sh`

---

## Recommended Workflow

### Morning Startup
```bash
./scripts/start-openclaw.sh

# Check status
docker ps
```

### Test Agents (New way with run-agent.sh)
```bash
# Option 1: Quick test
./scripts/run-agent.sh auth

# Option 2: Generate + Publish
./scripts/run-agent.sh generate
./scripts/run-agent.sh publish

# Option 3: Full flow
./scripts/run-agent.sh full-flow

# Option 4: Custom task (auto-spec reading)
./scripts/run-agent.sh "your task here"
```

### Monitor
```bash
# View logs (separate terminal)
docker compose logs -f

# Check result files
cat ~/.openclaw/workspace/worker-auth-result.md
```

### Shutdown
```bash
docker compose down
```

---

## Environment Variables

File: `docker/.env`

```bash
# AI Model
DEEPSEEK_API_KEY=sk-...
DEEPSEEK_MODEL=deepseek-chat

# GitHub
GITHUB_TOKEN=ghp_...

# Gateway (optional)
OPENCLAW_GATEWAY_URL=http://localhost:18789
```

Update & restart:
```bash
nano docker/.env
docker compose restart
```

---

## Related Docs

- [DAILY_WORKFLOW.md](DAILY_WORKFLOW.md) - Daily startup workflow
- [ANDROID_SSH_GUIDE.md](ANDROID_SSH_GUIDE.md) - SSH from phone
- [SETUP.md](SETUP.md) - First-time setup
