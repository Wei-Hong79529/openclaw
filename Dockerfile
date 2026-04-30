FROM ghcr.io/openclaw/openclaw:2026.4.26

USER root

# 預先建立資料夾（避免權限問題）
RUN mkdir -p /home/node/.openclaw

# 🚀 關鍵：預先觸發 runtime deps 安裝（zero-lock 核心）
RUN node dist/index.js gateway --help || true

# 加入腳本
COPY start.sh /start.sh
COPY healthcheck.sh /healthcheck.sh

RUN chmod +x /start.sh /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD /healthcheck.sh

ENTRYPOINT ["/start.sh"]