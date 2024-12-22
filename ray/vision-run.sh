[[ -z $DESTURL ]] && DESTURL="music.apple.com"
[[ -z $XRAY_Port ]] && XRAY_Port=443
PORT="$XRAY_Port"
x25519=$(echo $(xray x25519 | awk '{print $3}' | tr '\n' ' '))
PUBKEY=$(echo "${x25519}" | awk '{print $2}') 
PRIKEY=$(echo "${x25519}" | awk '{print $1}') 
xray_conf_dir="/etc/xray"
mkdir -p "$xray_conf_dir"
[[ ! -f "$xray_conf_dir"/xray ]] && cp /bin/xrayb "$xray_conf_dir"/xray \
&& wget -O "$xray_conf_dir"/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat \
&& wget -O "$xray_conf_dir"/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
[[ ! -f "$xray_conf_dir"/config.json ]] && cp /bin/config.json "$xray_conf_dir"/ && config_new="true"
echo 'MAILTO=""' >> /etc/crontabs/root
echo "0 12 * * * wget -O ${xray_conf_dir}/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" >> /etc/crontabs/root
echo "10 12 * * * wget -O ${xray_conf_dir}/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" >> /etc/crontabs/root

# qrencode -l H 参数 可以纠错，生成图片稍大
# qrencode -o- -l H "12345645gsdfgsdfsdf" -t UTF8
# echo "12345645gsdfgsdfsdf" | qrencode -o- -l H -t UTF8
apk add --no-cache jq libqrencode curl openssl

UUID=$(cat /proc/sys/kernel/random/uuid)

if [[ -n "$config_new" ]];then
sed -i "s/xx-port/${PORT}/g" ${xray_conf_dir}/config.json
sed -i "s/xx-uuid/${UUID}/g" ${xray_conf_dir}/config.json
sed -i "s/xx-url/${DESTURL}/g" ${xray_conf_dir}/config.json
sed -i "s/xx-okey/${PRIKEY}/g" ${xray_conf_dir}/config.json
fi

UUID=$(cat ${xray_conf_dir}/config.json | jq .inbounds[1].settings.clients[0].id | tr -d '"')
PRIKEY=$(cat ${xray_conf_dir}/config.json | jq .inbounds[1].streamSettings.realitySettings.privateKey | tr -d '"')
PUBKEY=$(xray x25519 -i ${PRIKEY} | awk '{print $3}' | tail -n1)
PORT=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].port)
DESTURL=$(cat ${xray_conf_dir}/config.json | jq .inbounds[1].streamSettings.realitySettings.serverNames[0] | tr -d '"')
DOMAIN=${CF_Domain}
DOMAIN4=$(curl -4 ipv4.ip.sb)
DOMAIN6=$(curl -6 ipv6.ip.sb)

if [[ -n "$DOMAIN" ]];then
echo "URL 链接 (VLESS + Vision + Reality)"
echo "vless://$UUID@$DOMAIN:$PORT?security=reality&flow=xtls-rprx-vision&fp=chrome&pbk=$PUBKEY&sni=$DESTURL&spx=%2F&sid=#VLESS-XTLS-uTLS-REALITY"
else
echo "URL 链接 (VLESS + Vision + Reality)"
echo "vless://$UUID@$DOMAIN4:$PORT?security=reality&flow=xtls-rprx-vision&fp=chrome&pbk=$PUBKEY&sni=$DESTURL&spx=%2F&sid=#VLESS-XTLS-uTLS-REALITY"
echo "vless://$UUID@$DOMAIN6:$PORT?security=reality&flow=xtls-rprx-vision&fp=chrome&pbk=$PUBKEY&sni=$DESTURL&spx=%2F&sid=#VLESS-XTLS-uTLS-REALITY"
fi

#"$xray_conf_dir"/xray --config "$xray_conf_dir"/config.json
#/bin/xray --config "$xray_conf_dir"/config.json
#/bin/sh
sed -i '/^\[program:hello\]/,/^$/d' /etc/supervisord.conf
crontab -l

