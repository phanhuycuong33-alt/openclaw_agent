#!/bin/sh

/usr/local/bin/start-vnc.sh &

exec node dist/index.js gateway \
  --bind "${OPENCLAW_GATEWAY_BIND:-lan}" \
  --port 18789
