#!/bin/sh
PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

# 嘗試 3 次，每次隔 1 秒，給 Node.js 一點啟動緩衝
for i in 1 2 3; do
  if nc -z 127.0.0.1 "$PORT"; then
    exit 0
  fi
  sleep 1
done

exit 1