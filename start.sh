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
  node <<'NODE'
const fs = require('fs');
const path = "/home/node/.openclaw/openclaw.json";
try {
  const data = fs.readFileSync(path, 'utf8');
  let config = JSON.parse(data || '{}');

  config.models = config.models || {};
  config.models.providers = config.models.providers || {};

  // ✨ 關鍵修正：api 必須是 "google-generative-ai"
  config.models.providers['google-gemini'] = {
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    apiKey: process.env.GEMINI_API_KEY,
    api: 'google-generative-ai',
    models: [{ id: 'gemini-3.0-flash', name: 'Gemini 3.0 Flash', input: ['text', 'image'] }]
  };

  config.agents = config.agents || {};
  config.agents.defaults = { model: { primary: 'google-gemini/gemini-3.0-flash' } };

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
# 🚀 關鍵修正：將 FINAL_BIND 改為 OpenClaw 認可的 "lan"
FINAL_BIND="lan"
FINAL_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

echo "Starting OpenClaw on $FINAL_BIND:$FINAL_PORT..."
sleep 20

# 執行 OpenClaw
exec node dist/index.js gateway \
  --allow-unconfigured \
  --bind "$FINAL_BIND" \
  --port "$FINAL_PORT" \
  --token "${OPENCLAW_GATEWAY_TOKEN:-}"