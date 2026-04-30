#!/bin/sh
# 暫時移除 -e 讓我們能看到錯誤訊息，或是保持 -e 但確保指令強健
set -u 

echo "=== [OpenClaw Zero-Lock Boot] ==="

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/home/node/.openclaw/workspace}"

echo "Debug: Checking directory permissions..."
# 確保目錄建立，如果失敗會印出原因
mkdir -p "$CONFIG_DIR" "$WORKSPACE_DIR/memory" || echo "Warning: mkdir failed"

# 1. 初始化基礎 Config
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Debug: Creating initial config file..."
  echo '{"gateway":{"controlUi":{"allowInsecureAuth":true}}}' > "$CONFIG_FILE" || { echo "Error: Cannot write config"; exit 1; }
fi

# -------------------------------
# 2. Provider 注入 (Gemini 3.0 Flash)
# -------------------------------
if [ -n "${GEMINI_API_KEY:-}" ]; then
  echo "Debug: Injecting Gemini 3.0 Flash..."
  # 這裡增加更多 console.log 以便在 Zeabur Runtime Log 看到進度
  node <<'NODE'
const fs = require('fs');
const path = "/home/node/.openclaw/openclaw.json";
try {
  const data = fs.readFileSync(path, 'utf8');
  let config = JSON.parse(data || '{}');
  // ... 注入邏輯 ...
  fs.writeFileSync(path, JSON.stringify(config, null, 2));
  console.log('Debug: Gemini Injection Success');
} catch (e) {
  console.error('Debug: Injection Error ->', e.message);
  process.exit(1);
}
NODE
fi

# -------------------------------
# 3. 啟動程序
# -------------------------------
echo "Debug: Preparing to exec node..."
FINAL_BIND="0.0.0.0" # 強制 0.0.0.0 以避免 lan 錯誤
FINAL_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

echo "Starting OpenClaw on $FINAL_BIND:$FINAL_PORT..."
sleep 3

exec node dist/index.js gateway \
  --allow-unconfigured \
  --bind "$FINAL_BIND" \
  --port "$FINAL_PORT" \
  --token "${OPENCLAW_GATEWAY_TOKEN:-}"