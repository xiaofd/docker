#!/bin/sh

# ==========================================
# Xray 部署脚本 (Vision + Hy2 + WS)
# 特性：配置自动生成、二维码并排打印
# ==========================================

# 1. 交互输入
[[ -z $CF_Domain ]] && echo -n "Enter Domain:" && read CF_Domain
[[ -z $CF_Token ]] && echo -n "CF_Token:" && read CF_Token
[[ -z $XRAY_Port ]] && echo -n "XRAY_Port:" && read XRAY_Port
PORT="$XRAY_Port"

# 2. 基础路径与依赖安装
xray_conf_dir="/etc/xray"
mkdir -p "$xray_conf_dir"

# 安装必要工具 (jq处理json, libqrencode生成二维码, coreutils用于paste拼接)
apk add --no-cache jq libqrencode curl openssl socat coreutils

# 复制二进制 & 下载 GeoIP/GeoSite
[[ ! -f "$xray_conf_dir"/xray ]] && cp /bin/xrayb "$xray_conf_dir"/xray \
&& wget -O "$xray_conf_dir"/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat \
&& wget -O "$xray_conf_dir"/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat

# 3. 配置文件初始化 (如果不存在则复制模板)
# ⚠️ 确保 /bin/config.json 是包含 Hy2 和 Vision 的最新模板
if [[ ! -f "$xray_conf_dir"/config.json ]]; then
    cp /bin/config.json "$xray_conf_dir"/
    config_new="true"
fi

# 添加 Crontab 自动更新 Geo 数据
if ! grep -q "geosite.dat" /etc/crontabs/root; then
    echo 'MAILTO=""' >> /etc/crontabs/root
    echo "0 12 * * * wget -O ${xray_conf_dir}/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" >> /etc/crontabs/root
    echo "10 12 * * * wget -O ${xray_conf_dir}/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" >> /etc/crontabs/root
fi

# 4. 生成参数
UUID=$(cat /proc/sys/kernel/random/uuid)
# 生成不带斜杠的随机路径字符串
WS_PATH_NOSPLASH=$(head -n 10 /dev/urandom | md5sum | head -c $((RANDOM % 12 + 4)))

# 5. 证书申请 (Acme.sh + ZeroSSL)
if [[ ! -f "$xray_conf_dir"/xray.crt ]]; then
    curl -L https://get.acme.sh | sh
    "$HOME"/.acme.sh/acme.sh --set-default-ca --server zerossl
    "$HOME"/.acme.sh/acme.sh --register-account -m admin@google.com
    
    if [[ -n $CF_Token ]]; then
        export CF_Token="$CF_Token"
        "$HOME"/.acme.sh/acme.sh --issue -d "${CF_Domain}" --dns dns_cf -k ec-256 --force
    fi
    
    "$HOME"/.acme.sh/acme.sh --installcert --ecc -d "${CF_Domain}" \
        --fullchainpath "${xray_conf_dir}"/xray.crt \
        --keypath "${xray_conf_dir}"/xray.key
        
    chmod 644 "${xray_conf_dir}"/xray.key
fi

# 6. 修改配置文件 (关键字替换)
if [[ -n "$config_new" ]]; then
    # 替换端口 (Vision TCP + Hy2 UDP 同时替换)
    sed -i "s/xx-port/${PORT}/g" ${xray_conf_dir}/config.json
    # 替换 UUID (所有协议统一)
    sed -i "s/xx-uuid/${UUID}/g" ${xray_conf_dir}/config.json
    # 替换 WS 回落路径
    sed -i "s/xx-path/${WS_PATH_NOSPLASH}/g" ${xray_conf_dir}/config.json
fi

# 7. 提取参数用于打印
UUID=$(jq -r '.inbounds[0].settings.clients[0].id' ${xray_conf_dir}/config.json)
PORT=$(jq -r '.inbounds[0].port' ${xray_conf_dir}/config.json)
# 智能提取 WS Path
WS_PATH=$(jq -r '.inbounds[0].settings.fallbacks[] | select(.path != null) | .path' ${xray_conf_dir}/config.json | head -n 1)
WS_PATH_WITHOUT_SLASH=${WS_PATH#/}
DOMAIN=${CF_Domain}

# ======================================================
# 8. 生成链接字符串
# ======================================================

# [1] VLESS Vision (TCP)
LINK_VISION="vless://${UUID}@${DOMAIN}:${PORT}?security=tls&encryption=none&type=tcp&headerType=none&flow=xtls-rprx-vision&sni=${DOMAIN}#${DOMAIN}_Vision"

# [2] Hysteria 2 (UDP)
LINK_HY2="vless://${UUID}@${DOMAIN}:${PORT}?security=tls&encryption=none&type=hysteria2&sni=${DOMAIN}&alpn=h3#${DOMAIN}_Hy2"

# [3] VLESS WS (CDN)
LINK_WS="vless://${UUID}@${DOMAIN}:${PORT}?type=ws&security=tls&path=%2f${WS_PATH_WITHOUT_SLASH}&sni=${DOMAIN}#${DOMAIN}_WS"

# ======================================================
# 9. 打印输出 (二维码并排 + 链接集中)
# ======================================================

echo -e "\n=================[ 📱 扫码连接 (QR Codes) ]================="
echo -e "   1. Vision (主力/稳定)          2. Hysteria2 (加速/UDP)"

# 创建临时文件存放二维码文本
TMP_QR1=$(mktemp)
TMP_QR2=$(mktemp)
TMP_QR3=$(mktemp)

# 生成二维码到临时文件 (使用 UTF8 模式)
echo "${LINK_VISION}" | qrencode -o - -t UTF8 -l L > "$TMP_QR1"
echo "${LINK_HY2}"    | qrencode -o - -t UTF8 -l L > "$TMP_QR2"
echo "${LINK_WS}"     | qrencode -o - -t UTF8 -l L > "$TMP_QR3"

# 使用 paste 命令将 Vision 和 Hy2 的二维码左右拼接 (中间用 tab 或空格隔开)
# 注意：如果终端宽度不够，可能会换行错位
paste "$TMP_QR1" "$TMP_QR2" | sed 's/^/  /' 

echo -e "   3. VLESS WS (CDN/备用)"
cat "$TMP_QR3" | sed 's/^/  /'

# 删除临时文件
rm "$TMP_QR1" "$TMP_QR2" "$TMP_QR3"

echo -e "\n=================[ 🔗 复制链接 (Links) ]===================="

echo -e "\n🚀 [1] VLESS Vision (TCP + TLS + Vision) [推荐]:"
echo "${LINK_VISION}"

echo -e "\n🌊 [2] Hysteria 2 (UDP + TLS + Hy2) [极速]:"
echo "${LINK_HY2}"

echo -e "\n🌐 [3] VLESS WS (WebSocket + TLS) [CDN备用]:"
echo "${LINK_WS}"

echo -e "\n============================================================"

# 启动命令 (如需要)
# "$xray_conf_dir"/xray --config "$xray_conf_dir"/config.json &
# 打印定时任务状态 (你要求的)
echo -e "\n[Cron Jobs]"
crontab -l
