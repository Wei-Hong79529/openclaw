# 使用官方映像檔
FROM ghcr.io/openclaw/openclaw:2026.4.26

USER root

# 1. 安裝 gosu 並建立資料夾，同時清理 apt 快取以縮小體積
RUN apt-get update && apt-get install -y --no-install-recommends gosu && \
    mkdir -p /home/node/.openclaw && \
    chown -R node:node /home/node/.openclaw && \
    rm -rf /var/lib/apt/lists/*

# 2. 加入啟動腳本並賦予執行權限
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 3. 設置健康檢查 (給予 300 秒的啟動緩衝時間)
HEALTHCHECK --start-period=300s --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:18789/__openclaw__/canvas/ || exit 1

# 4. 設置 Entrypoint
ENTRYPOINT ["/start.sh"]
# 備註：這裡故意不寫 CMD，讓 start.sh 的 "$@" 自動接手原映像檔的預設啟動指令
