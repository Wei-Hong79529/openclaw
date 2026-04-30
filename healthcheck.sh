#!/bin/sh

PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

# 檢查 port 是否有在 listen
nc -z 127.0.0.1 "$PORT" >/dev/null 2>&1 || exit 1

exit 0