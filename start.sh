#!/bin/bash
# 使用 -e 確保發生嚴重錯誤時及早停損，-u 檢查未定義變數
set -eu

echo "=== [OpenClaw Zero-Lock Boot] ==="

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/home/node/.openclaw/workspace}"

echo "Debug: Checking directory permissions..."
# 確保目錄建立
mkdir -p "$CONFIG_DIR" "$WORKSPACE_DIR/memory"

# 1. 初始化基礎 Config
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Debug: Creating initial config file..."
  echo '{"gateway":{"controlUi":{"allowInsecureAuth":true}}}' > "$CONFIG_FILE"
fi

# -------------------------------
# 2. Provider 注入 (Gemini 3 Flash)
# -------------------------------
if [ -n "${GOOGLE_API_KEY:-}" ]; then
  echo "Debug: Injecting Gemini Provider..."
  node <<'NODE'
const fs = require('fs');
const path = "/home/node/.openclaw/openclaw.json";
try {
  const data = fs.readFileSync(path, 'utf8');
  let config = JSON.parse(data || '{}');

  config.models = config.models || {};
  config.models.providers = config.models.providers || {};

  config.models.providers['google-gemini'] = {
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    apiKey: process.env.GOOGLE_API_KEY,
    api: 'google-generative-ai',
    models: [{
        id: 'gemini-3-flash-preview',
        name: 'gemini-3-flash-preview',
        input: ['text', 'image']
      }]
  };

  config.agents = config.agents || {};
  config.agents.defaults = {
    model: { primary: 'google-gemini/gemini-3-flash-preview' }
  };

  fs.writeFileSync(path, JSON.stringify(config, null, 2));
  console.log('Debug: Gemini Injection Success');
} catch (e) {
  console.error('Debug: Injection Error ->', e.message);
  process.exit(1);
}
NODE
fi

# -------------------------------
# 3. 清理舊鎖文件與修復權限 (關鍵！)
# -------------------------------
echo "Debug: Cleaning up locks and fixing permissions..."
rm -rf /home/node/.openclaw/plugin-runtime-deps/*/.*lock* 2>/dev/null || true

# 將所有剛才由 root 建立/修改的檔案，將擁有權交還給 node 使用者
# 這是 Zeabur 掛載 Volume 不會崩潰的關鍵
chown -R node:node /home/node/.openclaw

# -------------------------------
# 4. 啟動程序
# -------------------------------
FINAL_BIND="lan"
FINAL_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

echo "Starting OpenClaw on $FINAL_BIND:$FINAL_PORT..."

# 使用 gosu 切換回 node 身分執行，確保 PID 1 與訊號傳遞正常
exec gosu node node dist/index.js gateway \
  --allow-unconfigured \
  --bind "$FINAL_BIND" \
  --port "$FINAL_PORT" \
  --token "${OPENCLAW_GATEWAY_TOKEN:-}"
