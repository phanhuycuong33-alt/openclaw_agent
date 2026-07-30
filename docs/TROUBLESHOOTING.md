# Troubleshooting Agent Issues

## Crestodian Loop Issue

### Vấn đề
Khi chạy agent, Crestodian liên tục lặp lại:
```
Hi, I'm Crestodian.
Gateway: not reachable at ws://127.0.0.1:18789; I already did the first probe.
I can start debugging with gateway status, or queue restart gateway for approval.
───────────────────────────────────────────────────
[Lặp lại mãi mãi...]
```

**Root Cause:**
1. Crestodian interactive CLI không kết nối được Gateway
2. Hiển thị status + options, chờ user input
3. Nhưng không có cách nhập input → không có action
4. CLI lặp lại status mãi mãi (vô hạn)
5. **Vòng lặp vô tận!**

### Nguyên nhân
- Gateway cấu hình ở `http://localhost:18789` (HTTP)
- Crestodian tìm ở `ws://127.0.0.1:18789` (WebSocket + IP address)
- Mismatch: Protocol khác (http vs ws), hostname khác (localhost vs 127.0.0.1)
- Kết nối thất bại → không có user input → vòng lặp

### Giải pháp

#### Cách 1: Dùng `run-agent.sh` (Khuyến cáo ⭐⭐⭐)
Script này tránh vòng lặp bằng cách:
1. **Sử dụng HTTP API** thay vì interactive Crestodian CLI
2. **Timeout 120s** khi fallback to docker exec (prevent infinite loop)
3. **Tự động đọc spec files** và inject vào prompt
4. **Không yêu cầu user input** → không loop

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
- ✅ Không vòng lặp (HTTP API + timeout)
- ✅ Tự động đọc spec files
- ✅ Real-time output
- ✅ Auto-exit (không chờ user input)

**Workflow:**
```
run-agent.sh → Check Docker → Send to HTTP API → Get response → Exit
                                    ↓
                          (Fallback: timeout docker exec)
```

---

#### Cách 2: Fix Gateway Config (Ngăn chặn ở gốc)

**Already Fixed! ✅**

File `docker/openclaw.mjs` đã được update:
```javascript
export default {
  "gateway": {
    "mode": "local",
    "bind": "localhost",    // Changed from "lan"
    "hostname": "localhost", // Added
    "protocol": "http",     // Added (explicit)
    "port": 18789
  }
  // ...
};
```

Restart để apply:
```bash
cd docker
docker compose down
docker compose up -d
```

Giờ Gateway sẽ accessible tại `http://localhost:18789` (match với Crestodian expectations).

---

#### Cách 3: Manual Fix (nếu Cách 1 + 2 không work)

Khởi động mới OpenClaw:
```bash
docker compose down
docker compose up -d

# Verify Gateway
curl http://localhost:18789/api/status
# Should return: {"status":"ready"}
```

Nếu vẫn bị loop, sử dụng Cách 1 (`run-agent.sh`) vì nó không phụ thuộc vào Gateway connection.

---

## Comparison: test-agents.sh vs run-agent.sh

| Tiêu chí | test-agents.sh | run-agent.sh | Winner |
|----------|---|---|---|
| Cách chạy | HTTP API polling | HTTP API + docker exec (timeout) | 🔧 Tùy |
| Crestodian loop | ⚠️ Có thể | ✅ Không (timeout) | run-agent |
| Auto spec read | Có (built-in) | ✅ Có (from files) | 🤝 Bằng |
| Output | Polling status | Realtime | run-agent |
| User input | Chờ enter | ❌ Không cần | run-agent |
| Exit behavior | Manual chọn action | ✅ Auto-exit | run-agent |
| Error handling | Status polling | ✅ Timeout fallback | run-agent |

**→ Khuyến cáo: Luôn dùng `run-agent.sh` để tránh vòng lặp**

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

## Is Agent Actually Working?

### What You'll See
```bash
$ ./scripts/run-agent.sh auth

[INFO] Waiting for containers to reach healthy state...
[OK] Gateway is healthy: openclaw-gateway: Up 20s (healthy)
[INFO] Sending to supervisor (HTTP API)...
[OK] API response: Not found        ← This is NORMAL! Don't worry
[INFO] Using direct CLI execution (docker exec)...

[Agent output... might be long or empty]

[OK] Agent execution complete

How to verify it worked:
  Option 1: Check result files (BEST)
    $ ls -la ~/.openclaw/workspace/worker-*-result.md
```

**"API response: Not found" is NORMAL** - means HTTP API not available, script falls back to docker exec (which is better anyway).

---

## Verify Agent Actually Ran

### Best Method: Check Result Files
```bash
# List results
ls -la ~/.openclaw/workspace/worker-*-result.md

# View result
cat ~/.openclaw/workspace/worker-auth-result.md

# Expected output (example):
# Status: PASS
# Task: Check if GitHub is authenticated
# Result: Successfully authenticated as username
```

### Real-time Monitoring: VNC Browser
```bash
# Open in browser
http://localhost:6080

# You'll see:
# - Agent opening Firefox/Chrome
# - Navigating to GitHub
# - Logging in
# - Writing results
```

### Debug: Check Logs
```bash
# View gateway logs (before running agent)
docker logs -f openclaw-gateway

# Run agent (in another terminal)
./scripts/run-agent.sh auth

# Watch logs update with agent activity
```

---

## Common Output

### ✅ SUCCESS
```
[INFO] Using direct CLI execution (docker exec)...
[Output from agent...]
[OK] Agent execution complete

$ cat ~/.openclaw/workspace/worker-auth-result.md
Status: PASS
```

### ⚠️ TIMEOUT (But Still Working!)
```
[WARN] Execution timed out (120s) - agent is still processing in background

→ Agent is still running, check results in 30 seconds
→ Don't restart - let it finish
```

### ❌ ERROR
```
[ERROR] Agent execution failed with exit code 1
[Error output...]

→ Check logs: docker compose logs
→ Restart: docker compose restart
```

---

## Debug Commands

### Check Gateway status
```bash
# Test if gateway responds
curl http://localhost:18789/api/status

# Docker logs (realtime)
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
# 1. Start containers (waits for healthy state automatically)
./scripts/start-openclaw.sh

# Output:
# [INFO] Waiting for containers to reach healthy state...
# ⏳ Waiting... (0s elapsed)
# [OK] Containers healthy: openclaw-gateway: Up 12s (healthy), openclaw-cli: Up 10s
```

### Wait for Healthy State
**Important:** Containers have 3 states:
```
1. health: starting  ← Cannot use agent yet (container still initializing)
2. health: starting  ← Wait...
3. health: healthy   ← Ready! ✅ Can run agent now
```

If you see `health: starting`, **wait a bit more** (usually 10-30 seconds).

Check status:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"

# OUTPUT (need to wait):
# NAME              STATUS
# openclaw-gateway  Up 5s (health: starting)
# openclaw-cli      Up 4s (health: starting)

# OUTPUT (ready):
# NAME              STATUS
# openclaw-gateway  Up 20s (healthy)
# openclaw-cli      Up 18s (healthy)
```

### Test Agents (New way with run-agent.sh)
```bash
# run-agent.sh automatically waits for healthy state
./scripts/run-agent.sh auth       # Auto waits + spec reading
./scripts/run-agent.sh generate   # ...
./scripts/run-agent.sh publish
./scripts/run-agent.sh full-flow

# Custom task (auto-spec reading)
./scripts/run-agent.sh "your task here"
```

### Monitor
```bash
# View logs (separate terminal)
docker compose logs -f

# Check result files
cat ~/.openclaw/workspace/worker-auth-result.md

# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"
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
