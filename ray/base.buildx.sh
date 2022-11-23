#!/bin/bash
docker buildx build -t xiaofd/ray:base --platform linux/amd64,linux/arm64,linux/arm/v7,linux/386 -o type=registry -f Dockerfile.base .
docker buildx build -t xiaofd/ray:base-alpine --platform linux/amd64,linux/arm64,linux/arm/v7,linux/386 -o type=registry -f Dockerfile.base.alpine .

