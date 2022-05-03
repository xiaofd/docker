#!/bin/bash
# docker run -it --rm --privileged tonistiigi/binfmt --install all #  to install qemu emulators
# docker buildx create --use --platform linux/amd64,linux/arm64,linux/arm/v6,linux/arm/v7,linux/386 --buildkitd-flags '--allow-insecure-entitlement network.host'
docker buildx build -t xiaofd/ray:base -f Dockerfile --platform linux/amd64,linux/arm64,linux/arm/v6,linux/arm/v7,linux/386 -o type=registry -f Dockerfile.base .
docker buildx build -t xiaofd/ray:base-alpine -f Dockerfile --platform linux/amd64,linux/arm64,linux/arm/v6,linux/arm/v7,linux/386 -o type=registry -f Dockerfile.base.alpine .
# docker buildx build -t xiaofd/ray -f Dockerfile --platform linux/amd64,linux/arm64,linux/386 -o type=registry .

