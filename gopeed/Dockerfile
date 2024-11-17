# 基础镜像
FROM alpine:latest

# 安装依赖
RUN apk add --no-cache bash curl wget unzip

# 创建一个与宿主机 UID 和 GID 相同的用户（假设 UID 和 GID 都是 1000）
RUN addgroup -g 1000 dgroup && \
    adduser -u 1000 -G dgroup -D duser && \
    mkdir /app && \
    chown -R 1000:1000 /app

# 切换到这个用户
# USER duser
WORKDIR /app

RUN wget -O gopeed.zip $(wget -qO- https://api.github.com/repos/GopeedLab/gopeed/releases/latest | grep browser_download_url | grep linux | grep amd64 | grep web | cut -d '"' -f 4) \
    && unzip -j gopeed.zip $(unzip -l gopeed.zip | grep -o 'gopeed.*gopeed') -d . \
    && rm gopeed.zip \
    && chmod +x gopeed 

EXPOSE 9999

# 默认启动命令
#CMD ["sleep","1000000"]
CMD ["/app/gopeed"]

