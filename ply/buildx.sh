#!/bin/bash
#docker buildx build -t xiaofd/ray -f Dockerfile --platform linux/amd64,linux/arm64,linux/arm/v7,linux/386 -o type=registry .
docker buildx build -t xiaofd/ply -f Dockerfile --platform linux/amd64 -o type=registry .


