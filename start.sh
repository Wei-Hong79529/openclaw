#!/bin/sh
# 使用 -e 確保出錯立刻停止，方便在日誌中定位問題
set -e

echo "=== [OpenClaw Zero-Lock Boot] ==="

# 宣告路徑變數
CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/home/node/.openclaw/workspace}"

# 確保目錄存在且權限正確
# 在 Zeabur 建議使用 755 確保 node 使用者可讀寫
mkdir -p "$CONFIG_DIR" "$WORKSPACE_DIR/memory"
chmod -R 755 "$CONFIG_DIR"

# 1. 初始化基礎 Config
if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
  echo '{"gateway":{"controlUi":{"allowInsecureAuth":true}}}' > "$CONFIG_FILE"
fi

# -------------------------------
# 2. Provider 注入 (Gemini 3.0 Flash)
# -------------------------------
if [ -n "${GEMINI_API_KEY:-}" ]; then
  echo "Injecting Gemini 3.0 Flash Configuration..."
  # 修正：改用環境變數傳遞，避免 JSON 字串解析出錯
  node <<'NODE'
const fs = require('fs');
const path = "/home/node/.openclaw/openclaw.json";
try {
  const data = fs.readFileSync(path, 'utf8');
  let config = JSON.parse(data || '{}');

  config.models = config.models || {};
  config.models.providers = config.models.providers || {};

  // 配置 Google Gemini 3.0 Flash
  config.models.providers['google-gemini'] = {
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    apiKey: process.env.GEMINI_API_KEY,
    api: 'google-gemini',
    models: [{ id: 'gemini-3.0-flash', name: 'Gemini 3.0 Flash', input: ['text', 'image'] }]
  };

  // 設定為預設模型
  config.agents = config.agents || {};
  config.agents.defaults = { model: { primary: 'google-gemini/gemini-3.0-flash' } };

  fs.writeFileSync(path, JSON.stringify(config, null, 2));
  console.log('Gemini 3.0 Flash Injection Success');
} catch (e) {
  console.error('Injection Failed:', e.message);
  process.exit(1);
}
NODE
fi

# -------------------------------
# 3. 啟動程序
# -------------------------------
# 排除 BIND=lan 的錯誤，強制使用 0.0.0.0
FINAL_BIND="0.0.0.0"
FINAL_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

echo "Starting OpenClaw on $FINAL_BIND:$FINAL_PORT..."

# 🚀 關鍵：增加緩衝時間
# 給予 Node.js 載入 dist 檔案的時間，避免 Zeabur Probe 太早進來導致連線被拒絕
sleep 5

# 使用 exec 取代 shell，讓 Node.js 成為 PID 1，正確接收系統訊號
exec node dist/index.js gateway \
  --allow-unconfigured \
  --bind "$FINAL_BIND" \
  --port "$FINAL_PORT" \
  --token "${OPENCLAW_GATEWAY_TOKEN:-}"