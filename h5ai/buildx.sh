#!/bin/bash
docker buildx build -t xiaofd/h5ai -f Dockerfile --platform linux/amd64,linux/arm64,linux/arm/v7,linux/386 -o type=registry .

