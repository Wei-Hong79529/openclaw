FROM ghcr.io/openclaw/openclaw:2026.4.26

USER root

# 加入腳本
COPY start.sh /start.sh
COPY healthcheck.sh /healthcheck.sh

RUN chmod +x /start.sh /healthcheck.sh

# 健康檢查（K8s / Zeabur 都吃得到）
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD /healthcheck.sh

# 完全接管啟動
ENTRYPOINT ["/start.sh"]