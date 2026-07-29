#!/usr/bin/env bash
set -e
echo "=== Starting SSH agent ==="
if [ -z "$SSH_AUTH_SOCK" ] || ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add ~/.ssh/id_ed25519
fi
echo "=== SSH identities ==="
ssh-add -l
echo "=== Starting Docker ==="
sudo service docker start >/dev/null 2>&1 || true
echo "=== Starting OpenClaw ==="
cd ~/openclaw/openclaw
docker compose up -d
echo "=== OpenClaw Ready ==="
