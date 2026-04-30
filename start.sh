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
# 2. Provider（注入 Gemini 3.0 Flash）
# -------------------------------
if [ -n "${GEMINI_API_KEY:-}" ] && ! grep -q '"google-gemini"' "$CONFIG_FILE"; then
  echo "Configuring Gemini 3.0 Flash..."
  node <<'NODE'
const fs = require("fs");
const path = "/home/node/.openclaw/openclaw.json";

try {
  let c = JSON.parse(fs.readFileSync(path, "utf8"));

  c.models = c.models || {};
  c.models.providers = c.models.providers || {};

  // 設定 Google Gemini Provider
  c.models.providers["google-gemini"] = {
    baseUrl: "https://generativelanguage.googleapis.com/v1beta",
    apiKey: process.env.GEMINI_API_KEY,
    api: "google-gemini",
    models: [
      { id: "gemini-3.0-flash", name: "Gemini 3.0 Flash", input: ["text", "image"] }
    ]
  };

  c.agents = c.agents || {};
  c.agents.defaults = c.agents.defaults || {};
  c.agents.defaults.model = c.agents.defaults.model || {
    primary: "google-gemini/gemini-3.0-flash"
  };

  fs.writeFileSync(path, JSON.stringify(c, null, 2));
  console.log("Gemini 3.0 Flash configured successfully.");
} catch (e) {
  console.error("Failed to inject Gemini config:", e);
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