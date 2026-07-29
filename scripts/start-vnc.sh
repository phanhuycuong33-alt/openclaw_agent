#!/bin/sh

Xvfb :99 -screen 0 1280x800x24 >/tmp/xvfb.log 2>&1 &
export DISPLAY=:99

sleep 2

x11vnc \
  -display :99 \
  -rfbport 5900 \
  -forever \
  -shared \
  -nopw \
  >/tmp/x11vnc.log 2>&1 &

/usr/share/novnc/utils/novnc_proxy \
  --vnc localhost:5900 \
  --listen 6080
