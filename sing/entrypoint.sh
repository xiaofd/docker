#!/bin/bash

if [[ -z "$DOMAIN" ]]; then echo -n "Enter DOMAIN: "; read DOMAIN; fi
if [[ -z "$CF_TOKEN" ]]; then echo -n "Enter CF_TOKEN: "; read CF_TOKEN; fi

mkdir -p /etc/sing-box/cert
CERT_FILE="/etc/sing-box/cert/cert.pem"
KEY_FILE="/etc/sing-box/cert/key.pem"
CONFIG_FILE="/etc/sing-box/config.json"

# --- 证书逻辑 ---
if [[ -f "$CERT_FILE" ]] && [[ -f "$KEY_FILE" ]]; then
    echo "[Cert] Found existing certificates."
else
    echo "[Cert] Issuing new certificates..."
    export CF_Token="$CF_TOKEN"
    acme.sh --set-default-ca --server zerossl
    acme.sh --register-account -m admin@google.com
    acme.sh --issue -d "$DOMAIN" --dns dns_cf -k ec-256 --force
    acme.sh --installcert -d "$DOMAIN" --ecc --fullchainpath "$CERT_FILE" --keypath "$KEY_FILE" --reloadcmd "supervisorctl restart sing-box"
fi

# --- 下载规则集 ---
download_rules() {
    echo "Downloading Rule Sets from MetaCubeX..."
    wget -q -O /etc/sing-box/geoip-cn.srs https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geoip/cn.srs
    wget -q -O /etc/sing-box/geosite-ads.srs https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geosite/category-ads-all.srs
}

# --- 配置生成 ---
if [[ -f "$CONFIG_FILE" ]]; then
    echo "[Config] Found existing config."
    if [[ ! -f "/etc/sing-box/geoip-cn.srs" ]]; then download_rules; fi
else
    echo "[Config] Generating v1.12+ PERFECT config..."
    UUID=$(cat /proc/sys/kernel/random/uuid)
    WS_PATH="/$(head -n 10 /dev/urandom | md5sum | head -c 6)"
    
    download_rules

    cat <<JSON > "$CONFIG_FILE"
{
  "log": { "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "tag": "dns-remote", "address": "https://1.1.1.1/dns-query", "detour": "direct" },
      { "tag": "dns-direct", "address": "https://223.5.5.5/dns-query", "detour": "direct" }
    ],
    "final": "dns-remote",
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": 443,
      "sniff": true,
      "users": [{ "name": "hy2", "password": "$UUID" }],
      "tls": { "enabled": true, "certificate_path": "$CERT_FILE", "key_path": "$KEY_FILE", "alpn": ["h3"] }
    },
    {
      "type": "vless",
      "tag": "vision-in",
      "listen": "::",
      "listen_port": 443,
      "sniff": true,
      "users": [{ "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": { "enabled": true, "server_name": "$DOMAIN", "certificate_path": "$CERT_FILE", "key_path": "$KEY_FILE", "alpn": ["h2", "http/1.1"] }
    },
    {
      "type": "vless",
      "tag": "ws-in",
      "listen": "::",
      "listen_port": 2053,
      "sniff": true,
      "users": [{ "uuid": "$UUID" }],
      "transport": { "type": "ws", "path": "$WS_PATH" },
      "tls": { "enabled": true, "server_name": "$DOMAIN", "certificate_path": "$CERT_FILE", "key_path": "$KEY_FILE" }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "rule_set": [
      { "tag": "rs-geoip-cn", "type": "local", "format": "binary", "path": "/etc/sing-box/geoip-cn.srs" },
      { "tag": "rs-geosite-ads", "type": "local", "format": "binary", "path": "/etc/sing-box/geosite-ads.srs" }
    ],
    "rules": [
      { "protocol": "bittorrent", "outbound": "block" },
      { "ip_is_private": true, "outbound": "block" },
      { "rule_set": "rs-geoip-cn", "outbound": "block" },
      { "rule_set": "rs-geosite-ads", "outbound": "block" }
    ],
    "default_domain_resolver": "dns-remote"
  }
}
JSON
fi

/usr/local/bin/show-info
echo "🛠️  Starting Supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
