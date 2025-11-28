# Sing-box Docker (All-in-One) - xiaofd/song

A lightweight, automated Sing-box proxy server running in Docker with pure performance in mind.

## Features

- **Protocols**: VLESS Vision (TCP 443), Hysteria 2 (UDP 443), VLESS WS (TCP 2053).
- **Automated**: Auto-issues/renews SSL certs, auto-updates Sing-box Core and Rules.
- **Privacy**: Encrypted DNS, IPv4 preference, Anti-censorship rules.
- **Clean**: No logs, no bloating web servers.

## Quick Start

Run with host network for best performance:

\`\`\`bash
# Create data dir for persistence
mkdir -p $(pwd)/data

# Run
docker run -d \
    --name singbox \
    --network host \
    --restart always \
    -v $(pwd)/data:/etc/sing-box \
    -e DOMAIN="your.domain.com" \
    -e CF_TOKEN="your_cloudflare_token" \
    xiaofd/song:latest
\`\`\`

## View Links / QR Codes

\`\`\`bash
docker exec -it singbox show-info
\`\`\`

## Build & Push (Multi-Arch)

Ensure you have `docker buildx` installed.

\`\`\`bash
docker buildx build --no-cache \
  -t xiaofd/song:latest \
  -f Dockerfile \
  --platform linux/amd64,linux/arm64,linux/arm/v7,linux/386 \
  -o type=registry \
  .
\`\`\`

## Ports

| Port | Protocol | Usage |
| :--- | :--- | :--- |
| **443** | TCP | VLESS Vision |
| **443** | UDP | Hysteria 2 |
| **2053** | TCP | VLESS WebSocket (CDN) |
