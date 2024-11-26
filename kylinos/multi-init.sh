docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --use
docker buildx inspect --bootstrap
docker buildx build --platform linux/arm64 --load -t kylinos .
#docker run --platform linux/arm64 kylinos
