# syntax=docker/dockerfile:1.4
# docker build -t kylinos .
FROM debian:stable-slim AS debootstrap

# 安装debootstrap和其他必要工具
RUN apt-get update && apt-get install -y debootstrap --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# 创建根文件系统
RUN debootstrap --components main,universe,multiverse,restricted --variant minbase --include=ca-certificates --no-check-gpg 10.1-wayland-2203-updates /rootfs http://archive.kylinos.cn/kylin/KYLIN-ALL focal 

RUN echo "nameserver 8.8.8.8" >/rootfs/etc/resolv.conf
RUN echo "deb https://archive.kylinos.cn/kylin/KYLIN-ALL/ 10.1-kirin9006C-feature main" >>/rootfs/etc/apt/sources.list
RUN echo "deb https://archive2.kylinos.cn/deb/kylin/production/PART-10_1-kirin9a0/custom/partner/10_1-kirin9a0 default all" >>/rootfs/etc/apt/sources.list
# 阶段 2：构建最终的镜像
FROM scratch

# 将debootstrap生成的系统文件复制到镜像中
COPY --from=debootstrap /rootfs/ /

# 设置环境变量
ENV LANG C.UTF-8

# 默认运行shell
CMD ["/bin/bash"]

