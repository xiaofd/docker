# build local
# docker build -f Dockerfile -t xiaofd/ray  --network=host .
# multiplatform
# docker buildx create --platform linux/amd64,linux/386,linux/arm64,linux/arm/v6,linux/arm/v7 --use 
# docker buildx build -f Dockerfile -t xiaofd/ray --platform linux/amd64,linux/386,linux/arm64,linux/arm/v6,linux/arm/v7 -o type=registry .

FROM --platform= golang:1.19-alpine AS build
WORKDIR /src
ENV GO111MODULE=on 
RUN apk add git gcc g++
COPY hello.go /src/hello.go
ARG TARGETOS TARGETARCH
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o hello -trimpath -ldflags "-s -w -buildid=" ./hello.go

FROM --platform= xiaofd/ray:base AS buildb
FROM --platform= xiaofd/ray:base-alpine AS builda
#FROM --platform=$BUILDPLATFORM golang:1.18-alpine AS build
#WORKDIR /src
#RUN apk add git gcc g++
##RUN apt install git gcc g++
#RUN git clone https://github.com/XTLS/Xray-core
#WORKDIR /src/Xray-core
#ARG TARGETOS TARGETARCH
#RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

FROM alpine
#COPY --from=build /src/Xray-core/xray /bin
#FROM xiaofd/ray:base
#FROM xiaofd/ray:base-alpine
#FROM teddysun/xray
COPY --from=builda /bin/xray /bin/xray
COPY --from=buildb /bin/xray /bin/xrayb
COPY --from=build /src/hello /bin/hello
VOLUME /etc/xray
ENV TZ=Asia/Shanghai
#CMD [ "/bin/xray", "-config", "/etc/xray/config.json" ]
COPY run.sh /bin/
COPY config.json /bin/
ENV CF_Token=""
ENV CF_Domain=""
CMD ["/bin/hello","&","/bin/sh","/bin/run.sh"] 
