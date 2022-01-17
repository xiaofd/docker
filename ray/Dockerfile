FROM --platform= golang:1.17-alpine AS build
WORKDIR /src
RUN apk add git gcc g++
RUN git clone https://github.com/XTLS/Xray-core
WORKDIR /src/Xray-core
ARG TARGETOS TARGETARCH
RUN echo aarch64
RUN echo aarch64
RUN echo aarch64
RUN GOOS= GOARCH= go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

FROM alpine
COPY --from=build /src/Xray-core/xray /bin
VOLUME /etc/xray
ENV TZ=Asia/Shanghai
CMD [ "/bin/xray", "-config", "/etc/xray/config.json" ]
