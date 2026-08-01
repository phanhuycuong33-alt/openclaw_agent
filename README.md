# OpenClaw Agent

Multi-agent system for automated MCP server development and publishing.

## Quick Start (WSL)

### Lần đầu tiên (Setup 1 lần)

```bash
# 1. Clone repository
git clone https://github.com/phanhuycuong33-alt/openclaw_agent.git
cd openclaw_agent

# 2. Run setup (cài Docker, Node, SSH, config API key)
chmod +x scripts/*.sh
./scripts/setup-wsl.sh

# 3. Start OpenClaw
./scripts/start-openclaw.sh

# 4. Test agents
./scripts/test-agents.sh
```

### Các lần sau (Daily use)

```bash
cd openclaw_agent

# 1. Pull latest changes
git pull

# 2. Start OpenClaw  
./scripts/start-openclaw.sh

# 3. Test/Use agents
./scripts/test-agents.sh        # Check environment
./scripts/test-agents.sh auth   # Test GitHub auth
./scripts/test-agents.sh cli    # Chat with Supervisor
```

### Dừng OpenClaw

```bash
cd docker && docker compose down
```

## What Gets Installed

The setup script automatically installs:

| Component | Purpose |
|-----------|---------|
| Docker CE | Container runtime |
| Docker Compose | Multi-container orchestration |
| Node.js 20 | JavaScript runtime |
| Git | Version control |
| SSH keys | GitHub authentication |
| Xvfb | Virtual display |
| x11vnc | VNC server |
| AI API Key | Anthropic/OpenAI for agents |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       SUPERVISOR                            │
│                   (Orchestrates Workers)                    │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┬─────────────┐
        ▼             ▼             ▼             ▼
┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐
│  Worker   │  │  Worker   │  │  Worker   │  │  Worker   │
│   Auth    │  │ Generate  │  │  Publish  │  │  Report   │
│           │  │   Code    │  │   MCP     │  │           │
└───────────┘  └───────────┘  └───────────┘  └───────────┘
```

### Workers

- **Worker Auth**: Manages browser authentication sessions
- **Worker Generate Code**: Creates MCP server projects from tasks
- **Worker Publish MCP**: Publishes MCP servers to marketplaces via browser automation
- **Worker Report**: Standardized reporting format

## Ports

| Port | Service |
|------|---------|
| 18789 | OpenClaw Gateway |
| 18790 | Gateway Bridge |
| 6080 | VNC/noVNC (browser view) |
| 3978 | MS Teams integration |

## Directory Structure

```
~/.openclaw/              # OpenClaw config and state
~/.openclaw/workspace/    # Workspace for projects
~/.openclaw-auth-profile-secrets/  # Auth profiles
```

## Troubleshooting

### Docker permission denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### GitHub SSH not working
```bash
# Start SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Test connection
ssh -T git@github.com
```

### Verify environment
```bash
./scripts/verify-environment.sh
```

## License

See LICENSE file.

# mo rong kien thuc
Đúng rồi, bạn hiểu gần đúng. Cú pháp đầy đủ là:

docker compose [options] <command>

Ví dụ:

docker compose -f docker-compose-gateway.yml build

Trong đó:

docker → chương trình Docker
compose → module dùng để đọc file YAML
-f docker-compose-gateway.yml → chỉ định file compose sẽ dùng
build → command

Docker sẽ đọc file docker-compose-gateway.yml, tìm tất cả các service có mục build: rồi build image.

Ví dụ file:

services:
  openclaw-gateway:
    build:
      context: .
      dockerfile: docker/Dockerfile.openclaw-ssh
    image: openclaw-ssh:latest

  openclaw-cli:
    build:
      context: .
      dockerfile: docker/Dockerfile.openclaw-ssh
    image: openclaw-ssh:latest

Khi chạy

docker compose -f docker-compose-gateway.yml build

Docker sẽ:

Đọc YAML.
Thấy có 2 service.
Với mỗi service có build:
lấy context
mở Dockerfile
build image.
Gắn tên image là
openclaw-ssh:latest

Một số command Compose thường gặp:

docker compose build

→ build image.

docker compose up

→ nếu image chưa có thì build, sau đó tạo container và chạy.

docker compose up --build

→ ép build lại rồi chạy.

docker compose down

→ xóa các container của project.

docker compose restart

→ restart container.

docker compose exec openclaw-cli bash

→ chạy lệnh trong container đang chạy.

Có thể hình dung Compose như sau:

docker-compose.yml
        │
        ▼
docker compose
        │
        ├── build
        ├── up
        ├── down
        ├── restart
        └── exec

Nó giống như một "project manager" cho Docker. Thay vì phải gõ rất nhiều lệnh docker build, docker run, docker network create, docker volume create..., bạn chỉ mô tả tất cả trong một file YAML, rồi docker compose sẽ thực hiện theo mô tả đó.

Đến đây bạn đã nắm khá đúng các lớp rồi:

Docker Engine
    │
    └── Docker Compose
            │
            └── đọc docker-compose-gateway.yml
                    │
                    ├── build image
                    ├── tạo network
                    ├── tạo volume
                    ├── tạo container
                    └── start service

Đó cũng là lý do OpenClaw không cần viết code để tạo container: toàn bộ việc dựng môi trường được Docker Compose đảm nhiệm thông qua file YAML.

vi du yaml file nhu sau
    healthcheck:
      test:
        [
          "CMD",
          "node",
          "-e",
          "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))",
        ]
      interval: 5s
      timeout: 2s
      retries: 5
      start_period: 10s
thi lenh docker la gi

Đây là điểm nhiều người mới học Docker hay nhầm.

Đoạn YAML này không tương ứng với một lệnh docker mà bạn phải gõ. Nó chỉ là cấu hình mà Docker Compose sẽ tự chuyển thành các tham số khi tạo container.

Ví dụ:

healthcheck:
  test:
    [
      "CMD",
      "node",
      "-e",
      "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))",
    ]
  interval: 5s
  timeout: 2s
  retries: 5
  start_period: 10s

Khi bạn chạy

docker compose up -d

hoặc

docker compose create

Docker Compose sẽ đọc phần này và tự gọi Docker Engine với các tham số health check tương ứng.

Nếu không dùng Compose, thì lệnh docker run tương đương sẽ rất dài, ví dụ:

docker run \
  --health-cmd="node -e \"fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\"" \
  --health-interval=5s \
  --health-timeout=2s \
  --health-retries=5 \
  --health-start-period=10s \
  openclaw-ssh:latest

Nghĩa là:

YAML	docker run
healthcheck.test	--health-cmd
interval	--health-interval
timeout	--health-timeout
retries	--health-retries
start_period	--health-start-period
Điều Docker làm phía sau

Sau khi container được tạo, Docker Engine sẽ tự động chạy định kỳ:

node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

mỗi 5 giây.

Nếu lệnh trả về:

exit 0 → container healthy.
exit 1 → container unhealthy.

Đó là lý do khi chạy:

docker ps

bạn thấy:

STATUS
Up 2 minutes (healthy)

hoặc

Up 2 minutes (unhealthy)

Chính là kết quả của healthcheck, không phải OpenClaw tự ghi trạng thái đó. Docker Engine là thành phần thực hiện việc kiểm tra này.

ah vay kieu yaml giup giam bot lenh tren cmd 

Đúng rồi. Hiểu như vậy là rất chính xác.

Có thể xem Docker Compose YAML giống như một "file cấu hình cho hàng loạt lệnh docker run".

Ví dụ nếu không có YAML, bạn sẽ phải gõ một lệnh rất dài:

docker run \
  --name openclaw-gateway \
  -p 18789:18789 \
  -p 6080:6080 \
  -v ~/.openclaw:/home/node/.openclaw \
  --health-cmd="..." \
  --health-interval=5s \
  --restart unless-stopped \
  -e OPENCLAW_HOME=/home/node/.openclaw \
  openclaw-ssh:latest

Rất khó đọc và khó sửa.

Trong docker-compose-gateway.yml thì chỉ cần:

services:
  openclaw-gateway:
    image: openclaw-ssh:latest
    ports:
      - "18789:18789"
      - "6080:6080"
    volumes:
      - ~/.openclaw:/home/node/.openclaw
    environment:
      OPENCLAW_HOME: /home/node/.openclaw
    healthcheck:
      ...

Sau đó chỉ cần:

docker compose up -d

Compose sẽ tự:

tạo network
tạo volume mount
map port
set environment variables
tạo healthcheck
tạo container
start container
Có thể hình dung như thế này
docker-compose.yml
        │
        ▼
Docker Compose
        │
        ├── docker build ...
        ├── docker network create ...
        ├── docker volume create ...
        ├── docker create ...
        ├── docker run ...
        └── docker start ...

Compose giống như một "script tự động hóa Docker".

Thực tế, khoảng 95% các dự án hiện nay (OpenClaw, GitLab, Nextcloud, n8n, Home Assistant, MinIO, PostgreSQL...) đều dùng docker-compose.yml hoặc compose.yaml. Rất ít người còn tự gõ các lệnh docker run dài hàng chục tham số nữa, vì YAML dễ đọc, dễ chia sẻ và có thể đưa lên Git để quản lý phiên bản.

