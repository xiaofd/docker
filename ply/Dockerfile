FROM --platform= xiaofd/ray:base AS buildb
#FROM --platform=$BUILDPLATFORM golang:1.19 AS build
#WORKDIR /src
#RUN apk add git gcc g++
##RUN apt install git gcc g++
#RUN git clone https://github.com/XTLS/Xray-core
#WORKDIR /src/Xray-core
#ARG TARGETOS TARGETARCH
#RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

FROM ubuntu:22.04
VOLUME /xray
RUN apt-get update && apt-get install -y iptables sed wget curl net-tools kmod iproute2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && mkdir -p /xray && \
    echo "wget -O /xray/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" >/bin/update.sh && \
    echo "wget -O /xray/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" >>/bin/update.sh && \
    /bin/bash /bin/update.sh
#COPY --from=build /src/Xray-core/xray /bin
#FROM xiaofd/ray:base
#FROM xiaofd/ray:base-alpine
#FROM teddysun/xray
COPY --from=buildb /bin/xray /xray/xray
ENV TZ=Asia/Shanghai
ENV address=""
ENV id=""
COPY run.sh /bin/
COPY config.json /xray/
#RUN /bin/bash /bin/config.sh
CMD ["/bin/bash","/bin/run.sh"] 
