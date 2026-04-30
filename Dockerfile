FROM ghcr.io/openclaw/openclaw:2026.4.26

USER root

# 1. 建立資料夾並預先賦予 node 使用者權限
RUN mkdir -p /home/node/.openclaw && \
    chown -R node:node /home/node/.openclaw

# 2. 加入腳本
COPY start.sh /start.sh
# 建議移除內部的 healthcheck.sh，改用 Zeabur 控制台的 Networking 檢查
RUN chmod +x /start.sh

# 3. 關鍵：切換回 node 使用者，避免 root 執行 Node.js 產生安全性與路徑問題
USER node

# 4. 移除 Docker 內建 HEALTHCHECK (Zeabur 會自動透過 TCP Probe 檢查)
# 內建檢查過於頻繁會導致啟動階段被誤殺
ENTRYPOINT ["/start.sh"]