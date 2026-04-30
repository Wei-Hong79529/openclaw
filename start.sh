#!/bin/sh
set -eu

echo "=== [OpenClaw Zero-Lock Boot] ==="

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/home/node/.openclaw/workspace}"

mkdir -p "$CONFIG_DIR" "$WORKSPACE_DIR/memory"
chmod 700 "$CONFIG_DIR"

# -------------------------------
# 1. Config（只初始化）
# -------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
  cat >"$CONFIG_FILE" <<EOF
{"gateway":{"controlUi":{"allowInsecureAuth":true}}}
EOF
  chmod 600 "$CONFIG_FILE"
fi

# -------------------------------
# 2. Provider（安全注入）
# -------------------------------
if [ -n "${ZEABUR_AI_HUB_API_KEY:-}" ] && ! grep -q '"zeabur-ai"' "$CONFIG_FILE"; then
  node <<'NODE'
const fs = require("fs");
const path = "/home/node/.openclaw/openclaw.json";

try {
  let c = JSON.parse(fs.readFileSync(path, "utf8"));

  c.models = c.models || {};
  c.models.providers = c.models.providers || {};

  c.models.providers["zeabur-ai"] = {
    baseUrl: "https://hnd1.aihub.zeabur.ai/v1",
    apiKey: process.env.ZEABUR_AI_HUB_API_KEY,
    api: "openai-completions",
    models: [
      { id: "gpt-5-mini", name: "GPT-5 Mini", input: ["text"] }
    ]
  };

  c.agents = c.agents || {};
  c.agents.defaults = c.agents.defaults || {};
  c.agents.defaults.model = c.agents.defaults.model || {
    primary: "zeabur-ai/gpt-5-mini"
  };

  fs.writeFileSync(path, JSON.stringify(c, null, 2));
} catch (e) {
  console.error(e);
}
NODE
fi

# -------------------------------
# 3. Workspace
# -------------------------------
if [ ! -f "$WORKSPACE_DIR/MEMORY.md" ]; then
  echo "# Memory" > "$WORKSPACE_DIR/MEMORY.md"
fi

# -------------------------------
# 4. 啟動（唯一進程）
# -------------------------------
echo "Starting OpenClaw on Port: ${OPENCLAW_GATEWAY_PORT:-18789}..."
echo "Target Port: ${OPENCLAW_GATEWAY_PORT:-18789}"
echo "Config File: $(ls -l $CONFIG_FILE)"

# 確保權限完全開放給執行者
chmod -R 777 "$CONFIG_DIR"

# 確保我們監聽的是 0.0.0.0 (重要！)
# 有些版本會優先讀取 config 裡的設定，我們用參數強制蓋掉它
exec node dist/index.js gateway \
  --allow-unconfigured \
  --bind "0.0.0.0" \
  --port "${OPENCLAW_GATEWAY_PORT:-18789}" \
  --token "${OPENCLAW_GATEWAY_TOKEN:-}"  