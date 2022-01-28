#!/bin/bash
docker buildx build -t xiaofd/ray -f Dockerfile --platform linux/amd64,linux/arm64,linux/386 -o type=registry .
