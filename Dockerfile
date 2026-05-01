FROM ghcr.io/openclaw/openclaw:2026.4.26

USER root

# 1. 安裝 gosu (用來在 start.sh 安全切換使用者)
# 同時建立資料夾，確保環境乾淨
RUN apt-get update && apt-get install -y gosu && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /home/node/.openclaw

# 2. 加入腳本
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 3. 移除原本的 USER node
# 理由：若在這裡切換，容器啟動時就沒權限修正 Zeabur 掛載的 Volume 權限
# 我們改由 start.sh 內部完成 chown 後再切換身分

# 4. 設置健康檢查
HEALTHCHECK --start-period=300s --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:18789/__openclaw__/canvas/ || exit 1

ENTRYPOINT ["/start.sh"]
