FROM alpine:latest

# 定义构建参数 (由 docker buildx 自动传入)
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

# 安装依赖
RUN apk add --no-cache \
    curl openssl socat supervisor jq libqrencode-tools coreutils tzdata ca-certificates bash

ENV TZ=Asia/Shanghai
WORKDIR /app

# 安装 Acme.sh
RUN curl https://get.acme.sh | sh && \
    ln -s /root/.acme.sh/acme.sh /usr/local/bin/acme.sh

# 动态下载对应架构的 Sing-box
RUN set -ex; \
    echo "Building for $TARGETOS/$TARGETARCH/$TARGETVARIANT"; \
    # 映射架构名称
    case "$TARGETARCH" in \
        "amd64") S_ARCH="amd64" ;; \
        "arm64") S_ARCH="arm64" ;; \
        "386") S_ARCH="386" ;; \
        "arm") \
            if [ "$TARGETVARIANT" = "v7" ]; then \
                S_ARCH="armv7"; \
            else \
                echo "Unsupported ARM variant: $TARGETVARIANT"; exit 1; \
            fi ;; \
        *) echo "Unsupported architecture: $TARGETARCH"; exit 1 ;; \
    esac; \
    \
    # 获取下载链接
    DOWNLOAD_URL=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep "browser_download_url" | grep "linux-$S_ARCH.tar.gz" | head -n 1 | cut -d '"' -f 4); \
    \
    # Fallback 机制
    if [ -z "$DOWNLOAD_URL" ]; then \
        echo "⚠️  GitHub API failed, using fallback version v1.13.0"; \
        DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v1.13.0/sing-box-1.13.0-linux-$S_ARCH.tar.gz"; \
    fi; \
    \
    echo "Downloading: $DOWNLOAD_URL"; \
    wget -O /tmp/sing-box.tar.gz "$DOWNLOAD_URL"; \
    tar -xzf /tmp/sing-box.tar.gz -C /tmp; \
    mv /tmp/sing-box-*/sing-box /usr/local/bin/sing-box; \
    chmod +x /usr/local/bin/sing-box; \
    rm -rf /tmp/sing-box*

# 初始化目录
RUN mkdir -p /etc/sing-box

# 复制文件
COPY supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
COPY show-info.sh /usr/local/bin/show-info

# 修复权限
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh && \
    sed -i 's/\r$//' /usr/local/bin/show-info && chmod +x /usr/local/bin/show-info

EXPOSE 443/tcp 443/udp 2053/tcp

ENTRYPOINT ["/entrypoint.sh"]
