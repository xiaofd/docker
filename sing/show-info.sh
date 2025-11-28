#!/bin/bash
CONFIG_FILE="/etc/sing-box/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then echo "Error: Config file not found!"; exit 1; fi

UUID=$(jq -r '.inbounds[] | select(.tag=="hy2-in") | .users[0].password' "$CONFIG_FILE")
WS_PATH=$(jq -r '.inbounds[] | select(.tag=="ws-in") | .transport.path' "$CONFIG_FILE")
if [[ -z "$DOMAIN" ]]; then DOMAIN=$(jq -r '.inbounds[] | select(.tag=="vision-in") | .tls.server_name' "$CONFIG_FILE"); fi

L_VISION="vless://${UUID}@${DOMAIN}:443?security=tls&encryption=none&type=tcp&headerType=none&flow=xtls-rprx-vision&sni=${DOMAIN}#${DOMAIN}_Vision"
L_HY2="hysteria2://${UUID}@${DOMAIN}:443?insecure=0&sni=${DOMAIN}&alpn=h3#${DOMAIN}_Hy2"
L_WS="vless://${UUID}@${DOMAIN}:2053?type=ws&security=tls&path=${WS_PATH//\//%2F}&sni=${DOMAIN}#${DOMAIN}_WS"

echo -e "\n=================[ QR Codes ]================="

echo -e "\n[1] VLESS Vision (TCP 443)"
echo "$L_VISION" | qrencode -o - -t UTF8 -l L

echo -e "\n[2] Hysteria 2 (UDP 443)"
echo "$L_HY2" | qrencode -o - -t UTF8 -l L

echo -e "\n[3] VLESS WS (TCP 2053)"
echo "$L_WS" | qrencode -o - -t UTF8 -l L

echo -e "\n=================[ Links ]===================="
echo -e "Vision:"
echo "$L_VISION"
echo -e "\nHysteria2:"
echo "$L_HY2"
echo -e "\nWS:"
echo "$L_WS"
echo -e "==============================================\n"
