#!/bin/bash
docker buildx build --no-cache -t xiaofd/ray -f Dockerfile --platform linux/amd64,linux/arm64,linux/arm/v7,linux/386 -o type=registry .
docker buildx build --no-cache -t xiaofd/ray:vision -f Dockerfile.vision --platform linux/amd64,linux/arm64,linux/arm/v7,linux/386 -o type=registry .

