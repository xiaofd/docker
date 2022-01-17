# build local
# docker build -f Dockerfile -t xiaofd/ray .
# multiplatform
# docker buildx create --platform linux/amd64,linux/386,linux/arm64,linux/arm/v6,linux/arm/v7 --use 
# docker buildx build -f Dockerfile -t xiaofd/ray --platform linux/amd64,linux/386,linux/arm64,linux/arm/v6,linux/arm/v7 -o type=registry .
FROM --platform= golang:1.17-alpine AS build
WORKDIR /src
RUN apk add git gcc g++
RUN git clone https://github.com/XTLS/Xray-core
WORKDIR /src/Xray-core
ARG TARGETOS TARGETARCH
RUN GOOS= GOARCH= go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

FROM alpine
COPY --from=build /src/Xray-core/xray /bin
VOLUME /etc/xray
ENV TZ=Asia/Shanghai
#CMD [ "/bin/xray", "-config", "/etc/xray/config.json" ]
COPY run.sh /bin/
ENV CF_Token=""
CMD ["/bin/sh","/bin/run.sh"] 
