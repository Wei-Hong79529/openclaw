#!/bin/sh
set -eu

echo "=== [OpenClaw Zero-Lock Boot] ==="

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/home/node/.openclaw/workspace}"

mkdir -p "$CONFIG_DIR" "$WORKSPACE_DIR/memory"
chmod -R 777 "$CONFIG_DIR"

# 1. 初始化 Config
if [ ! -f "$CONFIG_FILE" ]; then
  echo '{"gateway":{"controlUi":{"allowInsecureAuth":true}}}' > "$CONFIG_FILE"
fi

# -------------------------------
# 2. Provider（注入 Gemini 3.0 Flash）
# -------------------------------
if [ -n "${GEMINI_API_KEY:-}" ]; then
  echo "Injecting Gemini 3.0 Flash..."
  node -e "
const fs = require('fs');
const p = '$CONFIG_FILE';
try {
  let c = JSON.parse(fs.readFileSync(p, 'utf8'));
  c.models = c.models || {};
  c.models.providers = c.models.providers || {};
  c.models.providers['google-gemini'] = {
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    apiKey: process.env.GEMINI_API_KEY,
    api: 'google-gemini',
    models: [{ id: 'gemini-3.0-flash', name: 'Gemini 3.0 Flash', input: ['text', 'image'] }]
  };
  c.agents = c.agents || {};
  c.agents.defaults = { model: { primary: 'google-gemini/gemini-3.0-flash' } };
  fs.writeFileSync(p, JSON.stringify(c, null, 2));
  console.log('Injection Success');
} catch (e) { console.error('Injection Failed:', e); process.exit(1); }
"
fi


# -------------------------------
# 3. 啟動（唯一進程）
# -------------------------------
echo "Starting OpenClaw..."
sleep 3 # 給予系統初始化緩衝

# 確保 BIND 是 0.0.0.0 而不是 lan
FINAL_BIND="0.0.0.0"
FINAL_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

exec node dist/index.js gateway \
  --allow-unconfigured \
  --bind "$FINAL_BIND" \
  --port "$FINAL_PORT" \
  --token "${OPENCLAW_GATEWAY_TOKEN:-}"